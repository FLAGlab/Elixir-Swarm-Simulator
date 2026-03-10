defmodule Simulator.SimulationExcutor do
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

  The process is registered with `simulation.type` as its name, so only one
  execution per type can run at a time.
  """

  use GenServer
  require Logger

  alias Simulator.Environment.PositionTracker
  alias Simulator.Environment.ProximityDetector
  alias Simulator.Environment.CommunicationRelay

  # Public API -------------------------------------------------------

  @doc """
  Returns the current positions of all agents via the PositionTracker.
  """
  def get_positions(pid) do
    GenServer.call(pid, :get_positions)
  end

  @doc """
  Starts a new simulation executor for the given `simulation` struct.

  Expects a map `%{simulation: %Simulation{}}`. The GenServer is registered
  under `String.to_atom(simulation.type)`.
  """
  def start_link(%{simulation: simulation}) do
    Logger.info("SimulationExcutor: start excution #{simulation.type}")
    initial_state = %{simulation: simulation}
    GenServer.start_link(__MODULE__, initial_state, name: String.to_atom(simulation.type))
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(state) do
    simulation = state.simulation
    Logger.info("SimulationExcutor: init excution #{simulation.type}")

    tracker_name = env_name("tracker", simulation.type)
    proximity_name = env_name("proximity", simulation.type)
    relay_name = env_name("relay", simulation.type)

    {:ok, tracker_pid} = PositionTracker.start_link(name: tracker_name)

    {:ok, proximity_pid} = ProximityDetector.start_link(
      name: proximity_name,
      tracker: tracker_name
    )

    {:ok, relay_pid} = CommunicationRelay.start_link(
      name: relay_name,
      tracker: tracker_name,
      proximity: proximity_name
    )

    agents = spawn_agents(simulation, tracker_name, relay_name)

    new_state = state
    |> Map.put(:agents, agents)
    |> Map.put(:tracker, tracker_pid)
    |> Map.put(:proximity_detector, proximity_pid)
    |> Map.put(:relay, relay_pid)

    {:ok, new_state}
  end

  @impl true
  def handle_call(:get_positions, _from, state) do
    data = PositionTracker.get_positions(state.tracker)
    {:reply, data, state}
  end

  @impl true
  def handle_info(:print, state) do
    {:noreply, state}
  end

  @impl true
  def handle_cast({:simulation_event, _payload}, state) do
    {:noreply, state}
  end

  # Private ----------------------------------------------------------

  defp spawn_agents(%{swarm: count, algorithm: algorithm, map: map}, tracker, relay) do
    for _ <- 1..count do
      {:ok, pid} = PointAgent.start_link(algorithm, map, tracker, relay)
      pid
    end
  end

  defp env_name(prefix, type), do: String.to_atom("#{prefix}_#{type}")
end
