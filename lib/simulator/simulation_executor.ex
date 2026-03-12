defmodule Simulator.SimulationExecutor do
  @moduledoc """
  GenServer that orchestrates the simulation environment.

  On initialization it starts the environment modules (PositionTracker,
  ProximityDetector, CommunicationRelay) and spawns N `PointAgent` processes.
  The Executor does not control drone behavior — it simulates the physical
  world around them.

  The environment modules handle:
  - **PositionTracker**: stores positions broadcast by agents
  - **ProximityDetector**: detects when drones enter/leave each other's range
  - **CommunicationRelay**: delivers shared data between neighboring drones
  - **ObjectiveServer**: manages the objective entity and detects when a drone finds it

  The process is registered with `simulation.name` as its name, so only one
  execution per type can run at a time.
  """

  use GenServer
  require Logger

  alias Simulator.Environment.PositionTracker
  alias Simulator.Environment.ProximityDetector
  alias Simulator.Environment.CommunicationRelay
  alias Simulator.Environment.ObjectiveServer
  alias Simulator.Maps

  # Public API -------------------------------------------------------

  @doc """
  Returns the current positions of all agents via the PositionTracker.
  """
  def get_positions(pid) do
    GenServer.call(pid, :get_positions)
  end

  @doc """
  Returns the detail summary of a specific agent by its numeric ID.
  """
  def get_agent_detail(pid, agent_id) do
    GenServer.call(pid, {:get_agent_detail, agent_id})
  end

  @doc """
  Toggles the connection state of a drone.

  When `connected` is `false`, the environment stops tracking the drone's
  position and relaying its communications — but the drone keeps running
  unaware of the disconnection. When `true`, the environment resumes
  normal tracking.
  """
  def toggle_drone_connection(pid, agent_id, connected) do
    GenServer.call(pid, {:toggle_drone_connection, agent_id, connected})
  end

  @doc """
  Stops the executor and all its child processes (agents, environment modules).
  """
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  @doc """
  Starts a new simulation executor for the given `simulation` struct.

  Expects a map `%{simulation: %Simulation{}}`. The GenServer is registered
  under `String.to_atom(simulation.name)`.
  """
  def start_link(%{simulation: simulation}) do
    Logger.info("SimulationExecutor: start excution #{simulation.name}")
    initial_state = %{simulation: simulation}
    GenServer.start_link(__MODULE__, initial_state, name: String.to_atom(simulation.name))
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(state) do
    simulation = state.simulation
    Logger.info("SimulationExecutor: init excution #{simulation.name}")

    tracker_name = env_name("tracker", simulation.name)
    proximity_name = env_name("proximity", simulation.name)
    relay_name = env_name("relay", simulation.name)

    {:ok, tracker_pid} = PositionTracker.start_link(name: tracker_name)

    {:ok, proximity_pid} =
      ProximityDetector.start_link(
        name: proximity_name,
        tracker: tracker_name
      )

    {:ok, relay_pid} =
      CommunicationRelay.start_link(
        name: relay_name,
        tracker: tracker_name,
        proximity: proximity_name
      )

    agents = spawn_agents(simulation, tracker_name, relay_name)

    objective_server = start_objective_server(simulation, tracker_name)

    new_state =
      state
      |> Map.put(:agents, agents)
      |> Map.put(:tracker, tracker_pid)
      |> Map.put(:proximity_detector, proximity_pid)
      |> Map.put(:relay, relay_pid)
      |> Map.put(:objective_server, objective_server)
      |> Map.put(:start_time, System.monotonic_time(:millisecond))
      |> Map.put(:tick_count, 0)

    {:ok, new_state}
  end

  @impl true
  def handle_call(:get_positions, _from, state) do
    data = PositionTracker.get_positions(state.tracker)
    new_tick_count = state.tick_count + 1

    response =
      case state.objective_server do
        nil -> data
        pid -> Map.put(data, :objective, ObjectiveServer.get_position(pid))
      end

    {:reply, response, %{state | tick_count: new_tick_count}}
  end

  @impl true
  def handle_call({:get_agent_detail, agent_id}, _from, state) do
    case Map.fetch(state.agents, agent_id) do
      {:ok, %{pid: agent_pid, disconnected: disconnected}} ->
        detail = Simulator.PointAgent.get_detail(agent_pid)
        detail_with_status = Map.put(detail, :disconnected, disconnected)
        {:reply, {:ok, detail_with_status}, state}

      :error ->
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_call({:toggle_drone_connection, agent_id, connected}, _from, state) do
    case Map.fetch(state.agents, agent_id) do
      {:ok, %{pid: agent_pid} = agent} ->
        disconnect = not connected

        if disconnect do
          PositionTracker.block_agent(state.tracker, agent_pid)
          CommunicationRelay.block_agent(state.relay, agent_pid)
        else
          PositionTracker.unblock_agent(state.tracker, agent_pid)
          CommunicationRelay.unblock_agent(state.relay, agent_pid)
        end

        updated_agent = %{agent | disconnected: disconnect}
        new_agents = Map.put(state.agents, agent_id, updated_agent)
        {:reply, :ok, %{state | agents: new_agents}}

      :error ->
        {:reply, :not_found, state}
    end
  end

  @impl true
  def handle_info({:objective_found, drone_id, objective_position}, state) do
    simulation = state.simulation
    duration_ms = System.monotonic_time(:millisecond) - state.start_time

    Logger.info(
      "SimulationExecutor: objective found by drone #{drone_id} after #{duration_ms}ms (#{state.tick_count} ticks)"
    )

    # Notify all drones about the objective being found
    Enum.each(state.agents, fn {_id, %{pid: pid}} ->
      Simulator.PointAgent.receive_shared_data(pid, :environment, %{
        type: :objective_found,
        position: objective_position
      })
    end)

    stats = %{
      simulation_id: simulation.id,
      algorithm: simulation.algorithm,
      map: simulation.map,
      objective: simulation.objective,
      swarm_size: simulation.swarm,
      duration_ms: duration_ms,
      ticks: state.tick_count,
      finder_drone_id: drone_id,
      objective_position: Jason.encode!(objective_position),
      status: "completed"
    }

    GenServer.cast(Simulator.SimulationManager, {:execution_complete, simulation.id, stats})
    {:noreply, state}
  end

  @impl true
  def handle_info(:print, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:simulation_event, _payload}, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(Map.get(state, :agents, %{}), fn {_id, %{pid: pid}} ->
      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end)

    for key <- [:tracker, :proximity_detector, :relay] do
      pid = Map.get(state, key)
      if pid && Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end

    objective_pid = Map.get(state, :objective_server)
    if objective_pid && Process.alive?(objective_pid), do: GenServer.stop(objective_pid, :normal)

    :ok
  end

  # Private ----------------------------------------------------------

  defp spawn_agents(%{swarm: count, algorithm: algorithm, map: map}, tracker, relay) do
    for id <- 1..count, into: %{} do
      {:ok, pid} = Simulator.PointAgent.start_link(algorithm, map, tracker, relay, id)
      {id, %{pid: pid, disconnected: false}}
    end
  end

  defp start_objective_server(simulation, tracker_name) do
    case Simulator.Objectives.get_objective(simulation.objective) do
      nil ->
        nil

      objective_module ->
        map_params = Maps.get_map(simulation.map).get_parameters()

        {:ok, pid} =
          ObjectiveServer.start_link(
            objective_module: objective_module,
            map_params: map_params,
            tracker: tracker_name,
            executor: self()
          )

        pid
    end
  end

  defp env_name(prefix, type), do: String.to_atom("#{prefix}_#{type}")
end
