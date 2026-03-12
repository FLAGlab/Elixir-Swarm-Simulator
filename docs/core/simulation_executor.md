# SimulationExecutor

**Módulo:** `Simulator.SimulationExecutor`
**Archivo:** `lib/simulator/simulation_executor.ex`

## Descripción

El Executor es el **simulador del entorno**, no un controlador de drones. En una simulación
de enjambre, todas las decisiones deben ocurrir dentro de cada dron (PointAgent) — el trabajo
del Executor es simular el mundo físico que los rodea.

## Árbol de Procesos

Al inicializarse, el Executor crea tres módulos de entorno y luego spawna los agentes:

```
SimulationExecutor
  |-- PositionTracker      (almacena posiciones broadcast por agentes)
  |-- ProximityDetector    (detecta cuando drones entran/salen del rango)
  |-- CommunicationRelay   (entrega datos compartidos entre drones vecinos)
  |-- PointAgent x N       (procesos de drones autónomos)
```

## Diagrama de Procesos

```mermaid
flowchart TD
    Exec["SimulationExecutor"]

    Exec --> PT["PositionTracker"]
    Exec --> PD["ProximityDetector"]
    Exec --> CR["CommunicationRelay"]

    PD -- "lee posiciones" --> PT
    CR -- "consulta vecinos" --> PD

    Exec --> A1["PointAgent 1"]
    Exec --> A2["PointAgent 2"]
    Exec --> A3["PointAgent ..."]
    Exec --> AN["PointAgent N"]

    A1 & A2 & A3 & AN -- "report_position" --> PT
    A1 & A2 & A3 & AN -- "broadcast" --> CR
    CR -- "receive_shared_data" --> A1 & A2 & A3 & AN
    PD -- "drone_entered / drone_left" --> A1 & A2 & A3 & AN
```

## Ciclo de Vida

```mermaid
stateDiagram-v2
    [*] --> Iniciando: start_link(simulation)
    Iniciando --> Operativo: init completo\n(environment + agents spawned)
    Operativo --> Operativo: get_positions / get_agent_detail
    Operativo --> Terminando: stop() / terminate()
    Terminando --> [*]: agents + environment detenidos
```

## Estado

```elixir
%{
  simulation: %Simulation{},     # Record de la simulación (de la DB)
  agents: %{id => pid},          # Mapa de ID → PID de cada agente
  tracker: pid(),                # PID del PositionTracker
  proximity: pid(),              # PID del ProximityDetector
  relay: pid()                   # PID del CommunicationRelay
}
```

## Responsabilidades

| Responsabilidad | Descripción |
|----------------|-------------|
| **Spawn agents** | Crea N procesos `PointAgent` (N = `simulation.swarm`), cada uno con su ID |
| **Orquestar environment modules** | Inicia y cablea PositionTracker, ProximityDetector, CommunicationRelay |
| **Agregar posiciones** | `get_positions/1` lee del PositionTracker |
| **Query agent detail** | `get_agent_detail/2` obtiene el estado detallado de un agente por ID |
| **Simular periféricos** | Puede enviar warnings de colisión, alertas de proximidad, o datos de sensores |
| **Gestionar objetivos** | Conoce la ubicación de objetivos de búsqueda. Los drones NO lo saben — el Executor notifica solo cuando "detectan" algo |
| **Shutdown de drones** | Puede terminar agentes específicos para simular fallas de hardware |

## API Pública

| Función | Descripción |
|---------|-------------|
| `start_link(simulation)` | Inicia el Executor con una simulación |
| `get_positions(pid)` | Retorna todas las posiciones de los agentes |
| `get_agent_detail(pid, agent_id)` | Retorna el estado detallado de un agente |
| `stop(pid)` | Detiene el Executor y todos sus procesos hijos |

## Ciclo de Vida

1. **Inicio**: `SimulationManager.start_execution/1` crea el Executor
2. **Operación**: Los agentes operan independientemente, el Executor solo responde queries
3. **Terminación**: `terminate/2` detiene todos los agentes y environment modules
4. **Registro**: Registrado por `simulation.type` en el Registry (uno por tipo de simulación)

## Relación con otros componentes

```
SimulationManager  ──calls──►  SimulationExecutor  ──starts──►  Environment Modules
                                                    ──spawns──►  PointAgents
```

El Executor nunca es accedido directamente por la capa web — toda comunicación
pasa por el SimulationManager.
