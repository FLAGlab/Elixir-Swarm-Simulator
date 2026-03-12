# Data Flows: Ejecución en Tiempo Real

Este documento describe el flujo completo de datos desde que el usuario crea una simulación
hasta que ve los agentes moviéndose en el canvas.

## Diagrama General

```mermaid
flowchart TD
    subgraph Browser
        UI["UI (Forms)"]
        Canvas["Canvas (JS)"]
    end

    subgraph Web["Capa Web"]
        SC["SimulationController"]
        EC["ExecutionController"]
        Ch["SimulationChannel"]
    end

    subgraph App["Capa Aplicación"]
        Mg["SimulationManager"]
    end

    subgraph Sim["Capa Simulación"]
        Ex["SimulationExecutor"]
        PT["PositionTracker"]
        PD["ProximityDetector"]
        CR["CommunicationRelay"]
    end

    subgraph Agents["Capa Agente"]
        A["PointAgent × N"]
    end

    DB[("SQLite")]

    UI -- "POST /simulations" --> SC
    SC --> DB
    UI -- "GET /execution/:id" --> EC
    EC --> DB
    Canvas <-- "WebSocket" --> Ch
    Ch --> Mg
    Mg --> Ex
    Ex --> PT & PD & CR
    PT --> PD
    PD --> CR
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

El usuario crea un record de simulación con tipo, algoritmo, cantidad de agentes y mapa.

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
    participant Agents as PointAgent × N

    JS->>Ch: join("simulation:id")
    Ch->>Mg: start_execution(simulation)

    Mg->>Ex: start_link(simulation)
    activate Ex
    Ex->>PT: start_link()
    Ex->>PD: start_link(tracker)
    Ex->>CR: start_link(proximity)
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
        Ex-->>Mg: positions
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

## Paso 5: Renderizado en Canvas (Browser)

```mermaid
flowchart TD
    Event["Recibe evento 'positions'"] --> Clear["Clear canvas"]
    Clear --> Structures["Dibujar structures\n(polígonos grises)"]
    Structures --> Overlay{"Hay dron\nseleccionado\ncon overlay?"}
    Overlay -- "Si" --> DrawOverlay["Dibujar overlay\n(heatmap / feromonas)"]
    Overlay -- "No" --> DrawAgents
    DrawOverlay --> DrawAgents["Dibujar agentes\n(círculos concéntricos)"]
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
