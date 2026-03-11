defmodule Simulator.Maps.CleanMap do
  @moduledoc """
  A clean, empty map with no structures.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_parameters(_opts \\ %{}) do
    %MapParams{width: 500, height: 500, structures: [], spawn_point: %{x: 250, y: 250}}
  end
end
