defmodule Simulator.Algorithm do
  @moduledoc """
  Behaviour for simulator movement algorithms.

  Implementations must provide `update_position/1` which receives the
  agent state map and returns the updated state map.
  """

  @callback update_position(map()) :: map()
end
