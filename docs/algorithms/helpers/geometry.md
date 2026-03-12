# Geometry

**Módulo:** `Simulator.Algorithms.Helpers.Geometry`
**Archivo:** `lib/simulator/algorithms/helpers/geometry.ex`

Utilidades geométricas y espaciales para implementaciones de algoritmos. Provee primitivas
(distancia, clamping, tests de polígonos) y helpers de alto nivel (colisiones, generación
de puntos, pasos dirigidos, grillas de celdas).

## Primitivas

### `clamp(value, min, max)`

Limita un valor numérico entre un mínimo y un máximo.

```elixir
Geometry.clamp(15, 0, 10)  #=> 10
Geometry.clamp(-3, 0, 10)  #=> 0
Geometry.clamp(5, 0, 10)   #=> 5
```

**Uso típico:** limitar coordenadas dentro de los bounds del mapa.

---

### `euclidean_distance(p1, p2)`

Distancia euclidiana entre dos puntos `%{x, y}`.

```elixir
Geometry.euclidean_distance(%{x: 0, y: 0}, %{x: 3, y: 4})  #=> 5.0
```

**Uso típico:** calcular si un dron llegó a su target, distancias entre vecinos.

---

### `point_in_polygon?({x, y}, points)`

Verifica si un punto está dentro de un polígono usando el algoritmo de ray-casting.
Lanza un rayo horizontal desde el punto hacia la derecha y cuenta cuántos bordes
del polígono cruza. Si el conteo es impar, el punto está adentro.

- `point` — tupla `{x, y}`
- `points` — lista de tuplas `{x, y}` de los vértices del polígono
- Retorna `false` para polígonos degenerados (< 3 vértices)

**Uso típico:** verificar si un punto candidato cae dentro de un obstáculo.

---

### `segment_intersects_polygon?(p1, p2, points)`

Verifica si un segmento de línea intersecta algún borde de un polígono.
Usa tests de signo de producto cruzado para determinar intersección.

- `p1`, `p2` — tuplas `{x, y}` de los extremos del segmento
- `points` — vértices del polígono
- Retorna `false` para polígonos degenerados (< 3 vértices)

**Uso típico:** verificar si el path de movimiento cruza un obstáculo.

## Helpers de Mapa

### `inside_structure?({x, y}, structures)`

Verifica si un punto cae dentro de cualquier estructura del mapa.

- `structures` — lista de `%{points: [{x, y}]}` del `MapParams`
- Retorna `false` para lista vacía de estructuras

**Uso típico:** validar que un target generado no esté dentro de un obstáculo.

---

### `path_collides?(from, to, structures)`

Verifica si moverse de un punto a otro colisionaría con alguna estructura.
Combina `point_in_polygon?` (destino dentro de obstáculo) y
`segment_intersects_polygon?` (path cruza obstáculo).

- `from`, `to` — tuplas `{x, y}`
- `structures` — lista de estructuras del mapa
- Retorna `false` para lista vacía de estructuras

**Uso típico:** decidir si un movimiento candidato es válido antes de ejecutarlo.

---

### `random_open_point(map, fallback, max_attempts \\ 50)`

Genera un punto random dentro de los bounds del mapa que no caiga dentro de
ningún obstáculo. Usa rejection sampling: genera candidatos y descarta los que
caen en obstáculos, hasta `max_attempts` intentos. Si se agotan, retorna `fallback`.

- `map` — `%MapParams{width, height, structures}`
- `fallback` — `%{x, y}` posición segura de respaldo
- Retorna `%{x, y}`

**Uso típico:** generar targets aleatorios para algoritmos de caminata dirigida.

---

### `step_toward(position, target, map, step_size)`

Calcula la posición candidata a un paso de distancia en dirección al target.
Normaliza el vector dirección, lo escala por `step_size`, y clampea el resultado
dentro del mapa.

- `position` — `%{x, y}` posición actual
- `target` — `%{x, y}` destino
- `map` — `%MapParams` para clampear
- `step_size` — píxeles de avance
- Retorna `%{x: integer(), y: integer()}` (coordenadas redondeadas)

**Uso típico:** avanzar un paso hacia un objetivo en cada tick.

## Helpers de Grilla

### `position_to_cell(position, cell_size)`

Convierte una posición `%{x, y}` a su celda de grid `{col, row}`.

```elixir
Geometry.position_to_cell(%{x: 45, y: 63}, 20)  #=> {2, 3}
```

---

### `cell_to_point({col, row}, cell_size, map)`

Genera un punto random dentro de una celda de grid, clampeado a los bounds del mapa.

```elixir
Geometry.cell_to_point({2, 3}, 20, map_params)  #=> %{x: 42, y: 67}  (ejemplo)
```

---

### `build_cell_grid(map, cell_size, default_value \\ 0)`

Crea un mapa de celdas `%{{col, row} => default_value}` cubriendo todo el mapa.
El número de columnas y filas se calcula como `div(dimension, cell_size) + 1`.

```elixir
Geometry.build_cell_grid(%MapParams{width: 100, height: 60}, 20, 0.0)
#=> %{{0,0} => 0.0, {0,1} => 0.0, ..., {5,3} => 0.0}
```

**Uso típico:** inicializar grids de feromonas (AntColony) o de calor (HeatmapWalk).

## Funciones privadas internas

- `polygon_edges/1` — genera pares de vértices consecutivos del polígono (incluyendo cierre)
- `ray_crosses_edge?/6` — test de cruce de rayo horizontal con un borde
- `segments_intersect?/4` — test de intersección de dos segmentos por producto cruzado
- `cross/3` — producto cruzado 2D de tres puntos
- `do_random_open_point/3` — implementación recursiva de rejection sampling
