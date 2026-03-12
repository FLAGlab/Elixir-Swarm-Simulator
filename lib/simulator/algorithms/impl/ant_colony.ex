defmodule Simulator.Algorithms.AntColony do
  @moduledoc """
  Ant Colony Optimization algorithm for 2D continuous space exploration.

  Implements a "negative pheromone" system: ants deposit pheromone on cells
  they visit, marking them as "explored, no objective found here". When
  choosing a new target, cells with less pheromone (unexplored areas) have
  higher probability of being selected, guiding the colony toward uncharted
  territory.

  Pheromone values decay multiplicatively each tick (evaporation), so old
  information fades and areas become worth re-exploring over time.

  Ants share their pheromone grid with neighbors. Grids are merged using
  max per cell, which is inherently idempotent — receiving your own data
  back via a neighbor does not inflate values, eliminating the echo problem
  without needing per-source tracking.
  """

  @behaviour Simulator.Algorithm

  alias Simulator.Algorithms.Helpers.Geometry

  @step_size 5
  @arrival_threshold 3
  @cell_size 20
  @evaporation_rate 0.02
  @deposit_amount 1.0

  # Callbacks --------------------------------------------------------

  @impl true
  def compute_step(%{position: position, map: map} = state) do
    grid = Map.get(state, :pheromone_grid) || Geometry.build_cell_grid(map, @cell_size, 0.0)
    grid = grid |> evaporate() |> deposit(position)
    state = Map.put(state, :pheromone_grid, grid)

    target = Map.get(state, :target) || pick_target(grid, map, position)

    if Geometry.euclidean_distance(position, target) <= @arrival_threshold do
      new_target = pick_target(grid, map, position)
      {position, Map.put(state, :target, new_target)}
    else
      move_toward_target(position, target, map, state)
    end
  end

  @impl true
  def get_shared_data(state) do
    grid = Map.get(state, :pheromone_grid, %{})
    shareable = Enum.reject(grid, fn {_cell, level} -> level == 0.0 end) |> Map.new()
    %{type: :ant_colony, grid: shareable}
  end

  @impl true
  def handle_received_data(_sender, data, state) do
    case data do
      %{type: :ant_colony, grid: remote_grid} ->
        local_grid = Map.get(state, :pheromone_grid, %{})

        merged =
          Map.merge(local_grid, remote_grid, fn _cell, local, remote -> max(local, remote) end)

        Map.put(state, :pheromone_grid, merged)

      _ ->
        state
    end
  end

  @impl true
  def format_state(algo_state) do
    grid = Map.get(algo_state, :pheromone_grid, %{})
    cells = grid_to_overlay(grid)

    fields =
      case Map.get(algo_state, :target) do
        nil -> []
        target -> [%{label: "Target", value: target, type: "position"}]
      end

    overlay =
      if cells == [] do
        nil
      else
        %{cells: cells, color: "59, 130, 246"}
      end

    %{detail_fields: fields, overlay: overlay}
  end

  # Private ----------------------------------------------------------

  defp move_toward_target(position, target, map, state) do
    candidate = Geometry.step_toward(position, target, map, @step_size)
    from = {position.x, position.y}
    to = {candidate.x, candidate.y}

    if Geometry.path_collides?(from, to, map.structures) do
      grid = Map.get(state, :pheromone_grid, %{})
      new_target = pick_target(grid, map, position)
      {position, Map.put(state, :target, new_target)}
    else
      {candidate, Map.put(state, :target, target)}
    end
  end

  defp evaporate(grid) do
    Map.new(grid, fn {cell, level} ->
      if level > 0.0 do
        {cell, level * (1 - @evaporation_rate)}
      else
        {cell, level}
      end
    end)
  end

  defp deposit(grid, position) do
    cell = Geometry.position_to_cell(position, @cell_size)
    Map.update(grid, cell, @deposit_amount, &(&1 + @deposit_amount))
  end

  defp pick_target(grid, map, fallback) do
    weights = cell_weights(grid, map)
    total = weights |> Map.values() |> Enum.sum()

    if total == 0.0 do
      Geometry.random_open_point(map, fallback)
    else
      cell = weighted_random_cell(weights, total)
      candidate = Geometry.cell_to_point(cell, @cell_size, map)

      if Geometry.inside_structure?({candidate.x, candidate.y}, map.structures) do
        Geometry.random_open_point(map, fallback)
      else
        candidate
      end
    end
  end

  defp cell_weights(grid, map) do
    Map.new(grid, fn {{col, row} = cell, level} ->
      center = {col * @cell_size + div(@cell_size, 2), row * @cell_size + div(@cell_size, 2)}

      if Geometry.inside_structure?(center, map.structures) do
        {cell, 0.0}
      else
        {cell, 1.0 / (1.0 + level)}
      end
    end)
  end

  defp weighted_random_cell(weights, total) do
    threshold = :rand.uniform() * total

    result =
      Enum.reduce_while(weights, 0.0, fn {cell, weight}, acc ->
        new_acc = acc + weight

        if new_acc >= threshold do
          {:halt, cell}
        else
          {:cont, new_acc}
        end
      end)

    case result do
      {_col, _row} = cell -> cell
      _acc -> weights |> Map.keys() |> Enum.random()
    end
  end

  defp grid_to_overlay(grid) do
    non_zero = Enum.reject(grid, fn {_cell, level} -> level == 0.0 end)

    if non_zero == [] do
      []
    else
      max_level = non_zero |> Enum.map(fn {_cell, level} -> level end) |> Enum.max()

      Enum.map(non_zero, fn {{col, row}, level} ->
        %{x: col * @cell_size, y: row * @cell_size, intensity: level / max_level}
      end)
    end
  end
end
