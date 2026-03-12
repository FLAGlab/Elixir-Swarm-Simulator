defmodule Simulator.Repo.Migrations.AddObjectiveToSimulations do
  use Ecto.Migration

  def change do
    alter table(:simulations) do
      add :objective, :string, default: "static"
    end
  end
end
