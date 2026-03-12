# AntColony

**Módulo:** `Simulator.Algorithms.AntColony`
**Archivo:** `lib/simulator/algorithms/impl/ant_colony.ex`
**Registro:** `"ant_colony"`

## Descripción

Optimización por Colonia de Hormigas adaptada para exploración 2D continua. Implementa un
sistema de "feromonas negativas": las hormigas depositan feromona en las celdas que visitan,
marcándolas como "exploradas, sin objetivo aquí". Al elegir un nuevo target, las celdas con
menos feromona (zonas inexploradas) tienen mayor probabilidad de ser seleccionadas.

Las feromonas se evaporan multiplicativamente cada tick, permitiendo la re-exploración
de zonas antiguas.

## Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `@step_size` | 5 | Píxeles de avance por tick |
| `@arrival_threshold` | 3 | Distancia mínima para considerar llegada |
| `@cell_size` | 20 | Tamaño de celda del grid de feromonas en píxeles |
| `@evaporation_rate` | 0.02 | Factor de evaporación por tick (2%) |
| `@deposit_amount` | 1.0 | Cantidad de feromona depositada por visita |

## Comportamiento

### Movimiento
1. **Inicialización:** Si no hay grid, crea uno con `Geometry.build_cell_grid/3` (valor 0.0)
2. **Evaporación:** Multiplica cada celda por `(1 - @evaporation_rate)`
3. **Depósito:** Incrementa la celda actual en `@deposit_amount`
4. **Target:** Si no hay target o llegó al actual, elige uno por selección ponderada
5. **Movimiento:** Avanza hacia el target con `Geometry.step_toward/4`
6. **Colisión:** Si el path colisiona, elige nuevo target y se queda

### Selección de target ponderada
1. Calcula peso de cada celda: `1.0 / (1.0 + nivel_feromona)` — inversamente proporcional
2. Celdas dentro de obstáculos reciben peso 0.0
3. Selección por ruleta: random ponderado sobre los pesos
4. Genera punto random dentro de la celda elegida
5. Si cae en obstáculo, usa `random_open_point` como fallback

### Comunicación
- **Broadcast:** Comparte las celdas con feromona > 0 del grid
- **Recepción:** Merge por `max` por celda — inherentemente idempotente, sin problema de eco
  (recibir tu propio grid de vuelta no infla valores porque `max(local, local) == local`)
- **Tipo de mensaje:** `%{type: :ant_colony, grid: %{{col, row} => float}}`

## Callbacks implementados

| Callback | Implementado |
|----------|:------------:|
| `compute_step/1` | Si |
| `get_shared_data/1` | Si |
| `handle_received_data/3` | Si |
| `format_state/1` | Si |

## Estado interno

| Key | Tipo | Descripción |
|-----|------|-------------|
| `:target` | `%{x, y}` | Punto objetivo actual |
| `:pheromone_grid` | `%{{col, row} => float}` | Grid de niveles de feromona por celda |

## format_state

Convierte `:pheromone_grid` a `:pheromone_overlay` (lista de `%{x, y, intensity}` normalizados
entre 0 y 1) para renderizado en el frontend. Elimina `:pheromone_grid`.

## Dependencias

- `Geometry` — step_toward, path_collides?, euclidean_distance, build_cell_grid, position_to_cell, cell_to_point, random_open_point, inside_structure?
