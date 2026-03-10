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

  # Callbacks --------------------------------------------------------

  @impl true
  def init(config) do
    {:ok, config}
  end

  @impl true
  def handle_cast({:broadcast, sender_pid, data}, state) do
    neighbors = get_sender_neighbors(sender_pid, state.proximity)

    Enum.each(neighbors, fn neighbor_pid ->
      PointAgent.receive_shared_data(neighbor_pid, sender_pid, data)
    end)

    {:noreply, state}
  end

  # Private ----------------------------------------------------------

  defp get_sender_neighbors(sender_pid, proximity) do
    proximity_state = :sys.get_state(proximity)

    Map.get(proximity_state.neighbors, sender_pid, MapSet.new())
  end
end
