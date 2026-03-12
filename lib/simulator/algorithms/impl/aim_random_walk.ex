defmodule Simulator.Algorithms.AimRandomWalk do
  @moduledoc """
  Aim random walk algorithm: picks a random target and walks toward it.

  On each tick the drone moves one step in the direction of its current
  target. When the drone arrives or when the next step would collide
  with a map obstacle, a new random target is generated.
  """

  @behaviour Simulator.Algorithm

  alias Simulator.Algorithms.Helpers.Geometry

  @step_size 5
  @arrival_threshold 3

  # Callbacks --------------------------------------------------------

  @impl true
  def compute_step(%{position: position, map: map} = state) do
    target = Map.get(state, :target) || Geometry.random_open_point(map, position)

    if Geometry.euclidean_distance(position, target) <= @arrival_threshold do
      new_target = Geometry.random_open_point(map, position)
      {position, Map.put(state, :target, new_target)}
    else
      move_toward_target(position, target, map, state)
    end
  end

  @impl true
  def format_state(algo_state) do
    fields =
      case Map.get(algo_state, :target) do
        nil -> []
        target -> [%{label: "Target", value: target, type: "position"}]
      end

    %{detail_fields: fields, overlay: nil}
  end

  # Private ----------------------------------------------------------

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
end
