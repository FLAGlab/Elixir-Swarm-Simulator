# Simulation Maps

This directory contains map implementations for the simulations (`lib/simulator/maps/`).

## Requirements

- Each map must be a module that implements the `Simulator.Map` behaviour.
- It must define `get_paramethers(opts)` which receives a `map` of options and returns a `%Simulator.Maps.MapParams{}` struct with the dimensions and structures of the simulation space.

## `MapParams` Struct

The `Simulator.Maps.MapParams` struct defines the spatial parameters of the map:

```elixir
%Simulator.Maps.MapParams{
  width: non_neg_integer(),          # Map width in pixels
  height: non_neg_integer(),         # Map height in pixels
  structures: list(),                # List of structures/obstacles in the map
  spawn_point: %{x: non_neg_integer(), y: non_neg_integer()}  # Initial position for all agents
}
```

The `spawn_point` defines where all agents start. It must be outside of any structure polygon to prevent agents from spawning inside obstacles.

## Available Maps

Maps are registered in `Simulator.Maps` (`lib/simulator/maps/maps.ex`) inside the `@available_maps` map:

| Key          | Module                       | Dimensions | Description                  |
|--------------|------------------------------|------------|------------------------------|
| `"clean"`    | `Simulator.Maps.CleanMap`    | 500x500    | Empty map with no structures |
| `"city"`     | `Simulator.Maps.CityMap`     | 500x500    | City-style map               |
| `"big_clean"`| `Simulator.Maps.BigCleanMap` | 1000x500   | Large empty map              |
| `"square_obstacle"`| `Simulator.Maps.SquareObstacleMap` | 1000x500 | Map with a centered 200x200 square obstacle |

## Usage Examples

- Get a map module by name:

      iex> Simulator.Maps.get_map("clean")
      Simulator.Maps.CleanMap

- Get the parameters of a map:

      iex> Simulator.Maps.get_map("clean").get_paramethers()
      %Simulator.Maps.MapParams{width: 500, height: 500, structures: []}

- Map names are resolved through `Simulator.Maps.get_map/1`.
  If the name is not found in `@available_maps`, `CleanMap` is used by default.

- List available maps:

      iex> Simulator.Maps.get_available_maps_keys()
      ["big_clean", "city", "clean", "square_obstacle"]

## Implementing a New Map

1. Create a module in `lib/simulator/maps/impl/`:

       defmodule Simulator.Maps.MyMap do
         @moduledoc "Description of the map."
         @behaviour Simulator.Map

         alias Simulator.Maps.MapParams

         @impl true
         def get_paramethers(_opts \\ %{}) do
           %MapParams{
             width: 800,
             height: 600,
             spawn_point: %{x: 400, y: 300},
             structures: [
               # Define obstacles or structures here
             ]
           }
         end
       end

2. Register the map in `Simulator.Maps` (`lib/simulator/maps/maps.ex`),
   adding it to the `@available_maps` map:

       @available_maps %{
         "clean" => CleanMap,
         "city" => CityMap,
         "big_clean" => BigCleanMap,
         "my_map" => MyMap
       }

## How Maps Are Used

Map parameters are loaded at two points:

1. **When creating a `PointAgent`**: `PointAgent.start_link/5` resolves the map name and stores the `%MapParams{}` in the agent state under the `:map` key. The agent's initial position is set to `map.spawn_point`.

2. **Inside algorithms**: Each algorithm receives the full agent state including `state.map` with the `width`, `height`, and `structures` fields. Algorithms use these values to constrain movement within the defined space (for example, `RandomWalk` clamps positions between `0` and `map.width`/`map.height`).

## Notes

- Existing implementations are in `lib/simulator/maps/impl/` (`CleanMap`, `CityMap`, `BigCleanMap`, `SquareObstacleMap`).
- The `structures` field defines obstacles as polygon point lists (see `SquareObstacleMap` for an example).
- The frontend canvas uses the same `width` and `height` values from `MapParams` to size the visualization area.
