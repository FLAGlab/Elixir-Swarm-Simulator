defmodule Simulator.Maps.BigCleanMap do
  @moduledoc """
  A clean, empty map with no structures.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_paramethers(_opts \\ %{}) do
    %MapParams{width: 1000, height: 500, structures: []}
  end
end
