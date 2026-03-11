defmodule Simulator.Algorithms.ParticleSwarm do
  @moduledoc """
  Particle Swarm Optimization for blind search in 2D continuous space.

  Designed for finding a static objective that emits no proximity signal —
  particles must physically reach the objective to detect it. To maximize
  area coverage and avoid clustering, the velocity update includes a
  **repulsion force** between nearby particles during exploration.

  ## Modes

  - **Exploration** (`:objective_found` is `nil`): particles spread out using
    inertia + random wander + repulsion from neighbors. Each particle tracks
    its personal best (least-visited position) to avoid re-exploring.
  - **Convergence** (`:objective_found` is `%{x, y}`): once any particle
    detects the objective, it broadcasts the location. All particles switch
    to classic PSO convergence: inertia + personal best attraction +
    global best (objective) attraction.

  ## Communication

  When a particle finds the objective, it shares `%{type: :pso, objective: %{x, y}}`
  with neighbors. Receivers store the objective and switch to convergence mode.
  The information propagates transitively as drones meet.
  """

  @behaviour Simulator.Algorithm

  alias Simulator.Algorithms.Helpers.Geometry

  @max_speed 8.0
  @inertia 0.6
  @cognitive_weight 1.5
  @social_weight 1.5
  @repulsion_radius 80.0
  @repulsion_strength 3.0
  @wander_strength 4.0

  # Callbacks --------------------------------------------------------

  @impl true
  def compute_step(%{position: position, map: map, neighbors: neighbors} = state) do
    velocity = Map.get(state, :velocity) || random_velocity()
    personal_best = Map.get(state, :personal_best) || position
    objective = Map.get(state, :objective_found)

    new_velocity =
      if objective do
        convergence_velocity(velocity, position, personal_best, objective)
      else
        exploration_velocity(velocity, position, neighbors)
      end

    new_velocity = clamp_velocity(new_velocity)
    candidate = apply_velocity(position, new_velocity, map)

    from = {position.x, position.y}
    to = {candidate.x, candidate.y}

    {final_pos, final_vel} =
      if Geometry.path_collides?(from, to, map.structures) do
        bounced = %{vx: -new_velocity.vx * 0.5, vy: -new_velocity.vy * 0.5}
        {position, bounced}
      else
        {candidate, new_velocity}
      end

    new_best =
      if objective == nil and further_from_neighbors?(final_pos, personal_best, neighbors) do
        final_pos
      else
        personal_best
      end

    state =
      state
      |> Map.put(:velocity, final_vel)
      |> Map.put(:personal_best, new_best)

    {final_pos, state}
  end

  @impl true
  def get_shared_data(state) do
    case Map.get(state, :objective_found) do
      nil -> %{}
      objective -> %{type: :pso, objective: objective}
    end
  end

  @impl true
  def handle_received_data(_sender, data, state) do
    case data do
      %{type: :pso, objective: objective} when not is_nil(objective) ->
        if Map.get(state, :objective_found) == nil do
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
    |> Map.delete(:velocity)
    |> Map.delete(:personal_best)
  end

  # Private — Velocity updates ----------------------------------------

  defp exploration_velocity(velocity, position, neighbors) do
    inertia = scale(velocity, @inertia)
    wander = random_velocity(@wander_strength)
    repulsion = compute_repulsion(position, neighbors)

    add(inertia, add(wander, repulsion))
  end

  defp convergence_velocity(velocity, position, personal_best, objective) do
    inertia = scale(velocity, @inertia)

    r1 = :rand.uniform()
    r2 = :rand.uniform()

    cognitive = scale(direction(position, personal_best), @cognitive_weight * r1)
    social = scale(direction(position, objective), @social_weight * r2)

    add(inertia, add(cognitive, social))
  end

  defp compute_repulsion(_position, neighbors) when map_size(neighbors) == 0 do
    %{vx: 0.0, vy: 0.0}
  end

  defp compute_repulsion(position, neighbors) do
    Enum.reduce(neighbors, %{vx: 0.0, vy: 0.0}, fn {_pid, neighbor_pos}, acc ->
      dx = position.x - neighbor_pos.x
      dy = position.y - neighbor_pos.y
      dist = :math.sqrt(dx * dx + dy * dy)

      if dist < @repulsion_radius and dist > 0.1 do
        force = @repulsion_strength / dist
        %{vx: acc.vx + dx / dist * force, vy: acc.vy + dy / dist * force}
      else
        acc
      end
    end)
  end

  # Private — Vector helpers ------------------------------------------

  defp random_velocity(magnitude \\ @max_speed) do
    angle = :rand.uniform() * 2 * :math.pi()
    speed = :rand.uniform() * magnitude
    %{vx: :math.cos(angle) * speed, vy: :math.sin(angle) * speed}
  end

  defp direction(from, to) do
    dx = to.x - from.x
    dy = to.y - from.y
    dist = :math.sqrt(dx * dx + dy * dy)

    if dist < 0.1 do
      %{vx: 0.0, vy: 0.0}
    else
      %{vx: dx / dist, vy: dy / dist}
    end
  end

  defp scale(v, factor), do: %{vx: v.vx * factor, vy: v.vy * factor}
  defp add(a, b), do: %{vx: a.vx + b.vx, vy: a.vy + b.vy}

  defp clamp_velocity(v) do
    speed = :math.sqrt(v.vx * v.vx + v.vy * v.vy)

    if speed > @max_speed do
      scale(v, @max_speed / speed)
    else
      v
    end
  end

  defp apply_velocity(position, velocity, map) do
    %{
      x: Geometry.clamp(round(position.x + velocity.vx), 0, map.width),
      y: Geometry.clamp(round(position.y + velocity.vy), 0, map.height)
    }
  end

  # Private — Personal best heuristic ---------------------------------

  defp further_from_neighbors?(pos, current_best, neighbors) when map_size(neighbors) == 0 do
    pos != current_best
  end

  defp further_from_neighbors?(pos, current_best, neighbors) do
    min_dist_pos = min_neighbor_distance(pos, neighbors)
    min_dist_best = min_neighbor_distance(current_best, neighbors)
    min_dist_pos > min_dist_best
  end

  defp min_neighbor_distance(pos, neighbors) do
    neighbors
    |> Enum.map(fn {_pid, n} -> Geometry.euclidean_distance(pos, n) end)
    |> Enum.min()
  end
end
