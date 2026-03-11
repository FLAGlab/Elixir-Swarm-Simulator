defmodule Simulator.Maps.MapParams do
  @moduledoc """
  Struct representing the parameters of a simulation map.
  """

  defstruct width: 0, height: 0, structures: [], spawn_point: %{x: 0, y: 0}

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          structures: list(),
          spawn_point: %{x: non_neg_integer(), y: non_neg_integer()}
        }
end
