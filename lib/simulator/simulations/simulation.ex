defmodule Simulator.Simulations.Simulation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "simulations" do
    field :type, :string
    field :algorithm, :string
    field :swarm, :integer
    field :map, :string, default: "clean"

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(simulation, attrs) do
    simulation
    |> cast(attrs, [:type, :algorithm, :swarm, :map])
    |> validate_required([:type, :algorithm, :swarm, :map])
  end
end
