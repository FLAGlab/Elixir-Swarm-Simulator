# Rutas y Controllers

## Principio General

La capa web es primariamente un **observador** de la simulación. Visualiza lo que ocurre
pero no controla el comportamiento de los drones. Su única capacidad de intervención es
enviar comandos de alto nivel (e.g., "apagar N drones") al Manager — nunca manipulación
directa de agentes.

Toda comunicación con Executors pasa por el SimulationManager. Los controllers y channels
nunca hablan con Executors directamente.

## HTTP Routes

```
GET    /                         PageController.home
GET    /simulations              SimulationController.index
POST   /simulations              SimulationController.create
GET    /simulations/new          SimulationController.new
GET    /simulations/:id          SimulationController.show
GET    /simulations/:id/edit     SimulationController.edit
PUT    /simulations/:id          SimulationController.update
DELETE /simulations/:id          SimulationController.delete
GET    /execution/:id            ExecutionController.show
GET    /execution_runs/:id      ExecutionRunController.show
```

## Controllers

### SimulationController

CRUD estándar para simulaciones. Las simulaciones son records persistidos en SQLite
que definen los parámetros de una ejecución (tipo, algoritmo, cantidad de agentes, mapa).

**Archivo:** `lib/simulator_web/controllers/simulation_controller.ex`

### ExecutionController

Renderiza la vista de ejecución en tiempo real. Al cargar `/execution/:id`:

1. Carga la simulación desde la DB
2. Resuelve los `MapParams` via `Maps.get_map(sim.map)`
3. Codifica las estructuras a JSON para el canvas
4. Renderiza HTML con el elemento canvas dimensionado según `MapParams`

**Archivo:** `lib/simulator_web/controllers/execution_controller.ex`

### ExecutionRunController

Renderiza la pantalla de estadísticas de una ejecución completada. Al cargar
`/execution_runs/:id`:

1. Carga el `ExecutionRun` desde la DB
2. Renderiza HTML con las estadísticas (algoritmo, mapa, objetivo, duración, ticks,
   dron finder, posición del objetivo, swarm size)
3. Incluye un botón "Run Again" que redirige a `/execution/:simulation_id`

**Archivo:** `lib/simulator_web/controllers/execution_run_controller.ex`

## Database Schema

**Tabla: `simulations`**

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | integer | Primary key (auto-increment) |
| `name` | string | Nombre/etiqueta de la simulación |
| `algorithm` | string | Key del algoritmo (e.g., `"random_walk"`) |
| `swarm` | integer | Cantidad de agentes |
| `map` | string | Key del mapa (default: `"clean"`) |
| `objective` | string | Key del objetivo (default: `"static"`) |
| `inserted_at` | utc_datetime | Timestamp |
| `updated_at` | utc_datetime | Timestamp |

**Tabla: `execution_runs`**

| Campo | Tipo | Notas |
|-------|------|-------|
| `id` | integer | Primary key (auto-increment) |
| `simulation_id` | integer | FK → simulations (on_delete: delete_all) |
| `algorithm` | string | Algoritmo usado en la ejecución |
| `map` | string | Mapa usado en la ejecución |
| `objective` | string | Tipo de objetivo |
| `swarm_size` | integer | Cantidad de agentes |
| `duration_ms` | integer | Duración en milisegundos |
| `ticks` | integer | Cantidad de ticks hasta detección |
| `finder_drone_id` | integer | ID del dron que encontró el objetivo |
| `objective_position` | string | Posición del objetivo como JSON string |
| `status` | string | `"completed"` o `"stopped"` |
| `inserted_at` | utc_datetime | Timestamp |
| `updated_at` | utc_datetime | Timestamp |

**Contexto Ecto:** `Simulator.Simulations` (`lib/simulator/simulations.ex`)
**Schemas:**
- `Simulator.Simulations.Simulation` (`lib/simulator/simulations/simulation.ex`)
- `Simulator.Simulations.ExecutionRun` (`lib/simulator/simulations/execution_run.ex`)
