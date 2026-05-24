# Geometry

**Module:** `Simulator.Algorithms.Helpers.Geometry`
**File:** `lib/simulator/algorithms/helpers/geometry.ex`

Geometric and spatial utilities for algorithm implementations. Provides primitives
(distance, clamping, polygon tests) and high-level helpers (collisions, point
generation, directed steps, cell grids).

## Primitives

### `clamp(value, min, max)`

Constrains a numeric value between a minimum and a maximum.

```elixir
Geometry.clamp(15, 0, 10)  #=> 10
Geometry.clamp(-3, 0, 10)  #=> 0
Geometry.clamp(5, 0, 10)   #=> 5
```

**Typical use:** constraining coordinates within map bounds.

---

### `euclidean_distance(p1, p2)`

Euclidean distance between two `%{x, y}` points.

```elixir
Geometry.euclidean_distance(%{x: 0, y: 0}, %{x: 3, y: 4})  #=> 5.0
```

**Typical use:** check whether a drone has reached its target, distances between neighbors.

---

### `point_in_polygon?({x, y}, points)`

Checks whether a point lies inside a polygon using the ray-casting algorithm.
It casts a horizontal ray from the point to the right and counts how many polygon
edges it crosses. If the count is odd, the point is inside.

- `point` — `{x, y}` tuple
- `points` — list of `{x, y}` tuples for the polygon's vertices
- Returns `false` for degenerate polygons (< 3 vertices)

**Typical use:** check whether a candidate point falls inside an obstacle.

---

### `segment_intersects_polygon?(p1, p2, points)`

Checks whether a line segment intersects any edge of a polygon.
Uses cross-product sign tests to determine intersection.

- `p1`, `p2` — `{x, y}` tuples for the segment endpoints
- `points` — polygon vertices
- Returns `false` for degenerate polygons (< 3 vertices)

**Typical use:** check whether a movement path crosses an obstacle.

## Map helpers

### `inside_structure?({x, y}, structures)`

Checks whether a point falls inside any map structure.

- `structures` — list of `%{points: [{x, y}]}` from `MapParams`
- Returns `false` for an empty list of structures

**Typical use:** validate that a generated target is not inside an obstacle.

---

### `path_collides?(from, to, structures)`

Checks whether moving from one point to another would collide with any structure.
Combines `point_in_polygon?` (destination inside an obstacle) and
`segment_intersects_polygon?` (path crosses an obstacle).

- `from`, `to` — `{x, y}` tuples
- `structures` — list of map structures
- Returns `false` for an empty list of structures

**Typical use:** decide whether a candidate move is valid before executing it.

---

### `random_open_point(map, fallback, max_attempts \\ 50)`

Generates a random point within the map bounds that does not fall inside any
obstacle. Uses rejection sampling: generates candidates and discards those that
fall inside obstacles, up to `max_attempts` attempts. If exhausted, returns `fallback`.

- `map` — `%MapParams{width, height, structures}`
- `fallback` — `%{x, y}` safe fallback position
- Returns `%{x, y}`

**Typical use:** generate random targets for directed-walk algorithms.

---

### `step_toward(position, target, map, step_size)`

Computes the candidate position one step away in the direction of the target.
Normalizes the direction vector, scales it by `step_size`, and clamps the result
within the map.

- `position` — `%{x, y}` current position
- `target` — `%{x, y}` destination
- `map` — `%MapParams` for clamping
- `step_size` — pixels to advance
- Returns `%{x: integer(), y: integer()}` (rounded coordinates)

**Typical use:** advance one step toward an objective on each tick.

## Grid helpers

### `position_to_cell(position, cell_size)`

Converts a `%{x, y}` position to its grid cell `{col, row}`.

```elixir
Geometry.position_to_cell(%{x: 45, y: 63}, 20)  #=> {2, 3}
```

---

### `cell_to_point({col, row}, cell_size, map)`

Generates a random point within a grid cell, clamped to the map bounds.

```elixir
Geometry.cell_to_point({2, 3}, 20, map_params)  #=> %{x: 42, y: 67}  (example)
```

---

### `build_cell_grid(map, cell_size, default_value \\ 0)`

Creates a cell map `%{{col, row} => default_value}` covering the entire map.
The number of columns and rows is computed as `div(dimension, cell_size) + 1`.

```elixir
Geometry.build_cell_grid(%MapParams{width: 100, height: 60}, 20, 0.0)
#=> %{{0,0} => 0.0, {0,1} => 0.0, ..., {5,3} => 0.0}
```

**Typical use:** initialize pheromone grids (AntColony) or heat grids (HeatmapWalk).

## Internal private functions

- `polygon_edges/1` — generates pairs of consecutive polygon vertices (including closure)
- `ray_crosses_edge?/6` — horizontal ray crossing test against an edge
- `segments_intersect?/4` — segment-segment intersection test via cross product
- `cross/3` — 2D cross product of three points
- `do_random_open_point/3` — recursive implementation of rejection sampling
