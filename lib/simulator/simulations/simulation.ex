defmodule Simulator.Simulations.Simulation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "simulations" do
    field :name, :string
    field :algorithm, :string
    field :swarm, :integer
    field :map, :string, default: "clean"
    field :objective, :string, default: "static"
    field :objective_seed, :integer
    field :swarm_seed, :integer
    field :execution_count, :integer, virtual: true, default: 0

    has_many :execution_runs, Simulator.Simulations.ExecutionRun

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(simulation, attrs) do
    simulation
    |> cast(attrs, [:name, :algorithm, :swarm, :map, :objective, :objective_seed, :swarm_seed])
    |> validate_required([:name, :algorithm, :swarm, :map, :objective])
  end
end
