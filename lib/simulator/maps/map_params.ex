defmodule Simulator.Maps.MapParams do
  @moduledoc """
  Struct representing the parameters of a simulation map.
  """

  defstruct width: 0, height: 0, structures: []

  @type t :: %__MODULE__{
          width: non_neg_integer(),
          height: non_neg_integer(),
          structures: list()
        }
end
