defmodule Simulator.Maps.BigCleanMap do
  @moduledoc """
  A large clean map (1000x500) with no structures.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_paramethers(_opts \\ %{}) do
    %MapParams{width: 1000, height: 500, structures: []}
  end
end
