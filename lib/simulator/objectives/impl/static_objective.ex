defmodule Simulator.Objectives.StaticObjective do
  @moduledoc """
  Static objective — spawns at a random open position and never moves.
  """

  @behaviour Simulator.Objective

  alias Simulator.Algorithms.Helpers.Geometry

  @impl true
  def init(map_params) do
    fallback = %{x: div(map_params.width, 2), y: div(map_params.height, 2)}
    position = Geometry.random_open_point(map_params, fallback)
    {position, %{}}
  end

  @impl true
  def tick(position, state, _map_params) do
    {position, state}
  end
end
