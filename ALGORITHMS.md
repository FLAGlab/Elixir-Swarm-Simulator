# Algoritmos de movimiento

Este directorio contiene implementaciones de algoritmos de movimiento para los agentes (`lib/simulator/algorithms/`).

## Requisitos

- Cada algoritmo debe ser un módulo que implemente la behaviour `Simulator.Algorithm`.
- Debe definir `update_position(state)` que reciba el `state` del agente (un `map` con las keys `:position` y `:map`) y devuelva el nuevo `%{x, y}` de posición.

## Ejemplo de uso

- Crear un agente con un algoritmo y mapa específicos:

      iex> {:ok, pid} = PointAgent.start_link("random_walk", "clean")

- Los nombres de algoritmo se resuelven a través de `Simulator.Algorithms.get_algorithm/1`.
  Si el nombre no se encuentra en `@available_algorithms`, se usa `RandomWalk` por defecto.

- Obtener la posición actual de un agente:

      iex> PointAgent.get_position(pid)
      %{x: 255, y: 255}

## Implementar un nuevo algoritmo

1. Crear un módulo en `lib/simulator/algorithms/impl/`:

       defmodule Simulator.Algorithms.MyAlgo do
         @moduledoc "Descripción del algoritmo."
         @behaviour Simulator.Algorithm

         @impl true
         def update_position(%{position: position, map: map}) do
           # Calcular nueva posición usando position.x, position.y
           # y los límites map.width, map.height.
           # Devolver el nuevo mapa de posición:
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

## Sistema de mapas

Los algoritmos reciben los parámetros del mapa en `state.map`, que es un struct
`%Simulator.Maps.MapParams{width, height, structures}`. Usa estos valores para
limitar el movimiento de los agentes dentro del espacio definido.

## Notas

- Las implementaciones existentes están en `lib/simulator/algorithms/impl/` (`RandomWalk`, `Static`).
- `PointAgent` guarda el módulo de algoritmo en el estado bajo la key `:algorithm` y llama `algorithm.update_position(state)` en cada tick (cada `@update_interval` ms).
- El parámetro del mapa se guarda bajo la key `:map` como un `%MapParams{}`.
