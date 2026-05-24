# Routes and Controllers

## General Principle

The web layer is primarily an **observer** of the simulation. It visualizes what
happens but does not control the drones' behavior. Its only intervention capability
is sending high-level commands (e.g., "shut down N drones") to the Manager — never
direct manipulation of agents.

All communication with Executors goes through the SimulationManager. Controllers
and channels never talk to Executors directly.

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

Standard CRUD for simulations. Simulations are records persisted in SQLite that
define the parameters of an execution (type, algorithm, agent count, map).

**File:** `lib/simulator_web/controllers/simulation_controller.ex`

### ExecutionController

Renders the real-time execution view. When loading `/execution/:id`:

1. Loads the simulation from the DB
2. Resolves the `MapParams` via `Maps.get_map(sim.map)`
3. Encodes the structures to JSON for the canvas
4. Renders HTML with the canvas element sized according to `MapParams`

**File:** `lib/simulator_web/controllers/execution_controller.ex`

### ExecutionRunController

Renders the stats screen of a completed execution. When loading
`/execution_runs/:id`:

1. Loads the `ExecutionRun` from the DB
2. Renders HTML with the stats (algorithm, map, objective, duration, ticks,
   finder drone, objective position, swarm size)
3. Includes a "Run Again" button that redirects to `/execution/:simulation_id`

**File:** `lib/simulator_web/controllers/execution_run_controller.ex`

## Database Schema

**Table: `simulations`**

| Field | Type | Notes |
|-------|------|-------|
| `id` | integer | Primary key (auto-increment) |
| `name` | string | Simulation name/label |
| `algorithm` | string | Algorithm key (e.g., `"random_walk"`) |
| `swarm` | integer | Number of agents |
| `map` | string | Map key (default: `"clean"`) |
| `objective` | string | Objective key (default: `"static"`) |
| `inserted_at` | utc_datetime | Timestamp |
| `updated_at` | utc_datetime | Timestamp |

**Table: `execution_runs`**

| Field | Type | Notes |
|-------|------|-------|
| `id` | integer | Primary key (auto-increment) |
| `simulation_id` | integer | FK → simulations (on_delete: delete_all) |
| `algorithm` | string | Algorithm used in the execution |
| `map` | string | Map used in the execution |
| `objective` | string | Objective type |
| `swarm_size` | integer | Number of agents |
| `duration_ms` | integer | Duration in milliseconds |
| `ticks` | integer | Number of ticks until detection |
| `finder_drone_id` | integer | ID of the drone that found the objective |
| `objective_position` | string | Objective position as a JSON string |
| `status` | string | `"completed"` or `"stopped"` |
| `inserted_at` | utc_datetime | Timestamp |
| `updated_at` | utc_datetime | Timestamp |

**Ecto context:** `Simulator.Simulations` (`lib/simulator/simulations.ex`)
**Schemas:**
- `Simulator.Simulations.Simulation` (`lib/simulator/simulations/simulation.ex`)
- `Simulator.Simulations.ExecutionRun` (`lib/simulator/simulations/execution_run.ex`)
