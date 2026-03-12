defmodule Simulator.Objectives do
  @moduledoc """
  Registry of available objective types.

  Maps string names to modules that implement the `Simulator.Objective`
  behaviour. `"none"` returns `nil` (no objective in the simulation).
  """

  alias Simulator.Objectives.{StaticObjective, AimRandomWalkObjective}

  @available_objectives %{
    "static" => StaticObjective,
    "aim_random_walk" => AimRandomWalkObjective
  }

  @doc """
  Returns the module for the given objective name, or `nil` for `"none"`.
  """
  @spec get_objective(String.t()) :: module() | nil
  def get_objective("none"), do: nil

  def get_objective(name) do
    Map.get(@available_objectives, name)
  end

  @doc """
  Returns the list of registered objective name strings including `"none"`.
  """
  @spec get_available_objectives_keys() :: [String.t()]
  def get_available_objectives_keys do
    ["none" | Map.keys(@available_objectives)]
  end
end
