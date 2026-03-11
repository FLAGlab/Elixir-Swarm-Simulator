defmodule Simulator.Environment.ProximityDetector do
  @moduledoc """
  GenServer that simulates line-of-sight detection between drones.

  Periodically reads agent positions from the PositionTracker, calculates
  distances between all pairs, and notifies agents when another drone enters
  or leaves their detection radius.

  The detection radius defines how far a drone can "see". This simulates
  the physical limitation of real drone sensors.
  """

  use GenServer
  require Logger

  alias Simulator.Environment.PositionTracker

  @default_detection_radius Application.compile_env(:simulator, :detection_radius, 50)
  @check_interval Application.compile_env(:simulator, :tick_interval, 30)

  # Public API -------------------------------------------------------

  @doc """
  Starts the ProximityDetector.

  ## Options
    - `:name` — process registration name (required)
    - `:tracker` — PID or name of the PositionTracker (required)
    - `:detection_radius` — how far a drone can see (default: #{@default_detection_radius})
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    config = %{
      tracker: Keyword.fetch!(opts, :tracker),
      detection_radius: Keyword.get(opts, :detection_radius, @default_detection_radius)
    }

    GenServer.start_link(__MODULE__, config, name: name)
  end

  @doc """
  Returns the set of neighbor PIDs for the given agent.

  Used by the CommunicationRelay to determine which drones should
  receive a broadcast from the sender.
  """
  def get_neighbors(proximity, agent_pid) do
    GenServer.call(proximity, {:get_neighbors, agent_pid})
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(config) do
    state = %{
      tracker: config.tracker,
      detection_radius: config.detection_radius,
      neighbors: %{}
    }

    schedule_check()
    {:ok, state}
  end

  @impl true
  def handle_info(:check_proximity, state) do
    positions = PositionTracker.get_positions_map(state.tracker)
    new_neighbors = compute_neighbors(positions, state.detection_radius)
    notify_changes(state.neighbors, new_neighbors, positions)

    schedule_check()
    {:noreply, %{state | neighbors: new_neighbors}}
  end

  @impl true
  def handle_call({:get_neighbors, agent_pid}, _from, state) do
    neighbors = Map.get(state.neighbors, agent_pid, MapSet.new())
    {:reply, neighbors, state}
  end

  # Private ----------------------------------------------------------

  defp schedule_check do
    Process.send_after(self(), :check_proximity, @check_interval)
  end

  @doc false
  def compute_neighbors(positions, radius) do
    pids = Map.keys(positions)

    Enum.reduce(pids, %{}, fn pid, acc ->
      pos = Map.fetch!(positions, pid)

      nearby =
        pids
        |> Enum.filter(fn other_pid ->
          other_pid != pid and distance(pos, Map.fetch!(positions, other_pid)) <= radius
        end)
        |> MapSet.new()

      Map.put(acc, pid, nearby)
    end)
  end

  defp notify_changes(old_neighbors, new_neighbors, positions) do
    all_pids = MapSet.new(Map.keys(new_neighbors))

    Enum.each(all_pids, fn pid ->
      old_set = Map.get(old_neighbors, pid, MapSet.new())
      new_set = Map.get(new_neighbors, pid, MapSet.new())

      entered = MapSet.difference(new_set, old_set)
      left = MapSet.difference(old_set, new_set)

      Enum.each(entered, fn neighbor_pid ->
        neighbor_pos = Map.get(positions, neighbor_pid)
        Simulator.PointAgent.notify_drone_entered(pid, neighbor_pid, neighbor_pos)
      end)

      Enum.each(left, fn neighbor_pid ->
        Simulator.PointAgent.notify_drone_left(pid, neighbor_pid)
      end)
    end)
  end

  defp distance(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
  end
end
