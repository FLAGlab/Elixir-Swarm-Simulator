defmodule Simulator.Algorithms.KnowledgeStore do
  @moduledoc """
  Utilities for managing shared knowledge between drones.

  Algorithms that communicate with neighbors need to store, decay, merge,
  and export positional knowledge received from other drones. This module
  encapsulates that logic so algorithms only deal with their own movement
  strategy.

  Knowledge is stored as a map of `%{source_pid => [positions]}`, where
  each source is the drone that originally explored those positions. This
  attribution prevents echo (receiving your own data back) and duplication
  (the same source stored under different keys).

  Each tick, every entry loses its oldest position — mirroring the natural
  decay of a drone's own rolling window. When an entry is fully consumed
  it is removed automatically.
  """

  # Public API ---------------------------------------------------------

  @doc """
  Removes the oldest position from each received entry.

  Entries that become empty are discarded. Call this once per tick before
  using the knowledge for decisions.
  """
  @spec decay(map()) :: map()
  def decay(received_visited) when received_visited == %{}, do: %{}

  def decay(received_visited) do
    received_visited
    |> Map.new(fn {key, positions} -> {key, List.delete_at(positions, -1)} end)
    |> Enum.reject(fn {_key, positions} -> positions == [] end)
    |> Map.new()
  end

  @doc """
  Merges incoming knowledge into the existing received store.

  Filters out the drone's own PID to prevent echo. For each source,
  keeps the longer (fresher) list between incoming and existing data.
  """
  @spec merge(map(), map()) :: map()
  def merge(received_visited, incoming_knowledge) do
    self_pid = self()

    incoming =
      incoming_knowledge
      |> Map.delete(self_pid)
      |> Map.new(fn {source, positions} ->
        existing = Map.get(received_visited, source, [])

        if length(positions) >= length(existing) do
          {source, positions}
        else
          {source, existing}
        end
      end)

    Map.merge(received_visited, incoming)
  end

  @doc """
  Combines own visited positions with all received knowledge into a flat list.
  """
  @spec all_positions(list(), map()) :: list()
  def all_positions(visited, received_visited) when received_visited == %{}, do: visited

  def all_positions(visited, received_visited) do
    neighbor_positions =
      received_visited
      |> Map.values()
      |> List.flatten()

    visited ++ neighbor_positions
  end

  @doc """
  Builds the knowledge map for broadcasting to neighbors.

  Includes the drone's own visited positions (keyed by its PID) merged
  with all received knowledge, so the data propagates transitively.
  """
  @spec build_shareable(list(), map()) :: map()
  def build_shareable(visited, received_visited) do
    own_entry = %{self() => visited}
    Map.merge(received_visited, own_entry)
  end

  @doc """
  Combines own and received positions into a single `visited` list for
  external consumption and removes internal keys.

  Used by `format_state/1` to prepare algorithm state for the detail panel.
  """
  @spec format_for_export(map()) :: map()
  def format_for_export(algo_state) do
    own = Map.get(algo_state, :visited, [])
    received = Map.get(algo_state, :received_visited, %{})

    algo_state
    |> Map.put(:visited, all_positions(own, received))
    |> Map.delete(:received_visited)
  end
end
