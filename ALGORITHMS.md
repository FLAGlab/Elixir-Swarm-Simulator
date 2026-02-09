# Algoritmos de movimiento 🤖

Este directorio contiene implementaciones de algoritmos de movimiento para los agentes (`lib/simulator/algorithms`).

Requisitos
- Cada algoritmo debe ser un módulo que implemente la behaviour `Simulator.Algorithm`.
- Debe definir `update_position(state)` que reciba el `state` del agente (un `map`) y devuelva el `state` actualizado.

Ejemplo de uso

- Crear un agente con el algoritmo por defecto (RandomWalk):

    iex> {:ok, pid} = PointAgent.start_link()

- Crear un agente con un algoritmo específico:

    iex> {:ok, pid} = PointAgent.start_link(Simulator.Algorithms.Static)

- Cambiar el algoritmo en tiempo de ejecución:

    iex> PointAgent.set_algorithm(pid, Simulator.Algorithms.RandomWalk)

- Implementar un nuevo algoritmo:

    defmodule Simulator.Algorithms.MyAlgo do
      @behaviour Simulator.Algorithm

      @impl true
      def update_position(state) do
        # calcular nueva posición y devolver el state actualizado
      end
    end

Notas
- Las implementaciones existentes están en `lib/simulator/algorithms` (`RandomWalk`, `Static`).
- `PointAgent` guarda el módulo de algoritmo en el estado bajo la key `:algorithm` y llama `algorithm.update_position(state)` en cada tick.
