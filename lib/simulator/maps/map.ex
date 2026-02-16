defmodule Simulator.Map do
  @moduledoc """
  Behaviour for simulation maps.

  Implementations must provide `get_paramethers/1` which returns a
  `Simulator.Maps.MapParams` struct defining the spatial dimensions
  and structures of the map.
  """

  alias Simulator.Maps.MapParams

  @callback get_paramethers(map()) :: MapParams.t()
end
