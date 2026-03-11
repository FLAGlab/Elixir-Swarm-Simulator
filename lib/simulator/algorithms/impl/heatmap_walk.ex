defmodule Simulator.Algorithms.HeatmapWalk do
  @moduledoc """
  Heatmap walk algorithm: picks targets favoring less-visited areas.

  Similar to AimRandomWalk but maintains a rolling window of the last K
  visited positions. When choosing a new target, the map is divided into
  cells and the algorithm picks a random point inside the least-visited
  cell, encouraging exploration of unvisited areas.

  Drones share their knowledge with neighbors via `KnowledgeStore`.
  Each shared message is keyed by original source PID, preventing echo
  and duplication. Received knowledge decays one position per tick,
  matching the drone's own rolling window lifecycle.
  """

  @behaviour Simulator.Algorithm

  alias Simulator.Geometry
  alias Simulator.Algorithms.KnowledgeStore

  @step_size 5
  @arrival_threshold 3
  @history_size 200
  @cell_size 20

  # Callbacks --------------------------------------------------------

  @impl true
  def compute_step(%{position: position, map: map} = state) do
    received = Map.get(state, :received_visited, %{})
    state = Map.put(state, :received_visited, KnowledgeStore.decay(received))

    knowledge = knowledge(state)
    target = Map.get(state, :target) || pick_cool_target(map, position, knowledge)

    if Geometry.euclidean_distance(position, target) <= @arrival_threshold do
      new_visited = record_position(Map.get(state, :visited, []), position)
      new_state = Map.put(state, :visited, new_visited)
      new_target = pick_cool_target(map, position, knowledge(new_state))
      {position, Map.put(new_state, :target, new_target)}
    else
      move_toward_target(position, target, map, state)
    end
  end

  @impl true
  def get_shared_data(state) do
    visited = Map.get(state, :visited, [])
    received = Map.get(state, :received_visited, %{})
    %{type: :heatmap, knowledge: KnowledgeStore.build_shareable(visited, received)}
  end

  @impl true
  def format_state(algo_state) do
    KnowledgeStore.format_for_export(algo_state)
  end

  @impl true
  def handle_received_data(_sender, data, state) do
    case data do
      %{type: :heatmap, knowledge: incoming} ->
        received = Map.get(state, :received_visited, %{})
        Map.put(state, :received_visited, KnowledgeStore.merge(received, incoming))

      _ ->
        state
    end
  end

  # Private ----------------------------------------------------------

  defp move_toward_target(position, target, map, state) do
    candidate = Geometry.step_toward(position, target, map, @step_size)
    from = {position.x, position.y}
    to = {candidate.x, candidate.y}

    new_visited = record_position(Map.get(state, :visited, []), position)
    new_state = Map.put(state, :visited, new_visited)

    if Geometry.path_collides?(from, to, map.structures) do
      new_target = pick_cool_target(map, position, knowledge(new_state))
      {position, Map.put(new_state, :target, new_target)}
    else
      {candidate, Map.put(new_state, :target, target)}
    end
  end

  defp knowledge(state) do
    KnowledgeStore.all_positions(
      Map.get(state, :visited, []),
      Map.get(state, :received_visited, %{})
    )
  end

  defp record_position(visited, position) do
    [position | visited] |> Enum.take(@history_size)
  end

  defp pick_cool_target(map, fallback, visited) do
    heat = build_heat_grid(map, visited)

    if map_size(heat) == 0 do
      Geometry.random_open_point(map, fallback)
    else
      min_heat = heat |> Map.values() |> Enum.min()
      cool_cells = for {cell, count} <- heat, count == min_heat, do: cell

      {col, row} = Enum.random(cool_cells)
      candidate = cell_to_point(col, row, map)

      if Geometry.inside_structure?({candidate.x, candidate.y}, map.structures) do
        Geometry.random_open_point(map, fallback)
      else
        candidate
      end
    end
  end

  defp build_heat_grid(map, visited) do
    cols = div(map.width, @cell_size) + 1
    rows = div(map.height, @cell_size) + 1

    base = for c <- 0..(cols - 1), r <- 0..(rows - 1), into: %{}, do: {{c, r}, 0}

    Enum.reduce(visited, base, fn pos, acc ->
      cell = {div(pos.x, @cell_size), div(pos.y, @cell_size)}
      Map.update(acc, cell, 1, &(&1 + 1))
    end)
  end

  defp cell_to_point(col, row, map) do
    x = Geometry.clamp(col * @cell_size + Enum.random(0..(@cell_size - 1)), 0, map.width)
    y = Geometry.clamp(row * @cell_size + Enum.random(0..(@cell_size - 1)), 0, map.height)
    %{x: x, y: y}
  end
end
