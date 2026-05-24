# RandomWalk

**Module:** `Simulator.Algorithms.RandomWalk`
**File:** `lib/simulator/algorithms/impl/random_walk.ex`
**Registry:** `"random_walk"`

## Description

Random walk: on each tick, shifts the position by a small random delta on X and Y.
If the candidate move collides with an obstacle, retries up to `@max_attempts` times.
This is the default algorithm when an unrecognized name is provided.

## Constants

| Constant | Value | Description |
|-----------|-------|-------------|
| `@max_attempts` | 10 | Maximum retries to find a valid move |

## Behavior

1. Generates a candidate: `position ± random(-5..5)` on each axis, clamped to the map
2. Checks path collision with `Geometry.path_collides?/3`
3. If it collides, retries (up to `@max_attempts`). If exhausted, stays in place
4. Does not modify the algorithm state

## Implemented callbacks

| Callback | Implemented |
|----------|:-----------:|
| `compute_step/1` | Yes |
| `get_shared_data/1` | No |
| `handle_received_data/3` | No |
| `format_state/1` | No |

## Internal state

None. The state is returned unchanged.

## Dependencies

- `Geometry.clamp/3` — constrain the position within the map
- `Geometry.path_collides?/3` — collision detection against obstacles
