# Elixir Swarm Simulator

An interactive web simulator for swarm behavior built with **Elixir** and the **Phoenix** framework. This project allows you to visualize and experiment with swarm intelligence algorithms in real time.

## Project Description

Elixir Swarm Simulator is a modern web application that simulates the collective behavior of autonomous agents (such as bee swarms, bird flocks, or fish schools). Users can:

- **Create custom simulations** with different parameters
- **Visualize in real time** the movement and behavior of agents
- **Experiment with algorithms** for artificial intelligence and emergent behavior

## Technologies Used

- **Elixir 1.15+**: Functional language with native concurrency support
- **Phoenix 1.8.1**: Modern and scalable web framework
- **Phoenix Channels / WebSockets**: Real-time position broadcasting
- **Ecto + SQLite3**: Data persistence
- **Tailwind CSS 4**: Responsive and modern design
- **Heroicons**: Icon library

## Prerequisites

Before getting started, make sure you have installed:

- **Elixir 1.15 or higher**
- **Erlang/OTP 26+** (included with Elixir)
- **Node.js 18+** (for compiling assets)
- **SQLite3** (included in most systems)
- **Git**

To verify your installation:

```bash
elixir --version
erl -version
node --version
```

## Installation and Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Elixir-Swarm-Simulator
```

### 2. Install Dependencies

Run the setup command that automatically configures the project:

```bash
mix setup
```

This command performs:
- Downloads and installs all dependencies with `mix deps.get`
- Sets up the database with `mix ecto.setup`
- Compiles the assets (CSS, JS) with `mix assets.build`

### 3. Start the Server

```bash
mix phx.server
```

Or if you prefer using IEx (Elixir interactive shell):

```bash
iex -S mix phx.server
```

Visit [`http://localhost:4000`](http://localhost:4000) once the server is started.

## Project Architecture

```
├── lib/
│   ├── simulator/                    # Core domain logic
│   │   ├── point_agent.ex            # Agent process (position + algorithm)
│   │   ├── simulation_executor.ex    # GenServer managing one execution
│   │   ├── simulation_manager.ex     # GenServer tracking all executions
│   │   ├── simulations.ex            # Ecto CRUD context
│   │   ├── simulations/
│   │   │   └── simulation.ex         # Simulation schema (type, algorithm, swarm, map)
│   │   ├── geometry.ex               # Geometric utilities (collision, distance, etc.)
│   │   ├── algorithms/
│   │   │   ├── algorithm.ex          # Algorithm behaviour
│   │   │   ├── algorithms.ex         # Algorithm registry
│   │   │   ├── knowledge_store.ex    # Shared knowledge utilities (decay, merge, anti-echo)
│   │   │   └── impl/                 # Algorithm implementations
│   │   │       ├── random_walk.ex    # Random walk with collision avoidance
│   │   │       ├── static.ex         # No movement
│   │   │       ├── aim_random_walk.ex # Target-directed walk
│   │   │       └── heatmap_walk.ex   # Heat-grid exploration with shared knowledge
│   │   ├── environment/              # Physical world simulation
│   │   │   ├── position_tracker.ex   # Stores agent positions
│   │   │   ├── proximity_detector.ex # Detects neighbor proximity
│   │   │   └── communication_relay.ex # Routes data between neighbors
│   │   └── maps/
│   │       ├── map.ex                # Map behaviour
│   │       ├── maps.ex               # Map registry
│   │       ├── map_params.ex         # MapParams struct (width, height, structures, spawn_point)
│   │       └── impl/                 # Map implementations
│   │           ├── clean_map.ex      # 500×500 empty map
│   │           ├── clean_city.ex     # 500×500 city map with 8 blocks
│   │           ├── big_clean_map.ex  # 1000×500 empty map
│   │           └── square_obstacle_map.ex # 1000×500 map with centered obstacle
│   └── simulator_web/               # Web layer
│       ├── router.ex                 # HTTP routes
│       ├── channels/
│       │   ├── user_socket.ex        # WebSocket endpoint
│       │   └── simulation_channel.ex # Real-time position broadcasting
│       ├── controllers/
│       │   ├── simulation_controller.ex  # CRUD at /simulations
│       │   └── execution_controller.ex   # Execution view at /execution/:id
│       └── components/               # Reusable UI components
├── assets/
│   ├── css/                          # Tailwind CSS styles
│   └── js/                           # JavaScript (Canvas, WebSocket client)
├── priv/
│   └── repo/                         # Database migrations
├── test/                             # Test suite
├── config/                           # Project configuration
└── mix.exs                           # Dependencies and project config
```

## How a Simulation Works

The simulation system is built on Erlang/OTP processes communicating through GenServers and Phoenix Channels. Below is the complete data flow:

### 1. Simulation Configuration (CRUD)

The user creates a simulation record through the web interface at `/simulations`. Each simulation has:

| Field       | Description                                     |
|-------------|------------------------------------------------|
| `type`      | A name/label for the simulation                |
| `algorithm` | Movement algorithm key (e.g. `"random_walk"`)  |
| `swarm`     | Number of agents to spawn                       |
| `map`       | Map key (e.g. `"clean"`, `"city"`, `"big_clean"`) |

These records are persisted in SQLite via Ecto.

### 2. Execution Startup

When the user navigates to `/execution/:id`:

```
Browser                    Server
  │                          │
  ├─ GET /execution/:id ────►│  ExecutionController loads simulation + map params
  │◄──── HTML page ──────────│  (renders canvas with correct dimensions)
  │                          │
  ├─ WebSocket connect ─────►│  UserSocket accepts connection
  ├─ join "simulation:<id>" ►│  SimulationChannel.join/3
  │                          │
```

### 3. Process Architecture

On channel join, the following OTP process tree is created:

```
SimulationManager (singleton GenServer)
  │
  ├── tracks: %{simulation_id => executor_pid}
  │
  └── SimulationExecutor (GenServer, one per simulation)
        │
        ├── PositionTracker    (stores positions broadcast by agents)
        ├── ProximityDetector  (detects neighbor proximity)
        ├── CommunicationRelay (routes data between neighbors)
        ├── PointAgent 1 (GenServer + tick loop)
        ├── PointAgent 2 (GenServer + tick loop)
        ├── ...
        └── PointAgent N (GenServer + tick loop)
```

- **SimulationManager** — Prevents duplicate executions per simulation ID. Delegates `start_execution` and `get_positions` calls to the appropriate executor.
- **SimulationExecutor** — Spawns N `PointAgent` processes on init. Registered under `simulation.type` as its process name.
- **PointAgent** — Each agent is a GenServer holding `%{id, position, algorithm, map, neighbors, tracker, relay}`. Every `@update_interval` ms it calls `algorithm.compute_step(state)` to compute the next position and updated state, then broadcasts position and shared data.

### 4. Real-Time Position Loop

After the execution starts, `SimulationChannel` enters a tick loop:

```
SimulationChannel                SimulationManager           SimulationExecutor        PointAgents
       │                                │                          │                      │
       ├── :tick (every @tick_interval) │                          │                      │
       ├── {:get_positions, sim} ──────►│                          │                      │
       │                                ├── get_positions(pid) ───►│                      │
       │                                │                          ├── get_position(pid) ─►│
       │                                │                          │◄── %{x, y} ──────────│
       │                                │◄── %{positions: [...]} ──│                      │
       │◄── %{positions: [...]} ────────│                          │                      │
       │                                                                                   │
       ├── push("positions", data) ──► Browser (Canvas renders agents)                    │
       │                                                                                   │
       │   Meanwhile, each PointAgent ticks independently:                                │
       │                                                           ┌── :tick ─────────────│
       │                                                           │  algorithm            │
       │                                                           │  .compute_step()      │
       │                                                           │  updates position     │
       │                                                           └──────────────────────►│
```

### 5. Algorithm System

Algorithms implement the `Simulator.Algorithm` behaviour:

```elixir
@callback compute_step(map()) :: {map(), map()}
```

The callback receives the full agent state (`%{position: %{x, y}, map: %MapParams{}}`) and must return `{new_position, updated_state}`. Available algorithms are registered in `Simulator.Algorithms` (`@available_algorithms` map). Unknown names fall back to `RandomWalk`.

### 6. Map System

Maps implement the `Simulator.Map` behaviour:

```elixir
@callback get_parameters(map()) :: MapParams.t()
```

Each map returns a `%MapParams{width, height, structures}` struct that defines spatial bounds. Algorithms use these bounds to constrain agent movement (e.g. `RandomWalk` clamps positions to `0..map.width` and `0..map.height`).

## Testing

Run all tests:

```bash
mix test
```

Run tests for a specific file:

```bash
mix test test/simulator/point_agent_test.exs
```

Run only previously failed tests:

```bash
mix test --failed
```

## Useful Commands

| Command | Description |
|---------|-------------|
| `mix setup` | Initial installation and setup |
| `mix phx.server` | Start the development server |
| `mix test` | Run the test suite |
| `mix format` | Automatically format code |
| `mix precommit` | Run linters and tests (use before committing) |
| `mix ecto.setup` | Set up the database |
| `mix ecto.reset` | Reset the database |

## Configuration

Configuration files are located in `config/`:

- **config.exs**: Global configuration
- **dev.exs**: Development configuration
- **prod.exs**: Production configuration
- **test.exs**: Test configuration
- **runtime.exs**: Runtime configuration

## Adding New Algorithms

See [ALGORITHMS.md](ALGORITHMS.md) for a guide on implementing new movement algorithms.

## Project Guidelines

See [docs/ProgramingGuide.md](docs/ProgramingGuide.md) for development guidelines, code conventions, and architecture standards.

## Contributing

Contributions are welcome. Please:

1. Fork the project
2. Create a branch for your feature (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed. See the [LICENSE](LICENSE) file for details.

## Author

Project developed as part of research in swarm intelligence and multi-agent simulation.

---

**Issues or Questions?**

If you find any issues or have questions, please open an issue in the repository.
