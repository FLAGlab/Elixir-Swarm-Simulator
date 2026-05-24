# HeatmapWalk

**Module:** `Simulator.Algorithms.HeatmapWalk`
**File:** `lib/simulator/algorithms/impl/heatmap_walk.ex`
**Registry:** `"heatmap_walk"`

## Description

Heatmap-guided walk: similar to `AimRandomWalk`, but it picks targets in the
least-visited zones of the map. It divides the space into cells and builds a heatmap
from visited positions. When choosing a new target, it randomly selects among the
cells with the lowest visit count ("cold cells").

Drones share their knowledge of visited positions with neighbors through the
`KnowledgeStore`, which enables cooperative exploration: one drone avoids zones that
another has already explored.

## Constants

| Constant | Value | Description |
|-----------|-------|-------------|
| `@step_size` | 5 | Pixels advanced per tick |
| `@arrival_threshold` | 3 | Minimum distance to consider arrival |
| `@history_size` | 200 | Maximum size of the rolling window of own positions |
| `@cell_size` | 20 | Grid cell size in pixels |

## Behavior

### Movement
1. **Decay:** On each tick, applies `KnowledgeStore.decay/1` to received knowledge
2. **Total knowledge:** Combines own + received positions with `KnowledgeStore.all_positions/2`
3. **Target:** If there is no target, or it has reached the current one, builds the heat grid and picks a target in a cold cell
4. **Movement:** Advances toward the target with `Geometry.step_toward/4`
5. **Collision:** If the path collides, picks a new cold target and stays in place
6. **Logging:** On every move, records the position into `:visited` (rolling window of `@history_size`)

### Cold target selection
1. Builds the base grid with `Geometry.build_cell_grid/2`
2. Increments the count for each visited position (own + received)
3. Finds the minimum heat value
4. Randomly selects among the cells with that minimum value
5. Generates a random point inside the chosen cell
6. If the point falls inside an obstacle, falls back to `random_open_point`

### Communication
- **Broadcast:** Shares knowledge via `KnowledgeStore.build_shareable/2` — includes
  own positions (keyed by self PID) + received knowledge (transitive)
- **Reception:** Merges via `KnowledgeStore.merge/2` — automatic anti-echo, freshness by length
- **Message type:** `%{type: :heatmap, knowledge: %{source_pid => [positions]}}`

## Implemented callbacks

| Callback | Implemented |
|----------|:-----------:|
| `compute_step/1` | Yes |
| `get_shared_data/1` | Yes |
| `handle_received_data/3` | Yes |
| `format_state/1` | Yes |

## Internal state

| Key | Type | Description |
|-----|------|-------------|
| `:target` | `%{x, y}` | Current target point |
| `:visited` | `[%{x, y}]` | Rolling window of own positions (max `@history_size`) |
| `:received_visited` | `%{pid => [%{x, y}]}` | Received knowledge, keyed by original source |

## format_state

Merges `:visited` + `:received_visited` into a single `:visited` list and removes
`:received_visited` using `KnowledgeStore.format_for_export/1`.

## Dependencies

- `Geometry` — step_toward, path_collides?, euclidean_distance, build_cell_grid, position_to_cell, cell_to_point, random_open_point, inside_structure?
- `KnowledgeStore` — decay, merge, all_positions, build_shareable, format_for_export
