# AimRandomWalk

**Módulo:** `Simulator.Algorithms.AimRandomWalk`
**Archivo:** `lib/simulator/algorithms/impl/aim_random_walk.ex`
**Registro:** `"aim_random_walk"`

## Descripción

Caminata dirigida: el dron elige un punto objetivo aleatorio en el mapa y camina hacia él
paso a paso. Al llegar al objetivo o al colisionar con un obstáculo, genera un nuevo
objetivo aleatorio.

## Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `@step_size` | 5 | Píxeles de avance por tick |
| `@arrival_threshold` | 3 | Distancia mínima para considerar que llegó al objetivo |

## Comportamiento

1. **Inicialización:** Si no hay target, genera uno con `Geometry.random_open_point/2`
2. **Llegada:** Si la distancia al target ≤ `@arrival_threshold`, genera nuevo target y se queda en su lugar
3. **Movimiento:** Calcula un paso hacia el target con `Geometry.step_toward/4`
4. **Colisión:** Si el path al candidato colisiona con un obstáculo, genera nuevo target y se queda en su lugar

## Callbacks implementados

| Callback | Implementado |
|----------|:------------:|
| `compute_step/1` | Si |
| `get_shared_data/1` | No |
| `handle_received_data/3` | No |
| `format_state/1` | No |

## Estado interno

| Key | Tipo | Descripción |
|-----|------|-------------|
| `:target` | `%{x, y}` | Punto objetivo actual |

## Dependencias

- `Geometry.euclidean_distance/2` — calcular distancia al target
- `Geometry.step_toward/4` — avanzar un paso hacia el target
- `Geometry.path_collides?/3` — detección de colisiones
- `Geometry.random_open_point/2` — generar targets fuera de obstáculos
