defmodule Simulator.Algorithm do
  @moduledoc """
  Behaviour for simulator movement algorithms.

  Implementations must provide `update_position/1` which receives the
  agent state map (containing `:position` and `:map` keys) and returns
  the new `%{x, y}` position map.
  """

  @callback update_position(map()) :: map()
end
