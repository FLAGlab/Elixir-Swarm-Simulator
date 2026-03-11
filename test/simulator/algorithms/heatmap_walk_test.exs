defmodule Simulator.Algorithms.HeatmapWalkTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.HeatmapWalk
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
    test "generates a target on first tick" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}
      {_pos, new_state} = HeatmapWalk.compute_step(state)

      assert Map.has_key?(new_state, :target)
    end

    test "records visited positions" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}

      {_pos, state2} = HeatmapWalk.compute_step(state)
      {_pos, state3} = HeatmapWalk.compute_step(Map.put(state2, :position, %{x: 255, y: 255}))

      visited = Map.get(state3, :visited, [])
      assert length(visited) > 0
    end

    test "keeps position within map bounds" do
      state = %{position: %{x: 2, y: 2}, map: @clean_map, target: %{x: 0, y: 0}}
      {pos, _} = HeatmapWalk.compute_step(state)

      assert pos.x >= 0 and pos.x <= @clean_map.width
      assert pos.y >= 0 and pos.y <= @clean_map.height
    end

    test "recalculates target on collision" do
      position = %{x: 395, y: 250}
      target = %{x: 500, y: 250}
      state = %{position: position, map: @obstacle_map, target: target}

      {pos, new_state} = HeatmapWalk.compute_step(state)

      assert pos == position
      assert new_state.target != target
    end
  end

  describe "get_shared_data/1" do
    test "returns heatmap type with knowledge" do
      state = %{position: %{x: 100, y: 100}, visited: [%{x: 50, y: 50}]}
      data = HeatmapWalk.get_shared_data(state)

      assert data.type == :heatmap
      assert is_map(data.knowledge)
    end
  end

  describe "handle_received_data/3" do
    test "merges incoming heatmap knowledge" do
      source = spawn(fn -> :ok end)
      incoming = %{type: :heatmap, knowledge: %{source => [%{x: 10, y: 10}]}}
      state = %{received_visited: %{}}

      new_state = HeatmapWalk.handle_received_data(self(), incoming, state)

      assert Map.has_key?(new_state.received_visited, source)
    end

    test "ignores non-heatmap data" do
      state = %{received_visited: %{}}
      new_state = HeatmapWalk.handle_received_data(self(), %{type: :other}, state)

      assert new_state == state
    end
  end

  describe "format_state/1" do
    test "combines visited and received into single visited list" do
      algo_state = %{
        visited: [%{x: 1, y: 1}],
        received_visited: %{self() => [%{x: 2, y: 2}]},
        target: %{x: 100, y: 100}
      }

      formatted = HeatmapWalk.format_state(algo_state)

      assert length(formatted.visited) == 2
      refute Map.has_key?(formatted, :received_visited)
    end
  end
end
