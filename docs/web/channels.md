# Channels (WebSocket)

## Conexión

- **Endpoint:** `/socket` (UserSocket)
- **Archivo socket:** `lib/simulator_web/channels/user_socket.ex`

## SimulationChannel

**Módulo:** `SimulatorWeb.SimulationChannel`
**Archivo:** `lib/simulator_web/channels/simulation_channel.ex`
**Topic:** `"simulation:<id>"`

### Join

Al unirse al channel (`join/3`):
1. Carga la simulación desde la DB
2. Llama `SimulationManager.start_execution(simulation)` — si ya existe, retorna el Executor existente
3. Programa el primer `:tick`
4. Retorna `:ok`

### Tick Loop

Cada `@tick_interval` ms (configurable via `Application.compile_env(:simulator, :tick_interval, 30)`):

1. `SimulationManager.get_positions(simulation)` → posiciones de todos los agentes
2. `push(socket, "positions", %{positions: positions})` → envía al frontend
3. Si hay un dron seleccionado, obtiene su detalle y hace push de `"drone_detail"`
4. Programa el siguiente tick

### Eventos Entrantes (frontend → backend)

| Evento | Payload | Efecto |
|--------|---------|--------|
| `"select_drone"` | `%{"id" => integer}` | Almacena el ID del dron seleccionado en `socket.assigns` |
| `"deselect_drone"` | `%{}` | Limpia la selección |

### Eventos Salientes (backend → frontend)

| Evento | Payload | Frecuencia |
|--------|---------|------------|
| `"positions"` | `%{positions: [%{x, y, color, id}]}` | Cada tick |
| `"drone_detail"` | `%{id, position, neighbors_count, algorithm_state}` | Cada tick (si hay selección) |

### Diagrama de flujo (secuencia)

```mermaid
sequenceDiagram
    participant JS as Frontend (JS)
    participant Ch as Channel
    participant Mg as Manager
    participant Ex as Executor

    JS->>Ch: join("simulation:id")
    Ch->>Mg: start_execution(simulation)
    Mg->>Ex: start_link(simulation)
    Ex-->>Mg: {:ok, pid}
    Mg-->>Ch: :ok

    loop Cada ~30ms (:tick)
        Ch->>Mg: get_positions(simulation)
        Mg->>Ex: get_positions()
        Ex-->>Mg: %{positions: [...]}
        Mg-->>Ch: %{positions: [...]}
        Ch->>JS: push "positions"
    end

    JS->>Ch: "select_drone" %{id: 3}
    Note over Ch: Guarda en socket.assigns

    loop Tick con selección
        Ch->>Mg: get_agent_detail(sim, 3)
        Mg->>Ex: get_agent_detail(3)
        Ex-->>Mg: detail
        Mg-->>Ch: detail
        Ch->>JS: push "drone_detail"
    end

    JS->>Ch: "deselect_drone"
    Note over Ch: Limpia assigns
```

### Notas

- El concepto de "dron seleccionado" vive exclusivamente en la capa web
  (`socket.assigns.selected_drone`). El backend expone un query genérico
  `get_agent_detail` que no sabe sobre selección.
- El channel no controla comportamiento de drones — solo observa y transmite.
