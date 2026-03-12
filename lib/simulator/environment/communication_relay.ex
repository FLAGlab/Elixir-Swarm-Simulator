defmodule Simulator.Environment.CommunicationRelay do
  @moduledoc """
  GenServer that simulates wireless communication between drones.

  When a drone broadcasts data, the relay checks which drones are
  currently within its detection radius (via the ProximityDetector's
  neighbor data stored in the PositionTracker) and delivers the
  message only to valid neighbors.

  This simulates the physical limitation that drones can only
  communicate with nearby drones via radio, not with the entire swarm.
  """

  use GenServer
  require Logger

  alias Simulator.Environment.ProximityDetector

  # Public API -------------------------------------------------------

  @doc """
  Starts the CommunicationRelay.

  ## Options
    - `:name` — process registration name (required)
    - `:tracker` — PID or name of the PositionTracker (required)
    - `:proximity` — PID or name of the ProximityDetector (required)
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    config = %{
      tracker: Keyword.fetch!(opts, :tracker),
      proximity: Keyword.fetch!(opts, :proximity)
    }

    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Called by a PointAgent to broadcast data to its neighbors.

  The relay determines which drones are within range and delivers
  the data only to those neighbors, simulating limited radio range.
  """
  def broadcast(relay, sender_pid, data) do
    GenServer.cast(relay, {:broadcast, sender_pid, data})
  end

  @doc """
  Blocks an agent from sending or receiving broadcasts.
  """
  def block_agent(relay, agent_pid) do
    GenServer.cast(relay, {:block_agent, agent_pid})
  end

  @doc """
  Unblocks a previously blocked agent.
  """
  def unblock_agent(relay, agent_pid) do
    GenServer.cast(relay, {:unblock_agent, agent_pid})
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(config) do
    {:ok, Map.put(config, :blocked, MapSet.new())}
  end

  @impl true
  def handle_cast({:broadcast, sender_pid, data}, state) do
    if MapSet.member?(state.blocked, sender_pid) do
      {:noreply, state}
    else
      neighbors = get_sender_neighbors(sender_pid, state.proximity)

      Enum.each(neighbors, fn neighbor_pid ->
        unless MapSet.member?(state.blocked, neighbor_pid) do
          Simulator.PointAgent.receive_shared_data(neighbor_pid, sender_pid, data)
        end
      end)

      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:block_agent, agent_pid}, state) do
    {:noreply, %{state | blocked: MapSet.put(state.blocked, agent_pid)}}
  end

  @impl true
  def handle_cast({:unblock_agent, agent_pid}, state) do
    {:noreply, %{state | blocked: MapSet.delete(state.blocked, agent_pid)}}
  end

  # Private ----------------------------------------------------------

  defp get_sender_neighbors(sender_pid, proximity) do
    ProximityDetector.get_neighbors(proximity, sender_pid)
  end
end
