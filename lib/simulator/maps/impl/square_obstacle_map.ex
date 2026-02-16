defmodule Simulator.Maps.SquareObstacleMap do
  @moduledoc """
  A 1000x500 map with a 200x200 square obstacle centered in the middle.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_paramethers(_opts \\ %{}) do
    %MapParams{
      width: 1000,
      height: 500,
      structures: [
        %{
          id: 1,
          points: [
            {400, 150},
            {600, 150},
            {600, 350},
            {400, 350}
          ]
        }
      ]
    }
  end
end
