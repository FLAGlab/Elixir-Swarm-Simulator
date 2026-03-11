defmodule Simulator.Algorithms.Static do
  @moduledoc "Static algorithm: no movement."
  @behaviour Simulator.Algorithm

  @impl true
  def compute_step(%{position: position} = state), do: {position, state}
end
