defmodule Simulator.SimulationExcutor do
  use GenServer
  require Logger

  def get_positions(pid) do
    GenServer.call(pid, :get_positions)
  end

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
  def handle_cast({:simulation_event, payload}, state) do
    {:noreply, state}
  end

  def obtains_agents(%{swarm: count, algorithm: algorithm, map: map}) do
    for _ <- 1..count do
      {:ok, pid} = PointAgent.start_link(algorithm, map)
      pid
    end
  end
end
