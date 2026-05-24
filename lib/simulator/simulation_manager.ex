defmodule Simulator.SimulationManager do
  @moduledoc """
  GenServer that tracks multiple running simulation executions.

  Maintains a map of `simulation.id => executor_pid` in its state. Prevents
  duplicate executions for the same simulation ID — if an execution is already
  running, `{:start_execution, ...}` replies with `:already_running`.

  Started as a named singleton (`__MODULE__`) in the application supervision tree.
  Accepts an optional `:interval` option (defaults to `@default_interval`).
  """

  alias Simulator.SimulationExecutor
  alias Simulator.Simulations
  use GenServer
  require Logger

  @default_interval 300

  @doc """
  Starts the SimulationManager GenServer.

  Accepts a keyword list with an optional `:interval` key
  (defaults to `@default_interval`). Registered as a named process under
  `Simulator.SimulationManager`.
  """
  def start_link(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)

    initial_state = %{
      interval: interval,
      executions: %{},
      completions: %{}
    }

    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @doc """
  Starts an execution for the given simulation.

  Returns `:ok` if the execution started, `:already_running` if one is
  already running for that simulation ID, or `{:error, reason}` if the
  executor failed to start.
  """
  def start_execution(%Simulator.Simulations.Simulation{} = simulation) do
    GenServer.call(__MODULE__, {:start_execution, %{simulation: simulation}})
  end

  @doc """
  Stops the execution for the given simulation, freeing all resources.

  Returns `:ok` if the execution was stopped, `:not_found` if no execution
  was running for that simulation ID.
  """
  def stop_execution(simulation_id) do
    GenServer.call(__MODULE__, {:stop_execution, simulation_id})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:start_execution, %{simulation: simulation}}, _from, state) do
    Logger.info(
      "SimulationManager: start execution #{DateTime.utc_now()} #{simulation.algorithm}"
    )

    case Map.fetch(state.executions, simulation.id) do
      {:ok, _pid} ->
        Logger.info("SimulationManager: execution already running for #{simulation.name}")
        {:reply, :already_running, state}

      :error ->
        Logger.info("SimulationManager: starting new executor: #{simulation.name}")

        with {:ok, pid} <- SimulationExecutor.start_link(%{simulation: simulation}) do
          new_executions = Map.put(state.executions, simulation.id, pid)
          new_completions = Map.delete(state.completions, simulation.id)

          {:reply, :ok, %{state | executions: new_executions, completions: new_completions}}
        else
          {:error, reason} ->
            Logger.error("Failed to start simulation executor: #{reason}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:stop_execution, simulation_id}, _from, state) do
    case Map.fetch(state.executions, simulation_id) do
      {:ok, pid} ->
        SimulationExecutor.stop(pid)
        new_executions = Map.delete(state.executions, simulation_id)
        new_completions = Map.delete(state.completions, simulation_id)
        Logger.info("SimulationManager: stopped execution #{simulation_id}")

        {:reply, :ok, %{state | executions: new_executions, completions: new_completions}}

      :error ->
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_call({:get_positions, %{simulation: simulation}}, _from, state) do
    case Map.fetch(state.executions, simulation.id) do
      {:ok, pid} ->
        data = SimulationExecutor.get_positions(pid)
        {:reply, data, state}

      :error ->
        case Map.fetch(state.completions, simulation.id) do
          {:ok, completion} ->
            {:reply, Map.put(completion, :completed, true), state}

          :error ->
            Logger.info("SimulationManager: no executor found for simulation: #{simulation.name}")
            {:reply, :not_found, state}
        end
    end
  end

  @impl true
  def handle_call(
        {:get_agent_detail, %{simulation: simulation, agent_id: agent_id}},
        _from,
        state
      ) do
    case Map.fetch(state.executions, simulation.id) do
      {:ok, pid} ->
        result = SimulationExecutor.get_agent_detail(pid, agent_id)
        {:reply, result, state}

      :error ->
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_call(
        {:toggle_drone_connection,
         %{simulation: simulation, agent_id: agent_id, connected: connected}},
        _from,
        state
      ) do
    case Map.fetch(state.executions, simulation.id) do
      {:ok, pid} ->
        result = SimulationExecutor.toggle_drone_connection(pid, agent_id, connected)
        {:reply, result, state}

      :error ->
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_cast({:execution_complete, simulation_id, stats}, state) do
    Logger.info("SimulationManager: execution complete for simulation #{simulation_id}")

    new_completions =
      case Simulations.create_execution_run(stats) do
        {:ok, run} ->
          Map.put(state.completions, simulation_id, %{
            execution_run_id: run.id,
            stats: stats
          })

        {:error, changeset} ->
          Logger.error(
            "SimulationManager: failed to save execution run: #{inspect(changeset.errors)}"
          )

          state.completions
      end

    case Map.fetch(state.executions, simulation_id) do
      {:ok, pid} ->
        SimulationExecutor.stop(pid)
        new_executions = Map.delete(state.executions, simulation_id)

        {:noreply, %{state | executions: new_executions, completions: new_completions}}

      :error ->
        {:noreply, %{state | completions: new_completions}}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_executions =
      state.executions
      |> Enum.reject(fn {_id, executor_pid} -> executor_pid == pid end)
      |> Map.new()

    {:noreply, %{state | executions: new_executions}}
  end

  @impl true
  def handle_info(:print, state) do
    Logger.info("SimulationManager: heartbeat at #{DateTime.utc_now()}")
    {:noreply, state}
  end
end
