defmodule Simulator.Repo.Migrations.CreateExecutionRuns do
  use Ecto.Migration

  def change do
    create table(:execution_runs) do
      add :simulation_id, references(:simulations, on_delete: :delete_all), null: false
      add :algorithm, :string
      add :map, :string
      add :objective, :string
      add :swarm_size, :integer
      add :duration_ms, :integer
      add :ticks, :integer
      add :finder_drone_id, :integer
      add :objective_position, :string
      add :status, :string

      timestamps(type: :utc_datetime)
    end

    create index(:execution_runs, [:simulation_id])
  end
end
