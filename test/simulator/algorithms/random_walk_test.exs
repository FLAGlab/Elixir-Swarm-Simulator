defmodule Simulator.Algorithms.RandomWalkTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.RandomWalk
  alias Simulator.Maps.MapParams

  @clean_map %MapParams{width: 500, height: 500, structures: []}

  @obstacle_map %MapParams{
    width: 500,
    height: 500,
    structures: [
      %{id: 1, points: [{200, 200}, {300, 200}, {300, 300}, {200, 300}]}
    ]
  }

  describe "compute_step/1" do
    test "keeps position within map bounds" do
      state = %{position: %{x: 0, y: 0}, map: @clean_map}

      for _ <- 1..50 do
        {pos, _} = RandomWalk.compute_step(state)
        assert pos.x >= 0 and pos.x <= @clean_map.width
        assert pos.y >= 0 and pos.y <= @clean_map.height
      end
    end

    test "returns integer coordinates" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}
      {pos, _} = RandomWalk.compute_step(state)

      assert is_integer(pos.x)
      assert is_integer(pos.y)
    end

    test "does not modify algorithm state" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}
      {_pos, new_state} = RandomWalk.compute_step(state)

      assert new_state == state
    end

    test "avoids moving into obstacles" do
      # Position just outside the obstacle
      state = %{position: %{x: 195, y: 250}, map: @obstacle_map}

      for _ <- 1..50 do
        {pos, _} = RandomWalk.compute_step(state)

        refute Simulator.Algorithms.Helpers.Geometry.inside_structure?(
                 {pos.x, pos.y},
                 @obstacle_map.structures
               )
      end
    end
  end
end
