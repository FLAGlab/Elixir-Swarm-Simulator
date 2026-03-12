defmodule Simulator.Objective do
  @moduledoc """
  Behaviour for simulation objectives.

  An objective is an entity in the simulation world that drones must find.
  Objectives have pluggable behaviors — they can be static or move around.

  - `init/1` — generates the initial position and internal state
  - `tick/3` — updates the objective position each tick (static objectives return unchanged)
  """

  @doc """
  Initializes the objective. Returns `{position, internal_state}`.

  `map_params` is the full map parameters struct with dimensions and structures.
  """
  @callback init(map_params :: map()) :: {%{x: number(), y: number()}, map()}

  @doc """
  Advances the objective by one tick. Returns `{new_position, new_state}`.
  """
  @callback tick(%{x: number(), y: number()}, state :: map(), map_params :: map()) ::
              {%{x: number(), y: number()}, map()}
end
