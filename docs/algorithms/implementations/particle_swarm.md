# ParticleSwarm (PSO)

**Módulo:** `Simulator.Algorithms.ParticleSwarm`
**Archivo:** `lib/simulator/algorithms/impl/particle_swarm.ex`
**Registro:** `"particle_swarm"`

## Descripción

Particle Swarm Optimization para búsqueda ciega en espacio 2D continuo. Diseñado para
encontrar un objetivo estático que no emite señal de proximidad — las partículas deben
alcanzar físicamente el objetivo para detectarlo.

Opera en dos modos implícitos determinados por si se ha encontrado el objetivo o no.

## Constantes

| Constante | Valor | Descripción |
|-----------|-------|-------------|
| `@max_speed` | 8.0 | Velocidad máxima en píxeles por tick |
| `@inertia` | 0.6 | Factor de inercia (peso de la velocidad anterior) |
| `@cognitive_weight` | 1.5 | Peso de atracción hacia personal best |
| `@social_weight` | 1.5 | Peso de atracción hacia global best (objetivo) |
| `@repulsion_radius` | 80.0 | Radio de repulsión entre partículas (exploración) |
| `@repulsion_strength` | 3.0 | Fuerza de repulsión entre partículas |
| `@wander_strength` | 4.0 | Magnitud del componente aleatorio en exploración |

## Comportamiento

### Modo Exploración (`objective_found` es `nil`)

Las partículas se dispersan para maximizar cobertura del espacio:

**Velocidad = inercia + wander + repulsión**

1. **Inercia:** `velocidad_anterior × @inertia`
2. **Wander:** Vector aleatorio con magnitud `@wander_strength`
3. **Repulsión:** Fuerza inversamente proporcional a la distancia de cada vecino
   dentro de `@repulsion_radius`. Empuja a las partículas lejos unas de otras.

**Personal best:** Se actualiza cuando la posición actual está más lejos de los vecinos
que el personal best actual — incentiva explorar zonas menos cubiertas.

### Modo Convergencia (`objective_found` es `%{x, y}`)

Ecuaciones clásicas de PSO:

**Velocidad = inercia + cognitivo + social**

1. **Inercia:** `velocidad_anterior × @inertia`
2. **Cognitivo:** `@cognitive_weight × r1 × dirección(posición → personal_best)`
3. **Social:** `@social_weight × r2 × dirección(posición → objetivo)`

Donde `r1` y `r2` son valores random uniformes en `[0, 1)`.

### Manejo de colisiones

Si el path al candidato colisiona con un obstáculo, la velocidad se invierte y reduce
a la mitad (`bounce`): `velocity = -velocity × 0.5`. La posición no cambia.

### Velocidad máxima

La velocidad se clampea a `@max_speed` normalizando el vector si la magnitud excede el límite.

### Comunicación
- **Broadcast:** Si encontró el objetivo, comparte `%{type: :pso, objective: %{x, y}}`.
  Si no, comparte `%{}` (nada).
- **Recepción:** Si recibe un objetivo y aún no tiene uno, lo almacena en `:objective_found`.
  Ignora si ya tiene uno (primera detección gana).
- **Propagación:** La información del objetivo se propaga transitivamente a medida que
  los drones se encuentran.

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
| `:velocity` | `%{vx, vy}` | Velocidad actual de la partícula |
| `:personal_best` | `%{x, y}` | Mejor posición encontrada (más alejada de vecinos) |
| `:objective_found` | `%{x, y} \| nil` | Ubicación del objetivo, `nil` en exploración |

## format_state

Elimina `:velocity` y `:personal_best` del estado expuesto.

## Dependencias

- `Geometry` — clamp, euclidean_distance, path_collides?
