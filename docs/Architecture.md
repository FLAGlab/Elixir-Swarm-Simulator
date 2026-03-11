# Architecture

## Overview

Multi-agent swarm simulator built with Phoenix 1.8 / Elixir 1.15 / SQLite. Agents are independent OTP processes with pluggable movement algorithms, visualized in real-time via Phoenix Channels + Canvas.

## Supervision Tree

```
Simulator.Supervisor (one_for_one)
  |-- Simulator.Repo                          # Ecto / SQLite
  |-- Ecto.Migrator                           # Auto-run migrations
  |-- DNSCluster                              # DNS clustering
  |-- Phoenix.PubSub (Simulator.PubSub)       # PubSub broker
  |-- SimulatorWeb.Endpoint                   # Phoenix HTTP + WebSocket
  |-- Simulator.SimulationManager             # Singleton: tracks all executions
  |-- Registry (Simulator.Registry)           # Process registry
```

## Core Domain (`lib/simulator/`)

### PointAgent (`point_agent.ex`)

Models an **autonomous drone** as a GenServer process. Each PointAgent represents a single swarm member that operates with **local information only** — it knows its own position, its map (pre-loaded, like an offline GPS), its detected neighbors, and data received from other drones. It must never access external state directly, just as a real drone would be limited to its own sensors and communications.

- **State**: `%{id: integer, position: %{x, y}, algorithm: module, map: %MapParams{}, neighbors: %{}, tracker: pid, relay: pid}`
- **Initial position**: Defined by the map's `spawn_point` (e.g., `%{x: 250, y: 250}` for CleanMap)
- **Tick loop**: Every 30ms via `handle_info(:tick)`, the drone:
  1. Calls the algorithm to decide its next movement
  2. Broadcasts its new position to the PositionTracker
  3. Broadcasts shared data (defined by the algorithm) to the CommunicationRelay
- **Incoming messages** (via `handle_cast`):
  - `{:drone_entered, pid, pos}` — environment detected a new neighbor
  - `{:drone_left, pid}` — a neighbor left detection range
  - `{:received_data, sender, data}` — shared data from a neighboring drone

**Autonomy principle**: The drone can only act on information it could realistically have — its position, the static map, neighbors detected by the environment, and data shared by those neighbors. It cannot query other drones' positions or know objective locations unless explicitly communicated to it.

### Algorithm System (`lib/simulator/algorithms/`)

Algorithms are the **brain of the drone**. They are pluggable components that give the PointAgent its decision-making capability. A drone is only as intelligent as its algorithm.

- **Information constraint**: An algorithm receives only the agent's local state (`%{position, map, neighbors, ...}`). It must never reach outside this state for information
- **Three responsibilities** defined by the `Simulator.Algorithm` behaviour:
  1. **Movement**: `compute_step(state)` — computes the drone's next position and updated state (required)
  2. **Broadcasting**: `get_shared_data(state)` — decides what data to share with neighbors (optional, defaults to `%{}`)
  3. **Receiving**: `handle_received_data(sender, data, state)` — processes data received from a neighbor (optional, defaults to no-op)
  4. **Formatting**: `format_state(algo_state)` — prepares algorithm state for external consumption, e.g. merging internal structures before exposing to the detail panel (optional, defaults to identity)
- **Registry** (`algorithms.ex`): maps string names to modules, also accepts module atoms directly. Defaults to `RandomWalk`
- **Implementations** in `impl/`: `RandomWalk`, `Static`, `AimRandomWalk`, `HeatmapWalk`

**KnowledgeStore** (`knowledge_store.ex`): Utility module for algorithms that share positional knowledge between drones. Provides functions for decaying received data (one position per tick), merging incoming knowledge with anti-echo (filters own PID), combining own and received positions, and formatting for export. Used by `HeatmapWalk` and available for any future cooperative algorithm.

See [ALGORITHMS.md](./ALGORITHMS.md) for details on implementing new algorithms.

### SimulationExecutor (`simulation_executor.ex`)

The Executor is the **environment simulator**, not a drone controller. Since this is a swarm simulation, all decisions must happen inside each drone (PointAgent) — the Executor's job is to simulate the physical world around them.

On initialization, the Executor starts three **environment modules** and then spawns the agents:

```
SimulationExecutor
  |-- PositionTracker      (stores positions broadcast by agents)
  |-- ProximityDetector    (detects when drones enter/leave each other's range)
  |-- CommunicationRelay   (delivers shared data between neighboring drones)
  |-- PointAgent x N       (autonomous drone processes)
```

**Responsibilities:**
- **Spawn agents**: Creates N `PointAgent` processes (N = `simulation.swarm`), stored as `%{id => pid}`
- **Query agent detail**: `get_agent_detail/2` retrieves a specific agent's detailed state by ID
- **Orchestrate environment modules**: Starts and wires PositionTracker, ProximityDetector, and CommunicationRelay
- **Aggregate positions**: `get_positions/1` reads from the PositionTracker (agents broadcast their position, the Executor no longer polls them)
- **Simulate peripherals**: Can send collision warnings, proximity alerts, or sensor data to drones — simulating what their hardware would detect in the real world
- **Manage objectives**: The Executor knows the location of search targets (fixed and mobile points). Drones do NOT know objective locations — the Executor notifies a drone only when it "detects" something (based on proximity/sensors)
- **Handle drone shutdown**: Can terminate specific agents to simulate drone failures. The frontend sends a count (not specific IDs) and the Executor decides which drones to shut down, allowing the swarm to adapt

Registered by `simulation.type` name (one per simulation type).

### Environment Modules (`lib/simulator/environment/`)

These GenServers simulate aspects of the physical world. They are started and managed by the Executor.

**PositionTracker** (`position_tracker.ex`): Receives position broadcasts from agents and stores them. Serves position data to the visualization layer and to other environment modules. Agents report their position on every tick via `report_position/3`.

**ProximityDetector** (`proximity_detector.ex`): Every 30ms, reads all positions from the PositionTracker, calculates distances between all agent pairs, and detects when drones enter or leave each other's detection radius. Sends `notify_drone_entered/3` and `notify_drone_left/2` casts to affected agents. Configurable `detection_radius` (default: 50px).

**CommunicationRelay** (`communication_relay.ex`): Receives data broadcasts from agents and delivers them only to valid neighbors (drones within detection range). When a drone calls `broadcast/3`, the relay queries `ProximityDetector.get_neighbors/2` to determine the sender's neighbors and sends `receive_shared_data/3` to each one. This simulates the physical limitation that drones can only communicate via radio with nearby drones, not with the entire swarm.

Registered by `simulation.type` name (one per simulation type).

### SimulationManager (`simulation_manager.ex`)

The Manager is an **application-level component**, not part of the simulation itself. It acts as a centralized bridge between the outside world (web controllers, channels) and the Executors. **No external component should communicate directly with an Executor** — all interaction must go through the Manager.

**Responsibilities:**
- Maintains map: `simulation.id => executor_pid`
- Prevents duplicate executions (returns `:already_running`)
- Stops executions via `stop_execution/1`, terminating all child processes and freeing resources
- Delegates position queries, agent detail queries, and commands to the appropriate Executor
- Monitors executor processes and cleans up on unexpected termination
- Serves as the sole communication bridge between controllers/channels and Executors

### Map System (`lib/simulator/maps/`)

Maps define the **static environment** for a simulation. They represent pre-known terrain that drones have loaded before flight (like an offline GPS map). Maps are static for the duration of a simulation — obstacles don't move.

**What drones know vs. don't know:**
- **Known**: Map dimensions and obstacle locations (structures). The drone's fundamental task is searching for fixed and mobile points within this known terrain
- **Unknown**: Objective locations. The Executor holds this information and notifies drones when they detect something through simulated sensors

**Implementation:**
- **Behaviour** (`map.ex`): `@callback get_parameters(map()) :: MapParams.t()`
- **MapParams struct** (`map_params.ex`): `%{width, height, structures, spawn_point}`
- **Registry** (`maps.ex`): maps string names to modules, defaults to `CleanMap`
- **Implementations** in `impl/`: `CleanMap`, `BigCleanMap`, `CityMap`, `SquareObstacleMap`

See [MAPS.md](./MAPS.md) for details on implementing new maps.

## Database Schema

**Table: `simulations`**

| Field | Type | Notes |
|-------|------|-------|
| `id` | integer | Primary key (auto-increment) |
| `type` | string | Simulation name/label |
| `algorithm` | string | Algorithm key (e.g., `"random_walk"`) |
| `swarm` | integer | Number of agents |
| `map` | string | Map key (default: `"clean"`) |
| `inserted_at` | utc_datetime | Timestamp |
| `updated_at` | utc_datetime | Timestamp |

## Web Layer (`lib/simulator_web/`)

The web layer is primarily an **observer** of the simulation. It visualizes what happens but does not control drone behavior. Its only intervention capability is sending high-level commands (e.g., "shut down N drones") to the Manager — never direct manipulation of agents.

All communication with Executors goes through the SimulationManager. Controllers and channels never talk to Executors directly.

### HTTP Routes

```
GET    /                    PageController.home
GET    /simulations         SimulationController.index
POST   /simulations         SimulationController.create
GET    /simulations/new     SimulationController.new
GET    /simulations/:id     SimulationController.show
GET    /simulations/:id/edit SimulationController.edit
PUT    /simulations/:id     SimulationController.update
DELETE /simulations/:id     SimulationController.delete
GET    /execution/:id       ExecutionController.show
```

### WebSocket

- Endpoint: `/socket` (UserSocket)
- Channel: `"simulation:<id>"` → `SimulationChannel`
- Incoming events: `"select_drone"` (with `%{"id" => id}`), `"deselect_drone"`
- Outgoing events: `"positions"` (all agents), `"drone_detail"` (selected agent's detailed state)

## Real-Time Execution Data Flow

### Step 1: User creates simulation (CRUD)
```
Browser --> POST /simulations --> SimulationController --> Repo.insert --> Redirect
```

### Step 2: User launches execution
```
Browser --> GET /execution/:id --> ExecutionController.show
  |-- Load Simulation from DB
  |-- Resolve MapParams via Maps.get_map(sim.map)
  |-- Encode structures to JSON
  |-- Render HTML with canvas element (width/height from MapParams)
```

### Step 3: Frontend connects via WebSocket
```
Browser (JS) --> WebSocket /socket --> SimulationChannel.join("simulation:<id>")
  |-- Load simulation from DB
  |-- SimulationManager.start_execution
  |   |-- Check if already running
  |   |-- Create SimulationExecutor if new
  |   |   |-- Start PositionTracker, ProximityDetector, CommunicationRelay
  |   |   |-- Spawn PointAgent x swarm (each linked to tracker + relay)
  |-- Schedule first :tick
  |-- Return :ok
```

### Step 4: Real-time position loop (every 30ms)
```
SimulationChannel.handle_info(:tick)
  |-- GenServer.call(SimulationManager, {:get_positions, ...})
  |   |-- SimulationExecutor reads from PositionTracker
  |   |-- Return %{positions: [%{x, y, color, id}, ...]}
  |-- push(socket, "positions", %{positions: positions})
  |-- push_selected_drone_detail (if a drone is selected)
  |-- schedule_tick()
```

### Step 5: Canvas renders (Browser)
```
JS receives "positions" event
  |-- Clear canvas
  |-- Draw structures (gray polygons)
  |-- Draw agents (concentric circles per agent)
  |-- Colors from CSS variables (--color-primary, --color-secondary)
```

### Step 6: Agent tick cycle (every 30ms, independent per agent)
```
PointAgent.handle_info(:tick)
  |-- algorithm.compute_step(state) --> {new_position, updated_state}
  |-- PositionTracker.report_position(tracker, self(), position)
  |-- algorithm.get_shared_data(state) --> data to broadcast
  |-- CommunicationRelay.broadcast(relay, self(), data) (if data != %{})
  |-- Schedule next tick
```

### Step 7: Environment modules (continuous, parallel)
```
ProximityDetector (every 30ms):
  |-- Read all positions from PositionTracker
  |-- Calculate distances between all pairs
  |-- Diff with previous neighbors state
  |-- Notify agents: drone_entered / drone_left

CommunicationRelay (on each broadcast):
  |-- Receive {:broadcast, sender, data}
  |-- Look up sender's neighbors from ProximityDetector
  |-- Deliver data to each valid neighbor via receive_shared_data
```

## Frontend (`assets/js/`)

- **`app.js`**: Entry point, imports Phoenix Socket, LiveView, topbar, and simulation canvas
- **`simulation_canvas.js`**: Connects to `SimulationChannel` via WebSocket, renders agents and structures on HTML Canvas using 2D context

### Canvas rendering details
- Structures: gray filled polygons (0.3 opacity fill, 0.8 opacity stroke)
- Heatmap overlay: when a heatmap_walk drone is selected, visited cells are drawn as semi-transparent red rectangles with opacity proportional to visit density
- Agents: outer circle (radius 20, stroke) + inner circle (radius 5, filled)
- Agent colors: violet (`#6366f1`) when alone, green (`#22c55e`) when has neighbors, amber (`#f59e0b`) when selected

### Drone grid and detail panel
- Below the canvas, a 4-column grid displays drone IDs with color-coded dots
- Clicking a drone toggles selection (sends `select_drone`/`deselect_drone` to the channel)
- When selected, a detail panel shows the drone's position, neighbor count, and algorithm-specific state
- The selected drone concept lives only in the web layer — the backend exposes a generic `get_agent_detail` query

## Key Design Decisions

1. **Drone autonomy**: Each PointAgent operates with local information only, mirroring real drone constraints. No agent can access global state — only its position, its map, and messages received from the environment
2. **Algorithms as the drone's brain**: Movement intelligence is fully encapsulated in the algorithm. The drone is as smart as its algorithm, and algorithms only use locally available information
3. **Executor as environment, not controller**: The Executor simulates the physical world (communications, sensors, collisions, objectives) — it never makes decisions for the drones
4. **Manager as application bridge**: All external communication (web, channels) goes through the Manager. No component outside the simulation talks to Executors directly
5. **Frontend as observer**: The web layer visualizes the simulation and can only send high-level commands (e.g., shut down N drones). It cannot manipulate individual agents
6. **Static maps, unknown objectives**: Drones know the terrain (map + obstacles) but not objective locations. The Executor reveals objectives through simulated sensor detection
7. **Algorithm-defined communication**: Algorithms decide what data to share (`get_shared_data`) and how to process received data (`handle_received_data`). The environment only handles routing — it never inspects or modifies the content
8. **Environment as separate modules**: Physical world simulation is split into specialized GenServers (PositionTracker, ProximityDetector, CommunicationRelay), each handling one aspect, orchestrated by the Executor
9. **GenServer per swarm member**: Each agent is an independent GenServer with its own tick loop, enabling true concurrency via the BEAM VM
10. **Pluggable behaviours**: Algorithms and maps are interchangeable via behaviour contracts + string-keyed registries
11. **Channels over LiveView for execution**: The real-time visualization uses Phoenix Channels + vanilla JS Canvas for fine-grained rendering control at 30fps
12. **Ephemeral execution**: Simulations are persisted in the DB, but executions are in-memory OTP processes — no execution state is saved
