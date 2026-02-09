defmodule Simulator.Algorithms.Static do
  @moduledoc "Static algorithm: no movement."
  @behaviour Simulator.Algorithm

  @impl true
  def update_position(%{position: position, space: space}), do: position
end
