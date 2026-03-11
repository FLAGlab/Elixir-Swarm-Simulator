defmodule Simulator.Maps.BigCleanMap do
  @moduledoc """
  A large clean map (1000x500) with no structures.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_parameters(_opts \\ %{}) do
    %MapParams{width: 1000, height: 500, structures: [], spawn_point: %{x: 500, y: 250}}
  end
end
