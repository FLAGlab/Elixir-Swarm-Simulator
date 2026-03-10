# Algoritmos de movimiento y comunicación

Este directorio contiene implementaciones de algoritmos para los agentes (`lib/simulator/algorithms/`).

## Requisitos

- Cada algoritmo debe ser un módulo que implemente la behaviour `Simulator.Algorithm`.
- Debe definir `update_position(state)` (obligatorio) que reciba el `state` del agente y devuelva el nuevo `%{x, y}` de posición.
- Opcionalmente puede definir `get_shared_data(state)` y `handle_received_data(sender, data, state)` para habilitar comunicación entre drones.

## Callbacks

### `update_position(state)` — obligatorio

Decide el próximo movimiento del dron. Recibe el estado completo del agente:
- `state.position` — posición actual `%{x, y}`
- `state.map` — `%MapParams{width, height, structures}`
- `state.neighbors` — `%{pid => %{x, y}}` drones detectados en rango
- Cualquier key adicional que el algoritmo haya agregado al estado

Devuelve el nuevo `%{x, y}`.

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

## Ejemplo de uso

- Crear un agente con un algoritmo y mapa específicos:

      iex> {:ok, pid} = PointAgent.start_link("random_walk", "clean", tracker, relay)

- Los nombres de algoritmo se resuelven a través de `Simulator.Algorithms.get_algorithm/1`.
  Acepta strings (busca en el registry) o módulos atom (los devuelve directamente).
  Si el string no se encuentra en `@available_algorithms`, se usa `RandomWalk` por defecto.

- Obtener la posición actual de un agente:

      iex> PointAgent.get_position(pid)
      %{x: 255, y: 255}

## Implementar un nuevo algoritmo

### Algoritmo básico (solo movimiento)

1. Crear un módulo en `lib/simulator/algorithms/impl/`:

       defmodule Simulator.Algorithms.MyAlgo do
         @moduledoc "Descripción del algoritmo."
         @behaviour Simulator.Algorithm

         @impl true
         def update_position(%{position: position, map: map}) do
           # Calcular nueva posición usando position.x, position.y
           # y los límites map.width, map.height.
           %{position | x: new_x, y: new_y}
         end
       end

2. Registrar el algoritmo en `Simulator.Algorithms` (`lib/simulator/algorithms/algorithms.ex`),
   agregándolo al mapa `@available_algorithms`:

       @available_algorithms %{
         "random_walk" => RandomWalk,
         "static" => Static,
         "my_algo" => MyAlgo
       }

### Algoritmo con comunicación

Para algoritmos que necesitan compartir información entre drones:

    defmodule Simulator.Algorithms.CooperativeSearch do
      @moduledoc "Algoritmo de búsqueda cooperativa."
      @behaviour Simulator.Algorithm

      @impl true
      def update_position(%{position: position, map: map} = state) do
        # Puede usar state.neighbors y datos recibidos para decidir movimiento
        messages = Map.get(state, :received_messages, [])
        # ... lógica de movimiento usando mensajes de vecinos
        %{position | x: new_x, y: new_y}
      end

      @impl true
      def get_shared_data(%{position: pos}) do
        # Compartir posición y estado con vecinos
        %{position: pos, status: :searching}
      end

      @impl true
      def handle_received_data(_sender, data, state) do
        # Almacenar mensajes recibidos para usar en update_position
        messages = Map.get(state, :received_messages, [])
        Map.put(state, :received_messages, [data | messages])
      end
    end

## Sistema de mapas

Los algoritmos reciben los parámetros del mapa en `state.map`, que es un struct
`%Simulator.Maps.MapParams{width, height, structures}`. Usa estos valores para
limitar el movimiento de los agentes dentro del espacio definido.

## Notas

- Las implementaciones existentes están en `lib/simulator/algorithms/impl/` (`RandomWalk`, `Static`).
- `PointAgent` es un GenServer que llama `algorithm.update_position(state)` en cada tick (cada 30ms).
- Los callbacks opcionales se invocan a través de helpers en `Simulator.Algorithm`:
  `Algorithm.shared_data(module, state)` y `Algorithm.receive_data(module, sender, data, state)`.
  Estos verifican si el callback está implementado antes de llamarlo.
- El estado del agente incluye `neighbors` (mapa de PIDs a posiciones) detectados por el ProximityDetector.
- Los datos compartidos se entregan via CommunicationRelay solo a vecinos dentro del radio de detección.
