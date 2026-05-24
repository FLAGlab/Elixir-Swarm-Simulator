# GreyWolf (GWO)

**Module:** `Simulator.Algorithms.GreyWolf`
**File:** `lib/simulator/algorithms/impl/grey_wolf.ex`
**Registry:** `"grey_wolf"`

## Description

Grey Wolf Optimizer modified for blind search in continuous 2D space. The pack
operates without prior knowledge of the objective, with a fixed role hierarchy
assigned by drone ID.

## Constants

| Constant | Value | Description |
|-----------|-------|-------------|
| `@step_size` | 5 | Pixels advanced per tick |
| `@arrival_threshold` | 3 | Minimum distance to consider arrival |
| `@min_leader_distance` | 150.0 | Minimum safety distance between leaders |
| `@repulsion_strength` | 2.0 | Repulsion strength between leaders |
| `@omega_spread` | 60 | Offset radius for omega targets around a leader |
| `@a_initial` | 2.0 | Initial value of GWO's `a` parameter |
| `@a_decay` | 0.005 | Decrement of `a` per tick during convergence |

## Behavior

### Role assignment

Roles are assigned deterministically by drone ID:

| ID | Role |
|----|------|
| 1 | Alpha |
| 2 | Beta |
| 3 | Delta |
| ≥4 | Omega |

### Scattered hunt phase (`objective_found` is `nil`)

#### Leaders (Alpha, Beta, Delta)

Each leader patrols an assigned zone of the map:

| Role | Zone center | Bounds |
|------|-------------|--------|
| Alpha | `(W/4, H/4)` | `[0, W/2] × [0, H/2]` (top-left quadrant) |
| Beta | `(3W/4, H/4)` | `[W/2, W] × [0, H/2]` (top-right quadrant) |
| Delta | `(W/2, 3H/4)` | `[0, W] × [H/2, H]` (entire bottom half) |

Leaders generate random targets within their bounds and walk toward them.
When they arrive, they generate a new target in their zone.

**Leader-to-leader repulsion:** If a leader is closer than `@min_leader_distance` to
another known leader, a repulsion force is applied that deflects the target. The force
is proportional to `(@min_leader_distance - distance) / @min_leader_distance`.

#### Omegas

Omegas track the closest known leader and generate targets with a random offset of
±`@omega_spread` pixels around the leader's position, providing local coverage.
If they don't know any leader, they fall back to `random_open_point`.

### Convergence phase (`objective_found` is `%{x, y}`)

All wolves use the classic GWO equations to surround the objective:

```
For each leader (alpha, beta, delta):
  A = 2·a·r1 - a
  C = 2·r2
  D = |C·leader_pos - pos|
  X_leader = leader_pos - A·D

Final position = (X_alpha + X_beta + X_delta) / 3
```

The `a` parameter decreases linearly from `@a_initial` (2.0) to 0 at rate `@a_decay`
(0.005) per tick. With high `a`, wolves explore widely; with low `a`, they converge
tightly.

If the leaders' positions are not available in `known_leaders`, the objective's
position is used as a fallback.

### Communication
- **Broadcast:** Shares `%{type: :gwo, role: atom, position: %{x,y}, objective: %{x,y} | nil}`
- **Reception:**
  - If the sender is a leader (alpha/beta/delta), updates its position in `:known_leaders`
  - If the message includes an objective and the receiver doesn't have one, stores it
  - Ignores messages with a type other than `:gwo`

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
| `:role` | `:alpha \| :beta \| :delta \| :omega` | Role assigned by ID |
| `:known_leaders` | `%{atom => %{x, y}}` | Known leader positions |
| `:objective_found` | `%{x, y} \| nil` | Objective location |
| `:target` | `%{x, y}` | Current movement target |
| `:a_param` | `float` | GWO's `a` parameter (only during convergence) |

## format_state

Removes `:known_leaders` and `:a_param` from the exposed state.

## Dependencies

- `Geometry` — clamp, euclidean_distance, step_toward, path_collides?, random_open_point, inside_structure?
