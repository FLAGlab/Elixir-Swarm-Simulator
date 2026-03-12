defmodule Simulator.Objectives.AimRandomWalkObjective do
  @moduledoc """
  Moving objective — picks a random target and walks toward it.

  Uses the same movement logic as the `AimRandomWalk` algorithm:
  step toward target, pick a new target on arrival or collision.
  """

  @behaviour Simulator.Objective

  alias Simulator.Algorithms.Helpers.Geometry

  @step_size 3
  @arrival_threshold 3

  @impl true
  def init(map_params) do
    fallback = %{x: div(map_params.width, 2), y: div(map_params.height, 2)}
    position = Geometry.random_open_point(map_params, fallback)
    target = Geometry.random_open_point(map_params, position)
    {position, %{target: target}}
  end

  @impl true
  def tick(position, state, map_params) do
    target = state.target

    if Geometry.euclidean_distance(position, target) <= @arrival_threshold do
      new_target = Geometry.random_open_point(map_params, position)
      {position, %{state | target: new_target}}
    else
      candidate = Geometry.step_toward(position, target, map_params, @step_size)
      from = {position.x, position.y}
      to = {candidate.x, candidate.y}

      if Geometry.path_collides?(from, to, map_params.structures) do
        new_target = Geometry.random_open_point(map_params, position)
        {position, %{state | target: new_target}}
      else
        {candidate, state}
      end
    end
  end
end
