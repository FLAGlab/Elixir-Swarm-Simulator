defmodule Simulator.Algorithms do
  @moduledoc """
  Module grouping all available movement algorithms.
  """

  alias Simulator.Algorithms.{RandomWalk, Static}

  @available_algorithms %{
    "random_walk" => RandomWalk,
    "static" => Static
  }

  @doc """
  Returns the module implementing the given algorithm name.

  ## Examples

      iex> Simulator.Algorithms.get_algorithm("random_walk")
      Simulator.Algorithms.RandomWalk

      iex> Simulator.Algorithms.get_algorithm("static")
      Simulator.Algorithms.Static

      iex> Simulator.Algorithms.get_algorithm("unknown")
      nil
  """
  @spec get_algorithm(String.t()) :: module() | nil
  def get_algorithm(name) do
    Map.get(@available_algorithms, name, RandomWalk)
  end

  @spec get_available_algorithms_keys() :: list()
  def get_available_algorithms_keys() do
    Map.keys(@available_algorithms)
  end
end
