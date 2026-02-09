defmodule Simulator.Map do
  alias Simulator.Maps.MapParams

  @callback get_paramethers(map()) :: MapParams.t()
end
