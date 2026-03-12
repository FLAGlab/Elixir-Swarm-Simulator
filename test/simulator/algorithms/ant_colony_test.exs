defmodule Simulator.Algorithms.AntColonyTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.AntColony
  alias Simulator.Maps.MapParams

  @clean_map %MapParams{width: 500, height: 500, structures: [], spawn_point: %{x: 250, y: 250}}

  @obstacle_map %MapParams{
    width: 1000,
    height: 500,
    structures: [
      %{id: 1, points: [{400, 150}, {600, 150}, {600, 350}, {400, 350}]}
    ],
    spawn_point: %{x: 200, y: 250}
  }

  describe "compute_step/1" do
    test "initializes pheromone grid on first tick" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}
      {_pos, new_state} = AntColony.compute_step(state)

      assert Map.has_key?(new_state, :pheromone_grid)
      assert is_map(new_state.pheromone_grid)
      assert map_size(new_state.pheromone_grid) > 0
    end

    test "deposits pheromone at current position" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}
      {_pos, new_state} = AntColony.compute_step(state)

      grid = new_state.pheromone_grid
      cell = {div(250, 20), div(250, 20)}

      assert Map.get(grid, cell, 0.0) > 0.0
    end

    test "generates a target" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}
      {_pos, new_state} = AntColony.compute_step(state)

      assert Map.has_key?(new_state, :target)
    end

    test "keeps position within map bounds" do
      state = %{position: %{x: 2, y: 2}, map: @clean_map}
      {pos, _} = AntColony.compute_step(state)

      assert pos.x >= 0 and pos.x <= @clean_map.width
      assert pos.y >= 0 and pos.y <= @clean_map.height
    end

    test "recalculates target on collision" do
      position = %{x: 395, y: 250}
      target = %{x: 500, y: 250}
      grid = Simulator.Algorithms.Helpers.Geometry.build_cell_grid(@obstacle_map, 20, 0.0)
      state = %{position: position, map: @obstacle_map, target: target, pheromone_grid: grid}

      {pos, new_state} = AntColony.compute_step(state)

      assert pos == position
      assert new_state.target != target
    end
  end

  describe "get_shared_data/1" do
    test "returns ant_colony type with non-zero grid cells" do
      grid = %{{0, 0} => 1.0, {1, 1} => 0.0, {2, 2} => 0.5}
      state = %{pheromone_grid: grid}
      data = AntColony.get_shared_data(state)

      assert data.type == :ant_colony
      assert map_size(data.grid) == 2
      refute Map.has_key?(data.grid, {1, 1})
    end

    test "returns empty grid when no pheromone deposited" do
      state = %{}
      data = AntColony.get_shared_data(state)

      assert data.type == :ant_colony
      assert data.grid == %{}
    end
  end

  describe "handle_received_data/3" do
    test "merges remote grid using max per cell" do
      local_grid = %{{0, 0} => 1.0, {1, 1} => 3.0}
      remote_grid = %{{0, 0} => 2.0, {1, 1} => 1.0, {2, 2} => 5.0}
      data = %{type: :ant_colony, grid: remote_grid}
      state = %{pheromone_grid: local_grid}

      new_state = AntColony.handle_received_data(self(), data, state)
      merged = new_state.pheromone_grid

      assert Map.get(merged, {0, 0}) == 2.0
      assert Map.get(merged, {1, 1}) == 3.0
      assert Map.get(merged, {2, 2}) == 5.0
    end

    test "ignores non-ant_colony data" do
      state = %{pheromone_grid: %{}}
      new_state = AntColony.handle_received_data(self(), %{type: :other}, state)

      assert new_state == state
    end
  end

  describe "format_state/1" do
    test "returns structured format with overlay and target" do
      grid = %{{0, 0} => 2.0, {1, 1} => 1.0}
      algo_state = %{pheromone_grid: grid, target: %{x: 100, y: 100}}

      formatted = AntColony.format_state(algo_state)

      assert %{detail_fields: fields, overlay: overlay} = formatted
      assert Enum.any?(fields, &(&1.label == "Target" and &1.type == "position"))
      assert overlay.color == "59, 130, 246"
      assert length(overlay.cells) == 2
    end

    test "returns nil overlay when grid is empty" do
      algo_state = %{pheromone_grid: %{}, target: nil}

      formatted = AntColony.format_state(algo_state)

      assert %{detail_fields: [], overlay: nil} = formatted
    end
  end
end
