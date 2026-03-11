defmodule Simulator.Maps.SquareObstacleMap do
  @moduledoc """
  A 1000x500 map with a 200x200 square obstacle centered in the middle.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_parameters(_opts \\ %{}) do
    %MapParams{
      width: 1000,
      height: 500,
      spawn_point: %{x: 200, y: 250},
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
