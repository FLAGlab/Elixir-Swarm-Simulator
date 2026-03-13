defmodule Simulator.Maps.ScatteredIslandsMap do
  @moduledoc """
  A 1200x600 open map with irregular obstacles scattered like islands.

  Features ~12 obstacles of varying sizes and shapes (rectangles, triangles,
  pentagons) spread across the area. The spawn point is on the left side.
  Good for testing open-field exploration with sporadic obstacles.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_parameters(_opts \\ %{}) do
    %MapParams{
      width: 1200,
      height: 600,
      spawn_point: %{x: 60, y: 300},
      structures: islands()
    }
  end

  # Private ----------------------------------------------------------

  defp islands do
    [
      # Top-left cluster: two small islands
      %{id: 1, points: [{120, 60}, {200, 40}, {220, 100}, {160, 120}]},
      %{id: 2, points: [{280, 100}, {350, 80}, {370, 150}, {310, 160}, {270, 140}]},

      # Large central-left block
      %{id: 3, points: [{180, 250}, {320, 250}, {320, 380}, {180, 380}]},

      # Top-center triangle
      %{id: 4, points: [{500, 50}, {580, 130}, {420, 130}]},

      # Center: large irregular polygon
      %{id: 5, points: [{520, 240}, {640, 220}, {680, 280}, {660, 360}, {560, 380}, {500, 320}]},

      # Small obstacle mid-right
      %{id: 6, points: [{780, 150}, {840, 150}, {840, 210}, {780, 210}]},

      # Right-center large island
      %{id: 7, points: [{850, 280}, {960, 260}, {1000, 320}, {980, 400}, {870, 390}]},

      # Bottom-left
      %{id: 8, points: [{100, 450}, {180, 430}, {200, 500}, {140, 530}, {80, 500}]},

      # Bottom-center
      %{id: 9, points: [{400, 460}, {500, 440}, {520, 520}, {420, 540}]},

      # Far right top
      %{id: 10, points: [{1050, 60}, {1150, 60}, {1150, 160}, {1050, 160}]},

      # Far right bottom
      %{id: 11, points: [{1060, 400}, {1160, 380}, {1180, 460}, {1100, 500}, {1040, 460}]},

      # Small bottom-right
      %{id: 12, points: [{750, 480}, {810, 470}, {820, 530}, {760, 540}]}
    ]
  end
end
