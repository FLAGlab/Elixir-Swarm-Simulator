defmodule Simulator.Algorithms.Static do
  @moduledoc "Static algorithm: no movement."
  @behaviour Simulator.Algorithm

  @impl true
  def compute_step(%{position: position} = state), do: {position, state}

  @impl true
  def format_state(_algo_state), do: %{detail_fields: [], overlay: nil}
end
