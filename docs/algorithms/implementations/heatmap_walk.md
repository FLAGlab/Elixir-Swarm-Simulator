# HeatmapWalk

**Módulo:** `Simulator.Algorithms.HeatmapWalk`
**Archivo:** `lib/simulator/algorithms/impl/heatmap_walk.ex`
**Registro:** `"heatmap_walk"`

## Descripción

Caminata dirigida por heatmap: similar a `AimRandomWalk` pero elige targets en las zonas
menos visitadas del mapa. Divide el espacio en celdas y construye un mapa de calor con
las posiciones visitadas. Al elegir un nuevo target, selecciona aleatoriamente entre las
celdas con menor conteo de visitas ("celdas frías").

Los drones comparten su conocimiento de posiciones visitadas con vecinos a través del
`KnowledgeStore`, lo que permite exploración cooperativa: un dron evita zonas que otro
ya exploró.

## Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `@step_size` | 5 | Píxeles de avance por tick |
| `@arrival_threshold` | 3 | Distancia mínima para considerar llegada |
| `@history_size` | 200 | Tamaño máximo de la ventana de posiciones propias |
| `@cell_size` | 20 | Tamaño de celda del grid en píxeles |

## Comportamiento

### Movimiento
1. **Decay:** En cada tick, aplica `KnowledgeStore.decay/1` al conocimiento recibido
2. **Conocimiento total:** Combina posiciones propias + recibidas con `KnowledgeStore.all_positions/2`
3. **Target:** Si no hay target o llegó al actual, construye grid de calor y elige target en celda fría
4. **Movimiento:** Avanza hacia el target con `Geometry.step_toward/4`
5. **Colisión:** Si el path colisiona, elige nuevo target frío y se queda
6. **Registro:** En cada movimiento registra la posición en `:visited` (rolling window de `@history_size`)

### Selección de target frío
1. Construye grid base con `Geometry.build_cell_grid/2`
2. Incrementa conteo por cada posición visitada (propia + recibida)
3. Encuentra el valor mínimo de calor
4. Selecciona aleatoriamente entre las celdas con ese valor mínimo
5. Genera un punto random dentro de la celda elegida
6. Si el punto cae en un obstáculo, usa `random_open_point` como fallback

### Comunicación
- **Broadcast:** Comparte conocimiento con `KnowledgeStore.build_shareable/2` — incluye
  posiciones propias (keyed por self PID) + conocimiento recibido (transitivo)
- **Recepción:** Merge con `KnowledgeStore.merge/2` — anti-eco automático, frescura por longitud
- **Tipo de mensaje:** `%{type: :heatmap, knowledge: %{source_pid => [positions]}}`

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
| `:visited` | `[%{x, y}]` | Rolling window de posiciones propias (máx `@history_size`) |
| `:received_visited` | `%{pid => [%{x, y}]}` | Conocimiento recibido, keyed por fuente original |

## format_state

Combina `:visited` + `:received_visited` en una sola lista `:visited` y elimina
`:received_visited` usando `KnowledgeStore.format_for_export/1`.

## Dependencias

- `Geometry` — step_toward, path_collides?, euclidean_distance, build_cell_grid, position_to_cell, cell_to_point, random_open_point, inside_structure?
- `KnowledgeStore` — decay, merge, all_positions, build_shareable, format_for_export
