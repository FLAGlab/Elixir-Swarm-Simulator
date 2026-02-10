defmodule Simulator.Algorithms.RandomWalk do
  @moduledoc "Random walk algorithm: moves x and y by a small random delta."
  @behaviour Simulator.Algorithm

  @impl true
  def update_position(%{position: position, map: map}) do
    new_x = clamp(position.x + Enum.random(-5..5), 0, map.width)
    new_y = clamp(position.y + Enum.random(-5..5), 0, map.height)

    %{position | x: new_x, y: new_y}
  end

  defp clamp(value, min, max) do
    cond do
      value < min -> min
      value > max -> max
      true -> value
    end
  end
end
