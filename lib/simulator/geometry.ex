defmodule Simulator.Geometry do
  @moduledoc """
  Geometric and spatial utilities for the simulation.

  Provides primitives (distance, clamping, polygon tests) and higher-level
  helpers (collision checks, random point generation, directed steps) that
  movement algorithms can compose without reimplementing navigation logic.
  """

  # Public API — Primitives ------------------------------------------

  @doc """
  Clamps a value between a minimum and maximum.

  ## Examples

      iex> Simulator.Geometry.clamp(15, 0, 10)
      10

      iex> Simulator.Geometry.clamp(-3, 0, 10)
      0

      iex> Simulator.Geometry.clamp(5, 0, 10)
      5
  """
  @spec clamp(number(), number(), number()) :: number()
  def clamp(value, min, max) do
    cond do
      value < min -> min
      value > max -> max
      true -> value
    end
  end

  @doc """
  Returns the Euclidean distance between two points.

  Points are maps with `:x` and `:y` keys.
  """
  @spec euclidean_distance(%{x: number(), y: number()}, %{x: number(), y: number()}) :: float()
  def euclidean_distance(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    dx = x2 - x1
    dy = y2 - y1
    :math.sqrt(dx * dx + dy * dy)
  end

  @doc """
  Checks if a point is inside a polygon using the ray-casting algorithm.

  Casts a horizontal ray from the point to the right and counts how many
  polygon edges it crosses. An odd count means the point is inside.

  `point` is `{x, y}` and `polygon` is a list of `{x, y}` vertex tuples.
  Returns `false` for degenerate polygons (fewer than 3 vertices).
  """
  @spec point_in_polygon?({number(), number()}, [{number(), number()}]) :: boolean()
  def point_in_polygon?(_point, polygon) when length(polygon) < 3, do: false

  def point_in_polygon?({px, py}, polygon) do
    polygon
    |> polygon_edges()
    |> Enum.count(fn {{x1, y1}, {x2, y2}} ->
      ray_crosses_edge?(px, py, x1, y1, x2, y2)
    end)
    |> rem(2) == 1
  end

  @doc """
  Checks if a line segment intersects any edge of a polygon.

  Uses cross-product sign tests to determine if the segment from `p1` to
  `p2` crosses any edge of the polygon. Returns `false` for degenerate
  polygons (fewer than 3 vertices).
  """
  @spec segment_intersects_polygon?(
          {number(), number()},
          {number(), number()},
          [{number(), number()}]
        ) :: boolean()
  def segment_intersects_polygon?(_p1, _p2, polygon) when length(polygon) < 3, do: false

  def segment_intersects_polygon?(p1, p2, polygon) do
    polygon
    |> polygon_edges()
    |> Enum.any?(fn {e1, e2} -> segments_intersect?(p1, p2, e1, e2) end)
  end

  # Public API — Map-aware helpers -----------------------------------

  @doc """
  Checks if a point `{x, y}` falls inside any structure polygon on the map.

  `structures` is the list from `%MapParams{}.structures`, where each
  structure has a `:points` key with a list of `{x, y}` vertex tuples.
  """
  @spec inside_structure?({number(), number()}, list()) :: boolean()
  def inside_structure?(_point, []), do: false

  def inside_structure?(point, structures) do
    Enum.any?(structures, fn structure ->
      point_in_polygon?(point, structure.points)
    end)
  end

  @doc """
  Checks if moving from one position to another would collide with any
  map structure.

  Returns `true` if the destination point lands inside a structure or the
  path segment crosses a structure edge.
  """
  @spec path_collides?(
          {number(), number()},
          {number(), number()},
          list()
        ) :: boolean()
  def path_collides?(_from, _to, []), do: false

  def path_collides?(from, to, structures) do
    Enum.any?(structures, fn structure ->
      polygon = structure.points

      point_in_polygon?(to, polygon) or
        segment_intersects_polygon?(from, to, polygon)
    end)
  end

  @doc """
  Generates a random point within the map bounds that does not fall inside
  any structure.

  Tries up to `max_attempts` times (default 50). If all attempts land inside
  an obstacle, returns `fallback` as a safe default.
  """
  @spec random_open_point(map(), %{x: number(), y: number()}, non_neg_integer()) ::
          %{x: number(), y: number()}
  def random_open_point(map, fallback, max_attempts \\ 50) do
    do_random_open_point(map, fallback, max_attempts)
  end

  @doc """
  Computes a candidate position one step toward a target, clamped within
  map bounds.

  Moves `step_size` pixels in the direction of `target` from `position`.
  """
  @spec step_toward(%{x: number(), y: number()}, %{x: number(), y: number()}, map(), number()) ::
          %{x: number(), y: number()}
  def step_toward(position, target, map, step_size) do
    dx = target.x - position.x
    dy = target.y - position.y
    dist = euclidean_distance(position, target)

    step_x = round(dx / dist * step_size)
    step_y = round(dy / dist * step_size)

    %{
      x: clamp(position.x + step_x, 0, map.width),
      y: clamp(position.y + step_y, 0, map.height)
    }
  end

  # Private ----------------------------------------------------------

  defp do_random_open_point(_map, fallback, 0) do
    %{x: fallback.x, y: fallback.y}
  end

  defp do_random_open_point(map, fallback, attempts_left) do
    candidate = %{x: Enum.random(0..map.width), y: Enum.random(0..map.height)}

    if inside_structure?({candidate.x, candidate.y}, map.structures) do
      do_random_open_point(map, fallback, attempts_left - 1)
    else
      candidate
    end
  end

  defp polygon_edges(points) do
    Enum.zip(points, tl(points) ++ [hd(points)])
  end

  defp ray_crosses_edge?(px, py, x1, y1, x2, y2) do
    y_in_range? = (y1 <= py and py < y2) or (y2 <= py and py < y1)

    if y_in_range? do
      x_intersect = x1 + (py - y1) / (y2 - y1) * (x2 - x1)
      px < x_intersect
    else
      false
    end
  end

  defp segments_intersect?(p1, p2, p3, p4) do
    d1 = cross(p3, p4, p1)
    d2 = cross(p3, p4, p2)
    d3 = cross(p1, p2, p3)
    d4 = cross(p1, p2, p4)

    d1 * d2 < 0 and d3 * d4 < 0
  end

  defp cross({ax, ay}, {bx, by}, {cx, cy}) do
    (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
  end
end
