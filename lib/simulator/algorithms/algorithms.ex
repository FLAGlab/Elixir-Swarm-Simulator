defmodule Simulator.Algorithms do
  @moduledoc """
  Registry of available movement algorithms.

  Maps string names to modules that implement the `Simulator.Algorithm`
  behaviour. When a name is not found, defaults to `RandomWalk`.
  """

  alias Simulator.Algorithms.{RandomWalk, Static}

  @available_algorithms %{
    "random_walk" => RandomWalk,
    "static" => Static
  }

  @doc """
  Returns the module implementing the given algorithm name.

  Falls back to `RandomWalk` when `name` is not found in `@available_algorithms`.

  ## Examples

      iex> Simulator.Algorithms.get_algorithm("random_walk")
      Simulator.Algorithms.RandomWalk

      iex> Simulator.Algorithms.get_algorithm("static")
      Simulator.Algorithms.Static

      iex> Simulator.Algorithms.get_algorithm("unknown")
      Simulator.Algorithms.RandomWalk
  """
  @spec get_algorithm(String.t()) :: module()
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
