# GreyWolf (GWO)

**Módulo:** `Simulator.Algorithms.GreyWolf`
**Archivo:** `lib/simulator/algorithms/impl/grey_wolf.ex`
**Registro:** `"grey_wolf"`

## Descripción

Grey Wolf Optimizer modificado para búsqueda ciega en espacio 2D continuo. La manada
opera sin conocimiento inicial del objetivo, con una jerarquía de roles fija asignada
por ID del dron.

## Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `@step_size` | 5 | Píxeles de avance por tick |
| `@arrival_threshold` | 3 | Distancia mínima para considerar llegada |
| `@min_leader_distance` | 150.0 | Distancia mínima de seguridad entre líderes |
| `@repulsion_strength` | 2.0 | Fuerza de repulsión entre líderes |
| `@omega_spread` | 60 | Radio de offset para targets de omega alrededor de un líder |
| `@a_initial` | 2.0 | Valor inicial del parámetro `a` de GWO |
| `@a_decay` | 0.005 | Decremento de `a` por tick durante convergencia |

## Comportamiento

### Asignación de roles

Los roles se asignan por ID del dron de forma determinista:

| ID | Rol |
|----|-----|
| 1 | Alpha |
| 2 | Beta |
| 3 | Delta |
| ≥4 | Omega |

### Fase de Caza Dispersa (`objective_found` es `nil`)

#### Líderes (Alpha, Beta, Delta)

Cada líder patrulla una zona asignada del mapa:

| Rol | Centro de zona | Bounds |
|-----|---------------|--------|
| Alpha | `(W/4, H/4)` | `[0, W/2] × [0, H/2]` (cuadrante superior izquierdo) |
| Beta | `(3W/4, H/4)` | `[W/2, W] × [0, H/2]` (cuadrante superior derecho) |
| Delta | `(W/2, 3H/4)` | `[0, W] × [H/2, H]` (mitad inferior completa) |

Los líderes generan targets random dentro de sus bounds y caminan hacia ellos.
Cuando llegan, generan un nuevo target en su zona.

**Repulsión entre líderes:** Si un líder está a menos de `@min_leader_distance` de otro
líder conocido, se aplica una fuerza de repulsión que desvía el target. La fuerza es
proporcional a `(@min_leader_distance - distancia) / @min_leader_distance`.

#### Omegas

Los omega rastrean al líder conocido más cercano y generan targets con un offset random
de ±`@omega_spread` píxeles alrededor de la posición del líder, proporcionando cobertura
local. Si no conocen ningún líder, usan `random_open_point`.

### Fase de Convergencia (`objective_found` es `%{x, y}`)

Todos los lobos usan las ecuaciones clásicas de GWO para encerrar el objetivo:

```
Para cada líder (alpha, beta, delta):
  A = 2·a·r1 - a
  C = 2·r2
  D = |C·líder_pos - pos|
  X_líder = líder_pos - A·D

Posición final = (X_alpha + X_beta + X_delta) / 3
```

El parámetro `a` decrece linealmente de `@a_initial` (2.0) a 0 con rate `@a_decay` (0.005)
por tick. Con `a` alto los lobos exploran ampliamente; con `a` bajo convergen estrechamente.

Si las posiciones de los líderes no están disponibles en `known_leaders`, se usa la
posición del objetivo como fallback.

### Comunicación
- **Broadcast:** Comparte `%{type: :gwo, role: atom, position: %{x,y}, objective: %{x,y} | nil}`
- **Recepción:**
  - Si el emisor es líder (alpha/beta/delta), actualiza su posición en `:known_leaders`
  - Si el mensaje incluye un objetivo y el receptor no tiene uno, lo almacena
  - Ignora mensajes de tipo distinto a `:gwo`

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
| `:role` | `:alpha \| :beta \| :delta \| :omega` | Rol asignado por ID |
| `:known_leaders` | `%{atom => %{x, y}}` | Posiciones conocidas de líderes |
| `:objective_found` | `%{x, y} \| nil` | Ubicación del objetivo |
| `:target` | `%{x, y}` | Target de movimiento actual |
| `:a_param` | `float` | Parámetro `a` de GWO (solo en convergencia) |

## format_state

Elimina `:known_leaders` y `:a_param` del estado expuesto.

## Dependencias

- `Geometry` — clamp, euclidean_distance, step_toward, path_collides?, random_open_point, inside_structure?
