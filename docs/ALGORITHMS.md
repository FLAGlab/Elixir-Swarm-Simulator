# Algoritmos de movimiento y comunicación

Este directorio contiene implementaciones de algoritmos para los agentes (`lib/simulator/algorithms/`).

## Requisitos

- Cada algoritmo debe ser un módulo que implemente la behaviour `Simulator.Algorithm`.
- Debe definir `compute_step(state)` (obligatorio) que reciba el `state` del agente y devuelva `{new_position, updated_state}`.
- Opcionalmente puede definir `get_shared_data(state)` y `handle_received_data(sender, data, state)` para habilitar comunicación entre drones.

## Callbacks

### `compute_step(state)` — obligatorio

Computa el siguiente paso del dron. Recibe el estado completo del agente:
- `state.position` — posición actual `%{x, y}`
- `state.map` — `%MapParams{width, height, structures}`
- `state.neighbors` — `%{pid => %{x, y}}` drones detectados en rango
- Cualquier key adicional que el algoritmo haya agregado al estado

Devuelve una tupla `{new_position, updated_state}` donde:
- `new_position` — el nuevo `%{x, y}`
- `updated_state` — el estado del agente con cualquier key interna del algoritmo actualizada

### `get_shared_data(state)` — opcional

Define qué información el dron comparte con sus vecinos en cada tick. La data se envía al CommunicationRelay que la entrega solo a drones dentro del rango de detección.

- Devuelve un `map()` con los datos a compartir
- Si no se implementa, el default es `%{}` (no comparte nada)

### `handle_received_data(sender, data, state)` — opcional

Procesa datos recibidos de un dron vecino. Llamado por el agente cuando el CommunicationRelay le entrega un mensaje.

- `sender` — PID del dron que envió los datos
- `data` — el mapa retornado por `get_shared_data/1` del dron emisor
- `state` — estado actual del agente
- Devuelve el estado actualizado
- Si no se implementa, el estado queda sin cambios

### `format_state(algo_state)` — opcional

Prepara el estado del algoritmo para consumo externo (e.g., panel de detalle del dron).
Permite al algoritmo combinar estructuras internas, eliminar detalles de implementación,
o reformatear datos antes de exponerlos. Llamado a través de `Algorithm.format_state/2`.

- `algo_state` — estado del algoritmo (sin keys del sistema como `:position`, `:neighbors`, etc.)
- Devuelve el estado transformado
- Si no se implementa, se devuelve el estado sin cambios

Ejemplo: `HeatmapWalk` combina `visited` + `received_visited` en una sola lista `visited`
y elimina keys internas (`received_visited`) antes de enviar al frontend.

## Ejemplo de uso

- Crear un agente con un algoritmo y mapa específicos:

      iex> {:ok, pid} = PointAgent.start_link("random_walk", "clean", tracker, relay, 1)

- Los nombres de algoritmo se resuelven a través de `Simulator.Algorithms.get_algorithm/1`.
  Acepta strings (busca en el registry) o módulos atom (los devuelve directamente).
  Si el string no se encuentra en `@available_algorithms`, se usa `RandomWalk` por defecto.

- Obtener la posición actual de un agente:

      iex> PointAgent.get_position(pid)
      %{x: 250, y: 250}

## Implementar un nuevo algoritmo

### Algoritmo básico (solo movimiento)

1. Crear un módulo en `lib/simulator/algorithms/impl/`:

       defmodule Simulator.Algorithms.MyAlgo do
         @moduledoc "Descripción del algoritmo."
         @behaviour Simulator.Algorithm

         @impl true
         def compute_step(%{position: position, map: map} = state) do
           # Calcular nueva posición usando position.x, position.y
           # y los límites map.width, map.height.
           new_position = %{position | x: new_x, y: new_y}
           {new_position, state}
         end
       end

2. Registrar el algoritmo en `Simulator.Algorithms` (`lib/simulator/algorithms/algorithms.ex`),
   agregándolo al mapa `@available_algorithms`:

       @available_algorithms %{
         "random_walk" => RandomWalk,
         "static" => Static,
         "my_algo" => MyAlgo
       }

### Algoritmo con estado interno

Para algoritmos que necesitan persistir estado entre ticks (como un target o datos acumulados),
se agregan keys al estado del agente y se retornan en `updated_state`:

    defmodule Simulator.Algorithms.AimRandomWalk do
      @moduledoc "Camina hacia un objetivo random, recalcula al llegar o colisionar."
      @behaviour Simulator.Algorithm

      @impl true
      def compute_step(%{position: position, map: map} = state) do
        target = Map.get(state, :target) || generate_target(map)
        # ... lógica de movimiento hacia target
        {new_position, Map.put(state, :target, new_target)}
      end
    end

### Algoritmo con comunicación

Para algoritmos que necesitan compartir información entre drones:

    defmodule Simulator.Algorithms.CooperativeSearch do
      @moduledoc "Algoritmo de búsqueda cooperativa."
      @behaviour Simulator.Algorithm

      @impl true
      def compute_step(%{position: position, map: map} = state) do
        # Puede usar state.neighbors y datos recibidos para decidir movimiento
        messages = Map.get(state, :received_messages, [])
        # ... lógica de movimiento usando mensajes de vecinos
        new_position = %{position | x: new_x, y: new_y}
        {new_position, state}
      end

      @impl true
      def get_shared_data(%{position: pos}) do
        # Compartir posición y estado con vecinos
        %{position: pos, status: :searching}
      end

      @impl true
      def handle_received_data(_sender, data, state) do
        # Almacenar mensajes recibidos para usar en compute_step
        messages = Map.get(state, :received_messages, [])
        Map.put(state, :received_messages, [data | messages])
      end
    end

### Algoritmo con conocimiento compartido (KnowledgeStore)

Para algoritmos que necesitan compartir y gestionar conocimiento posicional entre drones,
el módulo `Simulator.Algorithms.Helpers.KnowledgeStore` provee utilidades reutilizables:

- `decay(received_visited)` — elimina la posición más vieja de cada entry por tick
- `merge(received_visited, incoming_knowledge)` — merge con anti-eco (filtra self) y frescura
- `all_positions(visited, received_visited)` — combina propio + recibido en lista plana
- `build_shareable(visited, received_visited)` — arma mapa `%{source_pid => positions}` para broadcast
- `format_for_export(algo_state)` — combina para el frontend y elimina keys internas

Ejemplo de uso en `HeatmapWalk`:

    defmodule Simulator.Algorithms.HeatmapWalk do
      alias Simulator.Algorithms.Helpers.KnowledgeStore

      @impl true
      def get_shared_data(state) do
        visited = Map.get(state, :visited, [])
        received = Map.get(state, :received_visited, %{})
        %{type: :heatmap, knowledge: KnowledgeStore.build_shareable(visited, received)}
      end

      @impl true
      def handle_received_data(_sender, %{type: :heatmap, knowledge: incoming}, state) do
        received = Map.get(state, :received_visited, %{})
        Map.put(state, :received_visited, KnowledgeStore.merge(received, incoming))
      end

      @impl true
      def format_state(algo_state), do: KnowledgeStore.format_for_export(algo_state)
    end

El conocimiento se almacena por fuente original (`source_pid`), lo que:
- Previene eco (no almacenas tu propia data de vuelta)
- Evita duplicación (misma fuente siempre bajo la misma key)
- Permite transitividad (A comparte info de B a C, atribuida a B)
- Decae naturalmente (una posición menos por tick por entry)

## Utilidades de geometría

El módulo `Simulator.Algorithms.Helpers.Geometry` (`lib/simulator/geometry.ex`) provee funciones reutilizables
para algoritmos que necesitan detección de colisiones:

- `clamp(value, min, max)` — limita un valor entre mínimo y máximo
- `euclidean_distance(p1, p2)` — distancia euclidiana entre dos puntos `%{x, y}`
- `point_in_polygon?({x, y}, points)` — verifica si un punto está dentro de un polígono
- `segment_intersects_polygon?(p1, p2, points)` — verifica si un segmento cruza un polígono
- `inside_structure?({x, y}, structures)` — verifica si un punto cae dentro de cualquier estructura del mapa
- `path_collides?(from, to, structures)` — verifica si un movimiento colisiona con alguna estructura
- `random_open_point(map, fallback)` — genera un punto random fuera de obstáculos
- `step_toward(position, target, map, step_size)` — calcula un paso hacia un objetivo, clampeado al mapa

## Sistema de mapas

Los algoritmos reciben los parámetros del mapa en `state.map`, que es un struct
`%Simulator.Maps.MapParams{width, height, structures}`. Usa estos valores para
limitar el movimiento de los agentes dentro del espacio definido.

## Notas

- Las implementaciones existentes están en `lib/simulator/algorithms/impl/` (`RandomWalk`, `Static`, `AimRandomWalk`, `HeatmapWalk`).
- `PointAgent` es un GenServer que llama `algorithm.compute_step(state)` en cada tick (cada 30ms).
- Los callbacks opcionales se invocan a través de helpers en `Simulator.Algorithm`:
  `Algorithm.shared_data(module, state)` y `Algorithm.receive_data(module, sender, data, state)`.
  Estos verifican si el callback está implementado antes de llamarlo.
- `Algorithm.format_state(module, algo_state)` prepara el estado para consumo externo.
- El estado del agente incluye `neighbors` (mapa de PIDs a posiciones) detectados por el ProximityDetector.
- Los datos compartidos se entregan via CommunicationRelay solo a vecinos dentro del radio de detección.
