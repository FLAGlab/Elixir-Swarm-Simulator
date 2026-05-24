defmodule Simulator.Repo.Migrations.AddSeedsToSimulations do
  use Ecto.Migration

  def change do
    alter table(:simulations) do
      add :objective_seed, :integer, null: true
      add :swarm_seed, :integer, null: true
    end
  end
end
