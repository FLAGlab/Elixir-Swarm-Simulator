defmodule Simulator.Algorithms.AimRandomWalkTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.AimRandomWalk
  alias Simulator.Maps.MapParams

  @clean_map %MapParams{width: 500, height: 500, structures: []}

  @obstacle_map %MapParams{
    width: 1000,
    height: 500,
    structures: [
      %{id: 1, points: [{400, 150}, {600, 150}, {600, 350}, {400, 350}]}
    ]
  }

  describe "compute_step/1" do
    test "generates a target on the first tick" do
      state = %{position: %{x: 255, y: 255}, map: @clean_map}
      {_position, new_state} = AimRandomWalk.compute_step(state)

      assert Map.has_key?(new_state, :target)
      assert is_integer(new_state.target.x)
      assert is_integer(new_state.target.y)
    end

    test "moves closer to the target each tick" do
      target = %{x: 300, y: 300}
      position = %{x: 100, y: 100}
      state = %{position: position, map: @clean_map, target: target}

      {new_position, _new_state} = AimRandomWalk.compute_step(state)

      old_distance = distance(position, target)
      new_distance = distance(new_position, target)

      assert new_distance < old_distance
    end

    test "generates a new target when arriving at the current one" do
      target = %{x: 100, y: 100}
      position = %{x: 101, y: 101}
      state = %{position: position, map: @clean_map, target: target}

      {returned_position, new_state} = AimRandomWalk.compute_step(state)

      # Should stay in place and pick a new target
      assert returned_position == position
      assert new_state.target != target
    end

    test "keeps position within map bounds" do
      target = %{x: 0, y: 0}
      position = %{x: 2, y: 2}
      state = %{position: position, map: @clean_map, target: target}

      {new_position, _new_state} = AimRandomWalk.compute_step(state)

      assert new_position.x >= 0 and new_position.x <= @clean_map.width
      assert new_position.y >= 0 and new_position.y <= @clean_map.height
    end

    test "recalculates target when path collides with obstacle" do
      # Agent at left of obstacle, target behind it
      position = %{x: 395, y: 250}
      target = %{x: 605, y: 250}
      state = %{position: position, map: @obstacle_map, target: target}

      {new_position, new_state} = AimRandomWalk.compute_step(state)

      # Should stay in place and pick a new target
      assert new_position == position
      assert new_state.target != target
    end

    test "works correctly on a map without obstacles" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map}

      {new_position, new_state} = AimRandomWalk.compute_step(state)

      assert Map.has_key?(new_state, :target)
      assert new_position.x in 0..@clean_map.width
      assert new_position.y in 0..@clean_map.height
    end

    test "generated target is not inside any obstacle" do
      state = %{position: %{x: 100, y: 100}, map: @obstacle_map}

      {_position, new_state} = AimRandomWalk.compute_step(state)

      target = new_state.target
      obstacle = hd(@obstacle_map.structures)

      refute Simulator.Geometry.point_in_polygon?(
               {target.x, target.y},
               obstacle.points
             )
    end
  end

  # Helpers ----------------------------------------------------------

  defp distance(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    dx = x2 - x1
    dy = y2 - y1
    :math.sqrt(dx * dx + dy * dy)
  end
end
