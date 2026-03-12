# RandomWalk

**Módulo:** `Simulator.Algorithms.RandomWalk`
**Archivo:** `lib/simulator/algorithms/impl/random_walk.ex`
**Registro:** `"random_walk"`

## Descripción

Caminata aleatoria: en cada tick, desplaza la posición en X e Y por un delta random
pequeño. Si el movimiento candidato colisiona con un obstáculo, reintenta hasta
`@max_attempts` veces. Es el algoritmo por defecto cuando se proporciona un nombre
no reconocido.

## Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `@max_attempts` | 10 | Reintentos máximos para encontrar un movimiento válido |

## Comportamiento

1. Genera un candidato: `position ± random(-5..5)` en cada eje, clampeado al mapa
2. Verifica colisión del path con `Geometry.path_collides?/3`
3. Si colisiona, reintenta (hasta `@max_attempts`). Si se agotan, se queda en su lugar
4. No modifica el estado del algoritmo

## Callbacks implementados

| Callback | Implementado |
|----------|:------------:|
| `compute_step/1` | Si |
| `get_shared_data/1` | No |
| `handle_received_data/3` | No |
| `format_state/1` | No |

## Estado interno

Ninguno. El estado se retorna sin modificaciones.

## Dependencias

- `Geometry.clamp/3` — limitar posición dentro del mapa
- `Geometry.path_collides?/3` — detección de colisiones con obstáculos
