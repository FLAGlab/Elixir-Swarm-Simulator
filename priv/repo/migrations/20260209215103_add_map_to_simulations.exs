defmodule Simulator.Repo.Migrations.AddMapToSimulations do
  use Ecto.Migration

  def change do
    alter table(:simulations) do
      add :map, :string, default: "clean"
    end
  end
end
