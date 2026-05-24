# AntColony

**Module:** `Simulator.Algorithms.AntColony`
**File:** `lib/simulator/algorithms/impl/ant_colony.ex`
**Registry:** `"ant_colony"`

## Description

Ant Colony Optimization adapted for continuous 2D exploration. It implements a
"negative pheromone" system: ants deposit pheromone on the cells they visit,
marking them as "explored, no objective here". When picking a new target, cells
with less pheromone (unexplored zones) have a higher probability of being chosen.

Pheromones evaporate multiplicatively on every tick, allowing old zones to be
re-explored.

## Constants

| Constant | Value | Description |
|-----------|-------|-------------|
| `@step_size` | 5 | Pixels advanced per tick |
| `@arrival_threshold` | 3 | Minimum distance to consider arrival |
| `@cell_size` | 20 | Pheromone grid cell size in pixels |
| `@evaporation_rate` | 0.02 | Evaporation factor per tick (2%) |
| `@deposit_amount` | 1.0 | Pheromone amount deposited per visit |

## Behavior

### Movement
1. **Initialization:** If there is no grid, builds one with `Geometry.build_cell_grid/3` (value 0.0)
2. **Evaporation:** Multiplies each cell by `(1 - @evaporation_rate)`
3. **Deposit:** Increments the current cell by `@deposit_amount`
4. **Target:** If there is no target, or it has reached the current one, picks a new one via weighted selection
5. **Movement:** Advances toward the target with `Geometry.step_toward/4`
6. **Collision:** If the path collides, picks a new target and stays in place

### Weighted target selection
1. Computes the weight of each cell: `1.0 / (1.0 + pheromone_level)` — inversely proportional
2. Cells inside obstacles get weight 0.0
3. Roulette selection: weighted random over the weights
4. Generates a random point inside the chosen cell
5. If it falls inside an obstacle, falls back to `random_open_point`

### Communication
- **Broadcast:** Shares the cells with pheromone > 0 from the grid
- **Reception:** Merge by `max` per cell — inherently idempotent, no echo problem
  (receiving your own grid back does not inflate values because `max(local, local) == local`)
- **Message type:** `%{type: :ant_colony, grid: %{{col, row} => float}}`

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
| `:pheromone_grid` | `%{{col, row} => float}` | Pheromone level grid per cell |

## format_state

Converts `:pheromone_grid` into `:pheromone_overlay` (a list of `%{x, y, intensity}`
normalized between 0 and 1) for frontend rendering. Removes `:pheromone_grid`.

## Dependencies

- `Geometry` — step_toward, path_collides?, euclidean_distance, build_cell_grid, position_to_cell, cell_to_point, random_open_point, inside_structure?
