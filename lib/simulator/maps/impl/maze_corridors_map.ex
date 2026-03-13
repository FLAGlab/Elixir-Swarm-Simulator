defmodule Simulator.Maps.MazeCorridorsMap do
  @moduledoc """
  A 1200x600 maze map with staggered rectangular blocks creating corridors.

  Blocks are arranged in a grid pattern with alternating offsets per row,
  forcing drones to navigate through channels. The spawn point is on the
  left side.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_parameters(_opts \\ %{}) do
    %MapParams{
      width: 1200,
      height: 600,
      spawn_point: %{x: 60, y: 300},
      structures: blocks()
    }
  end

  # Private ----------------------------------------------------------

  defp blocks do
    # Row config: {y_center, [x_centers]}
    # Odd rows offset to create maze corridors
    rows = [
      {100, [150, 400, 650, 900, 1100]},
      {250, [275, 525, 775, 1025]},
      {400, [150, 400, 650, 900, 1100]},
      {530, [275, 525, 775, 1025]}
    ]

    w = 120
    h = 80
    hw = div(w, 2)
    hh = div(h, 2)

    rows
    |> Enum.flat_map(fn {cy, xs} ->
      Enum.map(xs, fn cx -> {cx, cy} end)
    end)
    |> Enum.with_index(1)
    |> Enum.map(fn {{cx, cy}, id} ->
      %{
        id: id,
        points: [
          {cx - hw, cy - hh},
          {cx + hw, cy - hh},
          {cx + hw, cy + hh},
          {cx - hw, cy + hh}
        ]
      }
    end)
  end
end
