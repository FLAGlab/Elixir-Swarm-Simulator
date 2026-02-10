defmodule Simulator.Maps do
  @moduledoc """
  Centralized map management.
  """

  alias Simulator.Maps.{CleanMap, CityMap, BigCleanMap}

  @available_maps %{
    "clean" => CleanMap,
    "city" => CityMap,
    "big_clean" => BigCleanMap
  }

  @spec get_map(String.t()) :: module() | nil
  def get_map(name) do
    Map.get(@available_maps, name, CleanMap)
  end
  @spec get_available_maps_keys() :: list()
  def get_available_maps_keys() do
    Map.keys(@available_maps)
  end
end
