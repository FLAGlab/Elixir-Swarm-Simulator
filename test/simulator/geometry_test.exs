defmodule Simulator.GeometryTest do
  use ExUnit.Case, async: true

  alias Simulator.Geometry
  alias Simulator.Maps.MapParams

  # Square from (0,0) to (10,10)
  @square [{0, 0}, {10, 0}, {10, 10}, {0, 10}]

  @structures [%{id: 1, points: @square}]

  @map %MapParams{width: 100, height: 100, structures: @structures}

  describe "clamp/3" do
    test "returns min when value is below" do
      assert Geometry.clamp(-5, 0, 100) == 0
    end

    test "returns max when value is above" do
      assert Geometry.clamp(150, 0, 100) == 100
    end

    test "returns value when in range" do
      assert Geometry.clamp(50, 0, 100) == 50
    end
  end

  describe "euclidean_distance/2" do
    test "returns zero for same point" do
      assert Geometry.euclidean_distance(%{x: 5, y: 5}, %{x: 5, y: 5}) == 0.0
    end

    test "returns correct distance for known points" do
      assert Geometry.euclidean_distance(%{x: 0, y: 0}, %{x: 3, y: 4}) == 5.0
    end
  end

  describe "point_in_polygon?/2" do
    test "returns true for point inside polygon" do
      assert Geometry.point_in_polygon?({5, 5}, @square)
    end

    test "returns false for point outside polygon" do
      refute Geometry.point_in_polygon?({15, 5}, @square)
    end

    test "returns false for point clearly outside" do
      refute Geometry.point_in_polygon?({-5, -5}, @square)
    end

    test "returns false for degenerate polygon with fewer than 3 points" do
      refute Geometry.point_in_polygon?({5, 5}, [{0, 0}, {10, 10}])
    end

    test "works with non-square polygons" do
      triangle = [{0, 0}, {10, 0}, {5, 10}]
      assert Geometry.point_in_polygon?({5, 3}, triangle)
      refute Geometry.point_in_polygon?({1, 9}, triangle)
    end
  end

  describe "segment_intersects_polygon?/3" do
    test "returns true when segment crosses polygon edge" do
      assert Geometry.segment_intersects_polygon?({-5, 5}, {5, 5}, @square)
    end

    test "returns false when segment is fully outside" do
      refute Geometry.segment_intersects_polygon?({-5, 5}, {-2, 5}, @square)
    end

    test "returns false for degenerate polygon" do
      refute Geometry.segment_intersects_polygon?({0, 0}, {5, 5}, [{0, 0}])
    end

    test "returns true when segment passes through polygon" do
      assert Geometry.segment_intersects_polygon?({-5, 5}, {15, 5}, @square)
    end
  end

  describe "inside_structure?/2" do
    test "returns true when point is inside a structure" do
      assert Geometry.inside_structure?({5, 5}, @structures)
    end

    test "returns false when point is outside all structures" do
      refute Geometry.inside_structure?({50, 50}, @structures)
    end

    test "returns false for empty structures list" do
      refute Geometry.inside_structure?({5, 5}, [])
    end
  end

  describe "path_collides?/3" do
    test "returns true when destination is inside a structure" do
      assert Geometry.path_collides?({-5, 5}, {5, 5}, @structures)
    end

    test "returns true when path crosses a structure" do
      assert Geometry.path_collides?({-5, 5}, {15, 5}, @structures)
    end

    test "returns false when path is clear" do
      refute Geometry.path_collides?({50, 50}, {60, 60}, @structures)
    end

    test "returns false for empty structures list" do
      refute Geometry.path_collides?({0, 0}, {5, 5}, [])
    end
  end

  describe "random_open_point/3" do
    test "generates a point within map bounds" do
      point = Geometry.random_open_point(@map, %{x: 50, y: 50})

      assert point.x in 0..@map.width
      assert point.y in 0..@map.height
    end

    test "generated point is not inside any structure" do
      point = Geometry.random_open_point(@map, %{x: 50, y: 50})
      refute Geometry.inside_structure?({point.x, point.y}, @structures)
    end

    test "returns fallback when map is fully obstructed" do
      # Polygon larger than map to ensure all generated points land inside
      full_map = %MapParams{
        width: 10,
        height: 10,
        structures: [%{id: 1, points: [{-1, -1}, {11, -1}, {11, 11}, {-1, 11}]}]
      }

      fallback = %{x: 99, y: 99}
      assert Geometry.random_open_point(full_map, fallback, 5) == fallback
    end
  end

  describe "step_toward/4" do
    test "moves closer to target" do
      position = %{x: 0, y: 0}
      target = %{x: 100, y: 0}
      result = Geometry.step_toward(position, target, @map, 5)

      assert result.x > position.x
      assert result.y == position.y
    end

    test "clamps within map bounds" do
      position = %{x: 99, y: 99}
      target = %{x: 200, y: 200}
      result = Geometry.step_toward(position, target, @map, 10)

      assert result.x <= @map.width
      assert result.y <= @map.height
    end
  end
end
