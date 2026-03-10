defmodule Simulator.Environment.PositionTracker do
  @moduledoc """
  GenServer that tracks the real-time positions of all agents in a simulation.

  Agents broadcast their position after each movement tick via `report_position/3`.
  The tracker stores these positions and serves them to other environment modules
  (ProximityDetector) and to the visualization layer via `get_positions/1`.
  """

  use GenServer
  require Logger

  # Public API -------------------------------------------------------

  @doc """
  Starts the PositionTracker for a simulation.

  Expects a map with `:name` to register the process.
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @doc """
  Called by a PointAgent to report its current position.

  This simulates the drone broadcasting its location to the environment.
  """
  def report_position(tracker_pid, agent_pid, position) do
    GenServer.cast(tracker_pid, {:position_update, agent_pid, position})
  end

  @doc """
  Returns all tracked positions as a list of `%{x, y}`.
  """
  def get_positions(tracker_pid) do
    GenServer.call(tracker_pid, :get_positions)
  end

  @doc """
  Returns all tracked positions as a map of `agent_pid => %{x, y}`.
  """
  def get_positions_map(tracker_pid) do
    GenServer.call(tracker_pid, :get_positions_map)
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(_opts) do
    {:ok, %{positions: %{}}}
  end

  @impl true
  def handle_cast({:position_update, agent_pid, position}, state) do
    new_positions = Map.put(state.positions, agent_pid, position)
    {:noreply, %{state | positions: new_positions}}
  end

  @impl true
  def handle_call(:get_positions, _from, state) do
    positions = Map.values(state.positions)
    {:reply, %{positions: positions}, state}
  end

  @impl true
  def handle_call(:get_positions_map, _from, state) do
    {:reply, state.positions, state}
  end
end
