defmodule Simulator.Repo.Migrations.CreateSimulations do
  use Ecto.Migration

  def change do
    create table(:simulations) do
      add :type, :string
      add :algorithm, :string
      add :swarm, :integer

      timestamps(type: :utc_datetime)
    end
  end
end
