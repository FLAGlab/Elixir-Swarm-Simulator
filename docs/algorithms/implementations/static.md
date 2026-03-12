# Static

**Módulo:** `Simulator.Algorithms.Static`
**Archivo:** `lib/simulator/algorithms/impl/static.ex`
**Registro:** `"static"`

## Descripción

Algoritmo nulo: el dron permanece inmóvil en su posición inicial. Útil para testing
y como baseline de comparación.

## Comportamiento

- `compute_step/1` retorna la posición actual sin modificarla
- No utiliza estado interno
- No implementa comunicación

## Callbacks implementados

| Callback | Implementado |
|----------|:------------:|
| `compute_step/1` | Si |
| `get_shared_data/1` | No |
| `handle_received_data/3` | No |
| `format_state/1` | No |

## Estado interno

Ninguno. El estado se retorna sin modificaciones.
