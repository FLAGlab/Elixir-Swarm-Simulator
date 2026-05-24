# AimRandomWalk

**Module:** `Simulator.Algorithms.AimRandomWalk`
**File:** `lib/simulator/algorithms/impl/aim_random_walk.ex`
**Registry:** `"aim_random_walk"`

## Description

Directed walk: the drone picks a random target point on the map and walks toward it
step by step. When it reaches the target or collides with an obstacle, it generates
a new random target.

## Constants

| Constant | Value | Description |
|-----------|-------|-------------|
| `@step_size` | 5 | Pixels advanced per tick |
| `@arrival_threshold` | 3 | Minimum distance to consider the target reached |

## Behavior

1. **Initialization:** If there is no target, generates one with `Geometry.random_open_point/2`
2. **Arrival:** If the distance to the target ≤ `@arrival_threshold`, generates a new target and stays in place
3. **Movement:** Computes a step toward the target with `Geometry.step_toward/4`
4. **Collision:** If the path to the candidate collides with an obstacle, generates a new target and stays in place

## Implemented callbacks

| Callback | Implemented |
|----------|:-----------:|
| `compute_step/1` | Yes |
| `get_shared_data/1` | No |
| `handle_received_data/3` | No |
| `format_state/1` | No |

## Internal state

| Key | Type | Description |
|-----|------|-------------|
| `:target` | `%{x, y}` | Current target point |

## Dependencies

- `Geometry.euclidean_distance/2` — compute distance to the target
- `Geometry.step_toward/4` — advance one step toward the target
- `Geometry.path_collides?/3` — collision detection
- `Geometry.random_open_point/2` — generate targets outside obstacles
