defmodule Simulator.SimulationExcutor do
  @moduledoc """
  GenServer that manages a single simulation execution.

  On initialization it spawns N `PointAgent` processes (where N is
  `simulation.swarm`) and keeps their PIDs. Provides a synchronous
  `get_positions/1` call to aggregate the current position of every agent.

  The process is registered with `simulation.type` as its name, so only one
  execution per type can run at a time.
  """

  use GenServer
  require Logger

  @doc """
  Returns the current positions of all agents in the execution identified by `pid`.

  Performs a synchronous `GenServer.call` with `:get_positions` and returns
  `%{positions: [%{x, y}, ...]}`.
  """
  def get_positions(pid) do
    GenServer.call(pid, :get_positions)
  end

  @doc """
  Starts a new simulation executor for the given `simulation` struct.

  Expects a map `%{simulation: %Simulation{}}`. The GenServer is registered
  under `String.to_atom(simulation.type)`.

  Returns `{:ok, pid}` on success.
  """
  def start_link(%{:simulation => simulation}) do
    Logger.info("SimulationExcutor: start excution #{simulation.type}")
    initial_state = %{
      :simulation => simulation
    }
    GenServer.start_link(__MODULE__, initial_state, name: String.to_atom(simulation.type))
  end

  @impl true
  def init(state) do
    simulation = state.simulation
    Logger.info("SimulationExcutor: init excution #{simulation.type}")

    new_state = state
    |> Map.put(:agents, obtains_agents(state.simulation))

    {:ok, new_state}
  end

  @impl true
  def handle_call(:get_positions, _from, state) do
    positions = state.agents
    |> Enum.map(fn agent_pid ->
      PointAgent.get_position(agent_pid)
    end)

    data = %{
      :positions => positions
    }
    {:reply, data, state}
  end

  @impl true
  def handle_info(:print, state) do
    {:noreply, state}
  end

  @impl true
  # handle direct notifications (no PubSub)
  def handle_cast({:simulation_event, _payload}, state) do
    {:noreply, state}
  end

  @doc """
  Spawns `count` `PointAgent` processes using the given `algorithm` and `map`
  names and returns a list of their PIDs.
  """
  def obtains_agents(%{swarm: count, algorithm: algorithm, map: map}) do
    for _ <- 1..count do
      {:ok, pid} = PointAgent.start_link(algorithm, map)
      pid
    end
  end
end
