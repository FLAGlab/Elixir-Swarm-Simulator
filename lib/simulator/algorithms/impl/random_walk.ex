defmodule Simulator.Algorithms.RandomWalk do
  @moduledoc "Random walk algorithm: moves x and y by a small random delta, avoiding obstacles."
  @behaviour Simulator.Algorithm

  alias Simulator.Algorithms.Helpers.Geometry

  @max_attempts 10

  @impl true
  def compute_step(%{position: position, map: map} = state) do
    candidate = find_valid_move(position, map, @max_attempts)
    {candidate, state}
  end

  @impl true
  def format_state(_algo_state), do: %{detail_fields: [], overlay: nil}

  # Private ----------------------------------------------------------

  defp find_valid_move(position, _map, 0), do: position

  defp find_valid_move(position, map, attempts_left) do
    candidate = %{
      x: Geometry.clamp(position.x + Enum.random(-5..5), 0, map.width),
      y: Geometry.clamp(position.y + Enum.random(-5..5), 0, map.height)
    }

    from = {position.x, position.y}
    to = {candidate.x, candidate.y}

    if Geometry.path_collides?(from, to, map.structures) do
      find_valid_move(position, map, attempts_left - 1)
    else
      candidate
    end
  end
end
