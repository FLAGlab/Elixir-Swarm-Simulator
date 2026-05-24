defmodule Simulator.Simulations.ExecutionRun do
  @moduledoc """
  Schema for a completed simulation execution run.

  Records the outcome of a simulation — algorithm, map, objective type,
  duration, tick count, and which drone found the objective.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Simulator.Simulations.Simulation

  schema "execution_runs" do
    belongs_to :simulation, Simulation

    field :algorithm, :string
    field :map, :string
    field :objective, :string
    field :swarm_size, :integer
    field :duration_ms, :integer
    field :ticks, :integer
    field :finder_drone_id, :integer
    field :objective_position, :string
    field :status, :string
    field :objective_seed, :integer
    field :swarm_seed, :integer

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(execution_run, attrs) do
    execution_run
    |> cast(attrs, [
      :simulation_id,
      :algorithm,
      :map,
      :objective,
      :swarm_size,
      :duration_ms,
      :ticks,
      :finder_drone_id,
      :objective_position,
      :status,
      :objective_seed,
      :swarm_seed
    ])
    |> validate_required([:simulation_id, :algorithm, :status, :objective_seed, :swarm_seed])
    |> foreign_key_constraint(:simulation_id)
  end
end
