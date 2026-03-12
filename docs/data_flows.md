# Data Flows: Ejecución en Tiempo Real

Este documento describe el flujo completo de datos desde que el usuario crea una simulación
hasta que ve los agentes moviéndose en el canvas.

## Diagrama General

```mermaid
flowchart TD
    subgraph Browser
        UI["UI (Forms)"]
        Canvas["Canvas (JS)"]
        Stats["Stats Page"]
    end

    subgraph Web["Capa Web"]
        SC["SimulationController"]
        EC["ExecutionController"]
        ERC["ExecutionRunController"]
        Ch["SimulationChannel"]
    end

    subgraph App["Capa Aplicación"]
        Mg["SimulationManager"]
        PS["PubSub"]
    end

    subgraph Sim["Capa Simulación"]
        Ex["SimulationExecutor"]
        PT["PositionTracker"]
        PD["ProximityDetector"]
        CR["CommunicationRelay"]
        OS["ObjectiveServer\n(opcional)"]
    end

    subgraph Agents["Capa Agente"]
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
    OS -- "lee posiciones" --> PT
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

## Paso 1: Creación de simulación (CRUD)

```mermaid
sequenceDiagram
    participant B as Browser
    participant SC as SimulationController
    participant DB as Repo (SQLite)

    B->>SC: POST /simulations
    SC->>DB: Repo.insert(changeset)
    DB-->>SC: {:ok, simulation}
    SC-->>B: Redirect a /simulations/:id
```

El usuario crea un record de simulación con nombre, algoritmo, cantidad de agentes, mapa y objetivo.

## Paso 2: Lanzamiento de ejecución

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
    EC-->>B: HTML + Canvas (dimensionado según MapParams)
```

## Paso 3: Conexión WebSocket

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
    opt Objetivo != "none"
        Ex->>OS: ObjectiveServer.start_link(objective_module, map, tracker, self)
    end
    Ex->>Agents: start_link × N (algorithm, map, tracker, relay)
    deactivate Ex

    Mg-->>Ch: {:ok, pid}
    Ch->>Ch: schedule_tick()
    Ch-->>JS: :ok
```

## Paso 4: Loop de posiciones en tiempo real (cada ~30ms)

```mermaid
sequenceDiagram
    participant JS as Browser
    participant Ch as Channel
    participant Mg as Manager
    participant Ex as Executor
    participant PT as PositionTracker

    loop Cada ~30ms
        Ch->>Ch: handle_info(:tick)
        Ch->>Mg: get_positions(simulation)
        Mg->>Ex: get_positions()
        Ex->>PT: get_positions()
        PT-->>Ex: %{positions: [%{x, y, color, id}...]}
        opt Hay ObjectiveServer
            Ex->>Ex: Agrega objective position al response
        end
        Ex-->>Mg: %{positions: [...], objective: %{x, y}}
        Mg-->>Ch: positions
        Ch->>JS: push("positions", data)
        opt Dron seleccionado
            Ch->>Mg: get_agent_detail(sim, id)
            Mg-->>Ch: detail
            Ch->>JS: push("drone_detail", detail)
        end
        Ch->>Ch: schedule_tick()
    end
```

## Paso 4.5: Toggle de conexión de dron (on-demand)

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

    par Bloqueo en entorno
        Ex->>PT: block_agent(agent_pid)
        Note over PT: Ignora report_position del dron<br/>Marca posición con disconnected: true
    and
        Ex->>CR: block_agent(agent_pid)
        Note over CR: Ignora broadcasts del dron<br/>No entrega mensajes al dron
    end

    Ex-->>Mg: :ok
    Mg-->>Ch: :ok

    Note over JS: ProximityDetector filtra al dron<br/>→ dispara drone_left a sus vecinos
    Note over JS: Siguiente tick muestra dron gris con opacidad 0.4
```

El dron **sigue corriendo** su tick loop — llama `compute_step`, intenta `report_position`
y `broadcast`, pero el entorno los ignora. Al reconectar (`connected: true`), el entorno
reanuda el tracking y el dron conserva su estado sucio (vecinos obsoletos, datos antiguos).

## Paso 5: Renderizado en Canvas (Browser)

```mermaid
flowchart TD
    Event["Recibe evento 'positions'"] --> Clear["Clear canvas"]
    Clear --> Structures["Dibujar structures\n(polígonos grises)"]
    Structures --> Overlay{"Hay dron\nseleccionado\ncon overlay?"}
    Overlay -- "Si" --> DrawOverlay["Dibujar overlay\n(heatmap / feromonas)"]
    Overlay -- "No" --> DrawObj
    DrawOverlay --> DrawObj{"Hay objetivo?"}
    DrawObj -- "Si" --> Objective["Dibujar objetivo\n(círculo rojo)"]
    DrawObj -- "No" --> DrawAgents
    Objective --> DrawAgents["Dibujar agentes\n(círculos concéntricos)"]
    DrawAgents --> Colors["Colorear:\nvioleta = solo\nverde = con vecinos\námbar = seleccionado"]
    Colors --> Grid["Actualizar drone grid\ny detail panel"]
```

## Paso 6: Ciclo de tick del agente (cada ~30ms, independiente por agente)

```mermaid
sequenceDiagram
    participant PA as PointAgent
    participant Algo as Algorithm
    participant PT as PositionTracker
    participant CR as CommunicationRelay

    loop Cada ~30ms (independiente)
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

## Paso 7: Módulos de entorno (continuo, paralelo)

> **Nota:** Tanto el ProximityDetector como el CommunicationRelay filtran agentes
> desconectados (bloqueados) de sus operaciones. El ProximityDetector excluye posiciones
> con `disconnected: true` antes de calcular vecinos, y el CommunicationRelay ignora
> broadcasts de/hacia agentes bloqueados.

```mermaid
sequenceDiagram
    participant PT as PositionTracker
    participant PD as ProximityDetector
    participant CR as CommunicationRelay
    participant A as Agent A
    participant B as Agent B

    par ProximityDetector (cada ~30ms)
        loop Cada ~30ms
            PD->>PT: get_positions()
            PT-->>PD: todas las posiciones
            PD->>PD: Calcula distancias entre pares
            PD->>PD: Diff con estado anterior
            opt Nuevo par en rango
                PD->>A: drone_entered(B, pos)
                PD->>B: drone_entered(A, pos)
            end
            opt Par sale de rango
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

## Paso 8: Detección de objetivo (ObjectiveServer, paralelo)

> Solo aplica cuando la simulación tiene un objetivo distinto de `"none"`.

```mermaid
sequenceDiagram
    participant OS as ObjectiveServer
    participant PT as PositionTracker
    participant Ex as Executor
    participant Agents as PointAgent × N
    participant Mg as Manager
    participant DB as Repo
    participant PS as PubSub

    loop Cada ~30ms (mientras no encontrado)
        OS->>OS: objective_module.tick(position, state, map)
        OS->>PT: get_positions_map()
        PT-->>OS: %{pid => %{x, y, id, ...}}
        OS->>OS: Filtrar desconectados + buscar dron en rango (25px)
    end

    Note over OS: Dron encontrado dentro del radio de detección

    OS->>Ex: send({:objective_found, drone_id, position})
    Ex->>Agents: receive_shared_data(:environment, %{type: :objective_found, position})
    Ex->>Mg: cast({:execution_complete, sim_id, stats})

    Mg->>DB: create_execution_run(stats)
    Mg->>PS: broadcast("simulation:sim_id", {:simulation_complete, ...})
    Mg->>Ex: stop(pid)
```

Las estadísticas incluyen: `duration_ms`, `ticks`, `finder_drone_id`, `objective_position`,
`algorithm`, `map`, `objective`, `swarm_size`, `status`.

## Paso 9: Redirección a pantalla de estadísticas

```mermaid
sequenceDiagram
    participant PS as PubSub
    participant Ch as Channel
    participant JS as Browser (JS)
    participant ERC as ExecutionRunController
    participant DB as Repo

    PS->>Ch: {:simulation_complete, %{execution_run_id, stats}}
    Ch->>JS: push "simulation_complete" %{execution_run_id, ...}
    Note over JS: Espera 1.5s
    JS->>ERC: GET /execution_runs/:id
    ERC->>DB: get_execution_run!(id)
    DB-->>ERC: %ExecutionRun{}
    ERC-->>JS: HTML con estadísticas
```

El frontend muestra: algoritmo, mapa, objetivo, duración, ticks, dron finder,
posición del objetivo, y un botón para volver a ejecutar la simulación.
