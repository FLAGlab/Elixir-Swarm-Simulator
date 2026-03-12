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

  @doc """
  Blocks an agent from updating its position.

  While blocked, `report_position` calls from this agent are silently ignored.
  The current position is preserved with a `disconnected: true` flag so other
  modules (ProximityDetector) can filter it out.
  """
  def block_agent(tracker_pid, agent_pid) do
    GenServer.cast(tracker_pid, {:block_agent, agent_pid})
  end

  @doc """
  Unblocks a previously blocked agent, allowing position updates again.

  Removes the `disconnected` flag from the stored position. The agent's next
  `report_position` call will overwrite it naturally.
  """
  def unblock_agent(tracker_pid, agent_pid) do
    GenServer.cast(tracker_pid, {:unblock_agent, agent_pid})
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(_opts) do
    {:ok, %{positions: %{}, blocked: MapSet.new()}}
  end

  @impl true
  def handle_cast({:position_update, agent_pid, position}, state) do
    if MapSet.member?(state.blocked, agent_pid) do
      {:noreply, state}
    else
      new_positions = Map.put(state.positions, agent_pid, position)
      {:noreply, %{state | positions: new_positions}}
    end
  end

  @impl true
  def handle_cast({:block_agent, agent_pid}, state) do
    new_blocked = MapSet.put(state.blocked, agent_pid)

    new_positions =
      case Map.fetch(state.positions, agent_pid) do
        {:ok, pos} -> Map.put(state.positions, agent_pid, Map.put(pos, :disconnected, true))
        :error -> state.positions
      end

    {:noreply, %{state | blocked: new_blocked, positions: new_positions}}
  end

  @impl true
  def handle_cast({:unblock_agent, agent_pid}, state) do
    new_blocked = MapSet.delete(state.blocked, agent_pid)

    new_positions =
      case Map.fetch(state.positions, agent_pid) do
        {:ok, pos} -> Map.put(state.positions, agent_pid, Map.delete(pos, :disconnected))
        :error -> state.positions
      end

    {:noreply, %{state | blocked: new_blocked, positions: new_positions}}
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
