defmodule Simulator.SimulationManager do
  alias Simulator.SimulationExcutor
  use GenServer
  require Logger

  @default_interval 300

  def start_link(opts) do
    interval = Keyword.get(opts, :interval, @default_interval)
    initial_state = %{
      :interval => interval,
      :executions => %{}
    }
    GenServer.start_link(__MODULE__, initial_state, name: __MODULE__)
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:start_excution, %{:simulation => simulation}}, _from, state) do
    algorithm = simulation.algorithm
    Logger.info("SimulationManager: start execution #{DateTime.utc_now()} #{algorithm}")

    case Map.fetch(state.executions, simulation.id) do
      {:ok, _pid} ->
        {:reply, :already_running, state}
        Logger.info("executor not processed: already running")

      :error ->
        Logger.info("SimulationManager: starting new excutor: #{simulation.type}")
        # Start a new simulation executor
        with {:ok, pid} <- SimulationExcutor.start_link(%{simulation: simulation}) do
          new_executions = Map.put(state.executions, simulation.id, pid)
          new_state = %{state | executions: new_executions}
          {:reply, :ok, new_state}
        else
          {:error, reason} ->
            Logger.error("Failed to start simulation executor: #{reason}")
            {:reply, {:error, reason}, state}
        end
    end
  end

  @impl true
  def handle_call({:get_positions, %{:simulation => simulation}}, _from, state) do

    case Map.fetch(state.executions, simulation.id) do
      {:ok, pid} ->
        data  = SimulationExcutor.get_positions(pid)
        {:reply, data, state}
      :error ->
        Logger.info("SimulationManager: no executor found for simulation: #{simulation.type}")
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_info(:print, state) do
    Logger.info("SimulationManager: heartbeat at #{DateTime.utc_now()}")
    #schedule(interval)
    {:noreply, state}
  end

  @impl true
  # handle direct notifications (no PubSub)
  def handle_cast({:simulation_event, payload}, state) do
    Logger.info("PeriodicPrinter received simulation_event: #{inspect(payload)}")
    {:noreply, state}
  end

  defp schedule(interval) do
    Process.send_after(self(), :print, interval)
  end
end
