# ParticleSwarm (PSO)

**Module:** `Simulator.Algorithms.ParticleSwarm`
**File:** `lib/simulator/algorithms/impl/particle_swarm.ex`
**Registry:** `"particle_swarm"`

## Description

Particle Swarm Optimization for blind search in continuous 2D space. Designed to
find a static objective that emits no proximity signal — particles must physically
reach the objective to detect it.

It operates in two implicit modes determined by whether the objective has been found
or not.

## Constants

| Constant | Value | Description |
|-----------|-------|-------------|
| `@max_speed` | 8.0 | Maximum speed in pixels per tick |
| `@inertia` | 0.6 | Inertia factor (weight of the previous velocity) |
| `@cognitive_weight` | 1.5 | Attraction weight toward personal best |
| `@social_weight` | 1.5 | Attraction weight toward global best (objective) |
| `@repulsion_radius` | 80.0 | Repulsion radius between particles (exploration) |
| `@repulsion_strength` | 3.0 | Repulsion strength between particles |
| `@wander_strength` | 4.0 | Magnitude of the random component during exploration |

## Behavior

### Exploration mode (`objective_found` is `nil`)

Particles spread out to maximize coverage of the space:

**Velocity = inertia + wander + repulsion**

1. **Inertia:** `previous_velocity × @inertia`
2. **Wander:** Random vector with magnitude `@wander_strength`
3. **Repulsion:** Force inversely proportional to the distance from each neighbor
   within `@repulsion_radius`. Pushes particles away from each other.

**Personal best:** Updated when the current position is farther from neighbors than
the current personal best — this rewards exploring less-covered zones.

### Convergence mode (`objective_found` is `%{x, y}`)

Classic PSO equations:

**Velocity = inertia + cognitive + social**

1. **Inertia:** `previous_velocity × @inertia`
2. **Cognitive:** `@cognitive_weight × r1 × direction(position → personal_best)`
3. **Social:** `@social_weight × r2 × direction(position → objective)`

Where `r1` and `r2` are uniform random values in `[0, 1)`.

### Collision handling

If the path to the candidate collides with an obstacle, the velocity is inverted and
halved (`bounce`): `velocity = -velocity × 0.5`. The position does not change.

### Maximum speed

The velocity is clamped to `@max_speed` by normalizing the vector when its magnitude
exceeds the limit.

### Communication
- **Broadcast:** If it found the objective, shares `%{type: :pso, objective: %{x, y}}`.
  Otherwise, shares `%{}` (nothing).
- **Reception:** If it receives an objective and does not yet have one, stores it in
  `:objective_found`. Ignores it if it already has one (first detection wins).
- **Propagation:** The objective information propagates transitively as drones meet.

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
| `:velocity` | `%{vx, vy}` | Current particle velocity |
| `:personal_best` | `%{x, y}` | Best position found (farthest from neighbors) |
| `:objective_found` | `%{x, y} \| nil` | Objective location, `nil` during exploration |

## format_state

Removes `:velocity` and `:personal_best` from the exposed state.

## Dependencies

- `Geometry` — clamp, euclidean_distance, path_collides?
