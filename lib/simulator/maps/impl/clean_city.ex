defmodule Simulator.Maps.CityMap do
  @moduledoc """
  A city-style map (500x500) with no structures yet.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_paramethers(_opts \\ %{}) do
    %MapParams{width: 500, height: 500, structures: []}
  end
end
