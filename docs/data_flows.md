# Data Flows: Real-Time Execution

This document describes the full data flow from when the user creates a simulation
until they see the agents moving on the canvas.

## General Diagram

```mermaid
flowchart TD
    subgraph Browser
        UI["UI (Forms)"]
        Canvas["Canvas (JS)"]
        Stats["Stats Page"]
    end

    subgraph Web["Web Layer"]
        SC["SimulationController"]
        EC["ExecutionController"]
        ERC["ExecutionRunController"]
        Ch["SimulationChannel"]
    end

    subgraph App["Application Layer"]
        Mg["SimulationManager"]
        PS["PubSub"]
    end

    subgraph Sim["Simulation Layer"]
        Ex["SimulationExecutor"]
        PT["PositionTracker"]
        PD["ProximityDetector"]
        CR["CommunicationRelay"]
        OS["ObjectiveServer\n(optional)"]
    end

    subgraph Agents["Agent Layer"]
        A["PointAgent × N"]
    end

    DB[("SQLite")]

    UI -- "POST /simulations" --> SC
    SC --> DB
    UI -- "GET /execution/:id" --> EC
    EC --> DB
    Stats -- "GET /execution_runs/:id" --> ERC
    ERC --> DB
    Canvas <-- "WebSocket" --> Ch
    Ch --> Mg
    Mg --> Ex
    Ex --> PT & PD & CR & OS
    PT --> PD
    PD --> CR
    OS -- "reads positions" --> PT
    OS -- "objective_found" --> Ex
    Ex -- "execution_complete" --> Mg
    Mg -- "save ExecutionRun" --> DB
    Mg -- "broadcast" --> PS
    PS -- "simulation_complete" --> Ch
    A -- "report_position" --> PT
    A -- "broadcast" --> CR
    CR -- "receive_shared_data" --> A
    PD -- "entered / left" --> A
```

## Step 1: Simulation creation (CRUD)

```mermaid
sequenceDiagram
    participant B as Browser
    participant SC as SimulationController
    participant DB as Repo (SQLite)

    B->>SC: POST /simulations
    SC->>DB: Repo.insert(changeset)
    DB-->>SC: {:ok, simulation}
    SC-->>B: Redirect to /simulations/:id
```

The user creates a simulation record with a name, algorithm, agent count, map, and objective.

## Step 2: Execution launch

```mermaid
sequenceDiagram
    participant B as Browser
    participant EC as ExecutionController
    participant DB as Repo
    participant Maps as Maps Registry

    B->>EC: GET /execution/:id
    EC->>DB: Repo.get(Simulation, id)
    DB-->>EC: simulation
    EC->>Maps: get_map(sim.map).get_parameters()
    Maps-->>EC: %MapParams{width, height, structures}
    EC-->>B: HTML + Canvas (sized according to MapParams)
```

## Step 3: WebSocket connection

```mermaid
sequenceDiagram
    participant JS as Browser (JS)
    participant Ch as SimulationChannel
    participant Mg as SimulationManager
    participant Ex as SimulationExecutor
    participant PT as PositionTracker
    participant PD as ProximityDetector
    participant CR as CommunicationRelay
    participant OS as ObjectiveServer
    participant Agents as PointAgent × N

    JS->>Ch: join("simulation:id")
    Ch->>Ch: PubSub.subscribe("simulation:id")
    Ch->>Mg: start_execution(simulation)

    Mg->>Ex: start_link(simulation)
    activate Ex
    Ex->>PT: start_link()
    Ex->>PD: start_link(tracker)
    Ex->>CR: start_link(proximity)
    opt Objective != "none"
        Ex->>OS: ObjectiveServer.start_link(objective_module, map, tracker, self)
    end
    Ex->>Agents: start_link × N (algorithm, map, tracker, relay)
    deactivate Ex

    Mg-->>Ch: {:ok, pid}
    Ch->>Ch: schedule_tick()
    Ch-->>JS: :ok
```

## Step 4: Real-time position loop (every ~30ms)

```mermaid
sequenceDiagram
    participant JS as Browser
    participant Ch as Channel
    participant Mg as Manager
    participant Ex as Executor
    participant PT as PositionTracker

    loop Every ~30ms
        Ch->>Ch: handle_info(:tick)
        Ch->>Mg: get_positions(simulation)
        Mg->>Ex: get_positions()
        Ex->>PT: get_positions()
        PT-->>Ex: %{positions: [%{x, y, color, id}...]}
        opt There is an ObjectiveServer
            Ex->>Ex: Adds objective position to the response
        end
        Ex-->>Mg: %{positions: [...], objective: %{x, y}}
        Mg-->>Ch: positions
        Ch->>JS: push("positions", data)
        opt Drone selected
            Ch->>Mg: get_agent_detail(sim, id)
            Mg-->>Ch: detail
            Ch->>JS: push("drone_detail", detail)
        end
        Ch->>Ch: schedule_tick()
    end
```

## Step 4.5: Drone connection toggle (on-demand)

```mermaid
sequenceDiagram
    participant JS as Browser (JS)
    participant Ch as Channel
    participant Mg as Manager
    participant Ex as Executor
    participant PT as PositionTracker
    participant CR as CommunicationRelay

    JS->>Ch: "toggle_drone_connection" %{id: 3, connected: false}
    Ch->>Mg: toggle_drone_connection(simulation, 3, false)
    Mg->>Ex: toggle_drone_connection(3, false)

    par Environment block
        Ex->>PT: block_agent(agent_pid)
        Note over PT: Ignores the drone's report_position<br/>Marks position with disconnected: true
    and
        Ex->>CR: block_agent(agent_pid)
        Note over CR: Ignores the drone's broadcasts<br/>Does not deliver messages to the drone
    end

    Ex-->>Mg: :ok
    Mg-->>Ch: :ok

    Note over JS: ProximityDetector filters out the drone<br/>→ triggers drone_left for its neighbors
    Note over JS: Next tick shows a gray drone with opacity 0.4
```

The drone **keeps running** its tick loop — it calls `compute_step`, attempts
`report_position` and `broadcast`, but the environment ignores them. On reconnection
(`connected: true`), the environment resumes tracking and the drone retains its
dirty state (stale neighbors, old data).

## Step 5: Canvas rendering (Browser)

```mermaid
flowchart TD
    Event["Receives 'positions' event"] --> Clear["Clear canvas"]
    Clear --> Structures["Draw structures\n(gray polygons)"]
    Structures --> Overlay{"Selected drone\nwith overlay?"}
    Overlay -- "Yes" --> DrawOverlay["Draw overlay\n(heatmap / pheromones)"]
    Overlay -- "No" --> DrawObj
    DrawOverlay --> DrawObj{"Is there an objective?"}
    DrawObj -- "Yes" --> Objective["Draw objective\n(red circle)"]
    DrawObj -- "No" --> DrawAgents
    Objective --> DrawAgents["Draw agents\n(concentric circles)"]
    DrawAgents --> Colors["Color them:\nviolet = alone\ngreen = with neighbors\namber = selected"]
    Colors --> Grid["Update drone grid\nand detail panel"]
```

## Step 6: Agent tick cycle (every ~30ms, independent per agent)

```mermaid
sequenceDiagram
    participant PA as PointAgent
    participant Algo as Algorithm
    participant PT as PositionTracker
    participant CR as CommunicationRelay

    loop Every ~30ms (independent)
        PA->>Algo: compute_step(state)
        Algo-->>PA: {new_position, updated_state}
        PA->>PT: report_position(tracker, self, position)

        PA->>Algo: get_shared_data(state)
        Algo-->>PA: data
        alt data != %{}
            PA->>CR: broadcast(relay, self, data)
        end

        PA->>PA: schedule_tick()
    end
```

## Step 7: Environment modules (continuous, parallel)

> **Note:** Both the ProximityDetector and the CommunicationRelay filter out
> disconnected (blocked) agents from their operations. The ProximityDetector
> excludes positions with `disconnected: true` before computing neighbors, and
> the CommunicationRelay ignores broadcasts to/from blocked agents.

```mermaid
sequenceDiagram
    participant PT as PositionTracker
    participant PD as ProximityDetector
    participant CR as CommunicationRelay
    participant A as Agent A
    participant B as Agent B

    par ProximityDetector (every ~30ms)
        loop Every ~30ms
            PD->>PT: get_positions()
            PT-->>PD: all positions
            PD->>PD: Compute pairwise distances
            PD->>PD: Diff against previous state
            opt New pair in range
                PD->>A: drone_entered(B, pos)
                PD->>B: drone_entered(A, pos)
            end
            opt Pair leaves range
                PD->>A: drone_left(B)
                PD->>B: drone_left(A)
            end
        end
    and CommunicationRelay (on-demand)
        A->>CR: broadcast(data)
        CR->>PD: get_neighbors(A)
        PD-->>CR: [B]
        CR->>B: receive_shared_data(A, data)
    end
```

## Step 8: Objective detection (ObjectiveServer, parallel)

> Only applies when the simulation has an objective other than `"none"`.

```mermaid
sequenceDiagram
    participant OS as ObjectiveServer
    participant PT as PositionTracker
    participant Ex as Executor
    participant Agents as PointAgent × N
    participant Mg as Manager
    participant DB as Repo
    participant PS as PubSub

    loop Every ~30ms (while not found)
        OS->>OS: objective_module.tick(position, state, map)
        OS->>PT: get_positions_map()
        PT-->>OS: %{pid => %{x, y, id, ...}}
        OS->>OS: Filter disconnected + look for drone within range (25px)
    end

    Note over OS: Drone found within the detection radius

    OS->>Ex: send({:objective_found, drone_id, position})
    Ex->>Agents: receive_shared_data(:environment, %{type: :objective_found, position})
    Ex->>Mg: cast({:execution_complete, sim_id, stats})

    Mg->>DB: create_execution_run(stats)
    Mg->>PS: broadcast("simulation:sim_id", {:simulation_complete, ...})
    Mg->>Ex: stop(pid)
```

The stats include: `duration_ms`, `ticks`, `finder_drone_id`, `objective_position`,
`algorithm`, `map`, `objective`, `swarm_size`, `status`.

## Step 9: Redirect to stats screen

```mermaid
sequenceDiagram
    participant PS as PubSub
    participant Ch as Channel
    participant JS as Browser (JS)
    participant ERC as ExecutionRunController
    participant DB as Repo

    PS->>Ch: {:simulation_complete, %{execution_run_id, stats}}
    Ch->>JS: push "simulation_complete" %{execution_run_id, ...}
    Note over JS: Waits 1.5s
    JS->>ERC: GET /execution_runs/:id
    ERC->>DB: get_execution_run!(id)
    DB-->>ERC: %ExecutionRun{}
    ERC-->>JS: HTML with stats
```

The frontend displays: algorithm, map, objective, duration, ticks, finder drone,
objective position, and a button to re-run the simulation.
