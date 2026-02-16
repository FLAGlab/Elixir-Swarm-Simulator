defmodule Simulator.Maps do
  @moduledoc """
  Registry of available simulation maps.

  Maps string names to modules that implement the `Simulator.Map`
  behaviour. When a name is not found, defaults to `CleanMap`.
  """

  alias Simulator.Maps.{CleanMap, CityMap, BigCleanMap, SquareObstacleMap}

  @available_maps %{
    "clean" => CleanMap,
    "city" => CityMap,
    "big_clean" => BigCleanMap,
    "square_obstacle" => SquareObstacleMap
  }

  @doc """
  Returns the module implementing the given map name.

  Falls back to `CleanMap` when `name` is not found in `@available_maps`.
  """
  @spec get_map(String.t()) :: module()
  def get_map(name) do
    Map.get(@available_maps, name, CleanMap)
  end

  @doc """
  Returns the list of registered map name strings.
  """
  @spec get_available_maps_keys() :: list()
  def get_available_maps_keys() do
    Map.keys(@available_maps)
  end
end
