defmodule Simulator.Maps.CityMap do
  @moduledoc """
  A 500x500 city-style map with 8 square blocks arranged around an open center.
  """

  @behaviour Simulator.Map

  alias Simulator.Maps.MapParams

  @impl true
  def get_paramethers(_opts \\ %{}) do
    %MapParams{width: 500, height: 500, structures: blocks(), spawn_point: %{x: 250, y: 250}}
  end

  # Private ----------------------------------------------------------

  defp blocks do
    size = 60
    half = div(size, 2)

    centers = [
      {125, 125},
      {250, 125},
      {375, 125},
      {125, 250},
      {375, 250},
      {125, 375},
      {250, 375},
      {375, 375}
    ]

    centers
    |> Enum.with_index(1)
    |> Enum.map(fn {{cx, cy}, id} ->
      %{
        id: id,
        points: [
          {cx - half, cy - half},
          {cx + half, cy - half},
          {cx + half, cy + half},
          {cx - half, cy + half}
        ]
      }
    end)
  end
end
