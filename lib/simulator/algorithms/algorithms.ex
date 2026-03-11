defmodule Simulator.Algorithms do
  @moduledoc """
  Registry of available movement algorithms.

  Maps string names to modules that implement the `Simulator.Algorithm`
  behaviour. When a name is not found, defaults to `RandomWalk`.
  """

  alias Simulator.Algorithms.{AimRandomWalk, AntColony, GreyWolf, HeatmapWalk, ParticleSwarm, RandomWalk, Static}

  @available_algorithms %{
    "aim_random_walk" => AimRandomWalk,
    "ant_colony" => AntColony,
    "grey_wolf" => GreyWolf,
    "heatmap_walk" => HeatmapWalk,
    "particle_swarm" => ParticleSwarm,
    "random_walk" => RandomWalk,
    "static" => Static
  }

  @doc """
  Returns the module implementing the given algorithm.

  Accepts a string name (looked up in the registry) or a module atom
  (returned as-is). Falls back to `RandomWalk` when a string name is
  not found in `@available_algorithms`.

  ## Examples

      iex> Simulator.Algorithms.get_algorithm("random_walk")
      Simulator.Algorithms.RandomWalk

      iex> Simulator.Algorithms.get_algorithm("static")
      Simulator.Algorithms.Static

      iex> Simulator.Algorithms.get_algorithm("unknown")
      Simulator.Algorithms.RandomWalk

      iex> Simulator.Algorithms.get_algorithm(Simulator.Algorithms.Static)
      Simulator.Algorithms.Static
  """
  @spec get_algorithm(String.t() | module()) :: module()
  def get_algorithm(name) when is_atom(name), do: name

  def get_algorithm(name) do
    Map.get(@available_algorithms, name, RandomWalk)
  end

  @doc """
  Returns the list of registered algorithm name strings.
  """
  @spec get_available_algorithms_keys() :: list()
  def get_available_algorithms_keys() do
    Map.keys(@available_algorithms)
  end
end
