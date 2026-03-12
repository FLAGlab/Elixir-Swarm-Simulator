defmodule Simulator.Simulations do
  @moduledoc """
  The Simulations context.
  """

  import Ecto.Query, warn: false
  alias Simulator.Repo

  alias Simulator.Simulations.Simulation
  alias Simulator.Simulations.ExecutionRun

  @doc """
  Returns the list of simulations.

  ## Examples

      iex> list_simulations()
      [%Simulation{}, ...]

  """
  def list_simulations do
    from(s in Simulation,
      left_join: r in assoc(s, :execution_runs),
      group_by: s.id,
      select_merge: %{execution_count: count(r.id)},
      order_by: [desc: s.id]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single simulation.

  Raises `Ecto.NoResultsError` if the Simulation does not exist.

  ## Examples

      iex> get_simulation!(123)
      %Simulation{}

      iex> get_simulation!(456)
      ** (Ecto.NoResultsError)

  """
  def get_simulation!(id), do: Repo.get!(Simulation, id)

  @doc """
  Creates a simulation.

  ## Examples

      iex> create_simulation(%{field: value})
      {:ok, %Simulation{}}

      iex> create_simulation(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_simulation(attrs) do
    %Simulation{}
    |> Simulation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a simulation.

  ## Examples

      iex> update_simulation(simulation, %{field: new_value})
      {:ok, %Simulation{}}

      iex> update_simulation(simulation, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_simulation(%Simulation{} = simulation, attrs) do
    simulation
    |> Simulation.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a simulation.

  ## Examples

      iex> delete_simulation(simulation)
      {:ok, %Simulation{}}

      iex> delete_simulation(simulation)
      {:error, %Ecto.Changeset{}}

  """
  def delete_simulation(%Simulation{} = simulation) do
    Repo.delete(simulation)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking simulation changes.

  ## Examples

      iex> change_simulation(simulation)
      %Ecto.Changeset{data: %Simulation{}}

  """
  def change_simulation(%Simulation{} = simulation, attrs \\ %{}) do
    Simulation.changeset(simulation, attrs)
  end

  # Execution Runs ---------------------------------------------------

  @doc """
  Creates an execution run record.
  """
  def create_execution_run(attrs) do
    %ExecutionRun{}
    |> ExecutionRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns all execution runs for a given simulation ID.
  """
  def list_execution_runs(simulation_id) do
    from(r in ExecutionRun, where: r.simulation_id == ^simulation_id, order_by: [desc: r.id])
    |> Repo.all()
  end

  @doc """
  Gets a single execution run. Raises if not found.
  """
  def get_execution_run!(id), do: Repo.get!(ExecutionRun, id)
end
