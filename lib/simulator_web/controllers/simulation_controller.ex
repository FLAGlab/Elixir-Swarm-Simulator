defmodule SimulatorWeb.SimulationController do
  use SimulatorWeb, :controller

  alias Simulator.Simulations
  alias Simulator.Simulations.Simulation

  def index(conn, _params) do
    simulations = Simulations.list_simulations()
    changeset = Simulations.change_simulation(%Simulation{})

    render(conn, :index,
      simulations: simulations,
      changeset: changeset,
      algorithms: get_algorithms(),
      maps: get_maps(),
      objectives: get_objectives()
    )
  end

  def new(conn, _params) do
    changeset = Simulations.change_simulation(%Simulation{})

    render(conn, :new,
      changeset: changeset,
      algorithms: get_algorithms(),
      maps: get_maps(),
      objectives: get_objectives()
    )
  end

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, %{"simulation" => simulation_params}) do
    simulations = Simulations.list_simulations()

    case Simulations.create_simulation(simulation_params) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Simulation created successfully.")
        |> redirect(to: ~p"/simulations")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :index,
          simulations: simulations,
          changeset: changeset,
          algorithms: get_algorithms(),
          maps: get_maps(),
          objectives: get_objectives()
        )
    end
  end

  def show(conn, %{"id" => id}) do
    simulation = Simulations.get_simulation!(id)
    execution_runs = Simulations.list_execution_runs(simulation.id)
    render(conn, :show, simulation: simulation, execution_runs: execution_runs)
  end

  def edit(conn, %{"id" => id}) do
    simulation = Simulations.get_simulation!(id)
    changeset = Simulations.change_simulation(simulation)

    render(conn, :edit,
      simulation: simulation,
      changeset: changeset,
      algorithms: get_algorithms(),
      maps: get_maps(),
      objectives: get_objectives()
    )
  end

  def update(conn, %{"id" => id, "simulation" => simulation_params}) do
    simulation = Simulations.get_simulation!(id)

    case Simulations.update_simulation(simulation, simulation_params) do
      {:ok, simulation} ->
        conn
        |> put_flash(:info, "Simulation updated successfully.")
        |> redirect(to: ~p"/simulations/#{simulation}")

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, :edit,
          simulation: simulation,
          changeset: changeset,
          algorithms: get_algorithms(),
          maps: get_maps(),
          objectives: get_objectives()
        )
    end
  end

  def delete(conn, %{"id" => id}) do
    simulation = Simulations.get_simulation!(id)
    {:ok, _simulation} = Simulations.delete_simulation(simulation)

    conn
    |> put_flash(:info, "Simulation deleted successfully.")
    |> redirect(to: ~p"/simulations")
  end

  @batch_max 500
  @batch_default 30

  def batch(conn, %{"id" => id} = params) do
    simulation = Simulations.get_simulation!(id)
    count = parse_count(params["count"])

    cond do
      count == :invalid ->
        conn
        |> put_flash(:error, "Batch count must be a positive integer.")
        |> redirect(to: ~p"/simulations/#{simulation}")

      count > @batch_max ->
        conn
        |> put_flash(:error, "Batch count cannot exceed #{@batch_max}.")
        |> redirect(to: ~p"/simulations/#{simulation}")

      true ->
        Task.Supervisor.start_child(Simulator.TaskSupervisor, fn ->
          Simulator.ExperimentRunner.run(simulation, count)
        end)

        conn
        |> put_flash(
          :info,
          "Started a batch of #{count} runs. Refresh this page to see them appear."
        )
        |> redirect(to: ~p"/simulations/#{simulation}")
    end
  end

  defp parse_count(nil), do: @batch_default

  defp parse_count(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} when n > 0 -> n
      _ -> :invalid
    end
  end

  defp parse_count(_), do: :invalid

  defp get_algorithms do
    Simulator.Algorithms.get_available_algorithms_keys()
  end

  defp get_maps do
    Simulator.Maps.get_available_maps_keys()
  end

  defp get_objectives do
    Simulator.Objectives.get_available_objectives_keys()
  end
end
