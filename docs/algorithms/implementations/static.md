# Static

**Module:** `Simulator.Algorithms.Static`
**File:** `lib/simulator/algorithms/impl/static.ex`
**Registry:** `"static"`

## Description

Null algorithm: the drone stays motionless at its initial position. Useful for
testing and as a comparison baseline.

## Behavior

- `compute_step/1` returns the current position without modifying it
- No internal state
- No communication

## Implemented callbacks

| Callback | Implemented |
|----------|:-----------:|
| `compute_step/1` | Yes |
| `get_shared_data/1` | No |
| `handle_received_data/3` | No |
| `format_state/1` | No |

## Internal state

None. The state is returned unchanged.
