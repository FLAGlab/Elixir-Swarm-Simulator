defmodule Simulator.Repo.Migrations.AddSeedsToExecutionRuns do
  use Ecto.Migration

  def change do
    alter table(:execution_runs) do
      add :objective_seed, :integer
      add :swarm_seed, :integer
    end
  end
end
