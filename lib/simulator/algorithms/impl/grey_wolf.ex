defmodule Simulator.Algorithms.GreyWolf do
  @moduledoc """
  Grey Wolf Optimizer (GWO) for blind search in 2D continuous space.

  Implements a modified GWO where wolves have no initial knowledge of the
  objective's location. The pack operates in two distinct phases:

  ## Dispersed Hunt (no objective detected)

  Wolves are assigned roles by ID: the first three drones become Alpha,
  Beta, and Delta (the leaders); all others are Omega. Each leader is
  assigned a different zone of the map and patrols it, maintaining a
  minimum safety distance from other known leaders via repulsion.

  Omega wolves track the nearest known leader and patrol around it with
  a random offset, providing local coverage near each leader.

  Leaders share their role and position through the decentralized
  communication system, so every wolf builds a local picture of where
  the leaders are without any global state.

  ## Convergence (objective detected)

  When any wolf finds the objective, it broadcasts the location. The
  information propagates transitively as wolves meet. All wolves switch
  to GWO encircling behavior: positions update based on Alpha, Beta, and
  Delta positions using the classic GWO equations with a linearly
  decreasing `a` parameter that tightens the encirclement over time.
  """

  @behaviour Simulator.Algorithm

  alias Simulator.Algorithms.Helpers.Geometry

  @step_size 5
  @arrival_threshold 3
  @min_leader_distance 150.0
  @repulsion_strength 2.0
  @omega_spread 60
  @a_initial 2.0
  @a_decay 0.005

  # Callbacks --------------------------------------------------------

  @impl true
  def compute_step(%{position: position, map: map, id: id} = state) do
    role = Map.get(state, :role) || assign_role(id)
    state = Map.put(state, :role, role)

    objective = Map.get(state, :objective_found)
    known_leaders = Map.get(state, :known_leaders, %{})

    if objective do
      convergence_step(position, map, objective, known_leaders, state)
    else
      dispersed_step(position, map, role, known_leaders, state)
    end
  end

  @impl true
  def get_shared_data(%{id: id} = state) do
    role = Map.get(state, :role) || assign_role(id)
    objective = Map.get(state, :objective_found)

    %{
      type: :gwo,
      role: role,
      position: state.position,
      objective: objective
    }
  end

  @impl true
  def handle_received_data(_sender, data, state) do
    case data do
      %{type: :gwo, role: role, position: pos, objective: objective} ->
        state = update_known_leaders(state, role, pos)

        if objective && Map.get(state, :objective_found) == nil do
          Map.put(state, :objective_found, objective)
        else
          state
        end

      _ ->
        state
    end
  end

  @impl true
  def format_state(algo_state) do
    algo_state
    |> Map.delete(:known_leaders)
    |> Map.delete(:a_param)
  end

  # Private — Dispersed hunt -----------------------------------------

  defp dispersed_step(position, map, role, known_leaders, state) when role in [:alpha, :beta, :delta] do
    zone_center = zone_target(role, map)
    target = Map.get(state, :target) || zone_center

    if Geometry.euclidean_distance(position, target) <= @arrival_threshold do
      new_target = random_in_zone(role, map)
      {position, Map.put(state, :target, new_target)}
    else
      repelled = apply_leader_repulsion(target, position, known_leaders, role, map)
      move_toward_target(position, repelled, map, state)
    end
  end

  defp dispersed_step(position, map, :omega, known_leaders, state) do
    target = Map.get(state, :target) || pick_omega_target(position, known_leaders, map)

    if Geometry.euclidean_distance(position, target) <= @arrival_threshold do
      new_target = pick_omega_target(position, known_leaders, map)
      {position, Map.put(state, :target, new_target)}
    else
      move_toward_target(position, target, map, state)
    end
  end

  # Private — Convergence --------------------------------------------

  defp convergence_step(position, map, objective, known_leaders, state) do
    a = Map.get(state, :a_param, @a_initial)
    new_a = max(a - @a_decay, 0.0)
    state = Map.put(state, :a_param, new_a)

    leader_positions = get_leader_positions(known_leaders, objective)
    target = gwo_encircle(position, leader_positions, a)

    clamped = %{
      x: Geometry.clamp(round(target.x), 0, map.width),
      y: Geometry.clamp(round(target.y), 0, map.height)
    }

    from = {position.x, position.y}
    to = {clamped.x, clamped.y}

    if Geometry.path_collides?(from, to, map.structures) do
      {position, Map.put(state, :target, nil)}
    else
      {clamped, Map.put(state, :target, nil)}
    end
  end

  defp gwo_encircle(position, {alpha_pos, beta_pos, delta_pos}, a) do
    x1 = encircle_component(position.x, alpha_pos.x, a)
    y1 = encircle_component(position.y, alpha_pos.y, a)
    x2 = encircle_component(position.x, beta_pos.x, a)
    y2 = encircle_component(position.y, beta_pos.y, a)
    x3 = encircle_component(position.x, delta_pos.x, a)
    y3 = encircle_component(position.y, delta_pos.y, a)

    %{x: (x1 + x2 + x3) / 3.0, y: (y1 + y2 + y3) / 3.0}
  end

  defp encircle_component(pos, leader_pos, a) do
    r1 = :rand.uniform()
    r2 = :rand.uniform()
    a_vec = 2.0 * a * r1 - a
    c = 2.0 * r2
    d = abs(c * leader_pos - pos)
    leader_pos - a_vec * d
  end

  defp get_leader_positions(known_leaders, objective) do
    alpha = Map.get(known_leaders, :alpha, objective)
    beta = Map.get(known_leaders, :beta, objective)
    delta = Map.get(known_leaders, :delta, objective)
    {alpha, beta, delta}
  end

  # Private — Zone management ----------------------------------------

  defp assign_role(id) do
    case id do
      1 -> :alpha
      2 -> :beta
      3 -> :delta
      _ -> :omega
    end
  end

  defp zone_target(:alpha, map), do: %{x: div(map.width, 4), y: div(map.height, 4)}
  defp zone_target(:beta, map), do: %{x: 3 * div(map.width, 4), y: div(map.height, 4)}
  defp zone_target(:delta, map), do: %{x: div(map.width, 2), y: 3 * div(map.height, 4)}

  defp random_in_zone(role, map) do
    {x_min, x_max, y_min, y_max} = zone_bounds(role, map)
    %{x: Enum.random(x_min..x_max), y: Enum.random(y_min..y_max)}
  end

  defp zone_bounds(:alpha, map) do
    {0, div(map.width, 2), 0, div(map.height, 2)}
  end

  defp zone_bounds(:beta, map) do
    {div(map.width, 2), map.width, 0, div(map.height, 2)}
  end

  defp zone_bounds(:delta, map) do
    {0, map.width, div(map.height, 2), map.height}
  end

  # Private — Leader repulsion ---------------------------------------

  defp apply_leader_repulsion(target, position, known_leaders, self_role, map) do
    other_leaders =
      known_leaders
      |> Map.delete(self_role)
      |> Map.values()

    repulsion =
      Enum.reduce(other_leaders, %{rx: 0.0, ry: 0.0}, fn leader_pos, acc ->
        dist = Geometry.euclidean_distance(position, leader_pos)

        if dist < @min_leader_distance and dist > 0.1 do
          dx = position.x - leader_pos.x
          dy = position.y - leader_pos.y
          force = @repulsion_strength * (@min_leader_distance - dist) / @min_leader_distance
          %{rx: acc.rx + dx / dist * force, ry: acc.ry + dy / dist * force}
        else
          acc
        end
      end)

    %{
      x: Geometry.clamp(round(target.x + repulsion.rx), 0, map.width),
      y: Geometry.clamp(round(target.y + repulsion.ry), 0, map.height)
    }
  end

  # Private — Omega target -------------------------------------------

  defp pick_omega_target(position, known_leaders, map) when map_size(known_leaders) == 0 do
    Geometry.random_open_point(map, position)
  end

  defp pick_omega_target(position, known_leaders, map) do
    {_role, leader_pos} =
      Enum.min_by(known_leaders, fn {_role, pos} ->
        Geometry.euclidean_distance(position, pos)
      end)

    offset_x = Enum.random(-@omega_spread..@omega_spread)
    offset_y = Enum.random(-@omega_spread..@omega_spread)

    candidate = %{
      x: Geometry.clamp(leader_pos.x + offset_x, 0, map.width),
      y: Geometry.clamp(leader_pos.y + offset_y, 0, map.height)
    }

    if Geometry.inside_structure?({candidate.x, candidate.y}, map.structures) do
      Geometry.random_open_point(map, position)
    else
      candidate
    end
  end

  # Private — Movement -----------------------------------------------

  defp move_toward_target(position, target, map, state) do
    candidate = Geometry.step_toward(position, target, map, @step_size)
    from = {position.x, position.y}
    to = {candidate.x, candidate.y}

    if Geometry.path_collides?(from, to, map.structures) do
      new_target = Geometry.random_open_point(map, position)
      {position, Map.put(state, :target, new_target)}
    else
      {candidate, Map.put(state, :target, target)}
    end
  end

  # Private — Known leaders ------------------------------------------

  defp update_known_leaders(state, role, position) when role in [:alpha, :beta, :delta] do
    leaders = Map.get(state, :known_leaders, %{})
    Map.put(state, :known_leaders, Map.put(leaders, role, position))
  end

  defp update_known_leaders(state, _role, _position), do: state
end
