defmodule Simulator.PointAgent do
  @moduledoc """
  GenServer modeling an autonomous drone.

  Each agent operates with local information only — its position, the static map,
  its neighbors (detected by the environment), and data received from other drones.
  It cannot access global state directly, just as a real drone is limited to its
  own sensors and communications.

  On each tick the drone:
  1. Calls the algorithm to decide its next movement
  2. Broadcasts its new position to the PositionTracker
  3. Broadcasts shared data (defined by the algorithm) to the CommunicationRelay

  The environment modules handle the rest:
  - ProximityDetector notifies when drones enter/leave detection radius
  - CommunicationRelay delivers shared data only to valid neighbors
  """

  use GenServer
  require Logger

  alias Simulator.Algorithm
  alias Simulator.Algorithms
  alias Simulator.Maps
  alias Simulator.Environment.PositionTracker
  alias Simulator.Environment.CommunicationRelay

  @update_interval Application.compile_env(:simulator, :tick_interval, 30)

  # Public API -------------------------------------------------------

  @doc """
  Starts a new agent.

  Takes three arguments grouped by category:

    - `config` — agent behavior parameters: `%{algorithm, map, swarm_seed}`.
      `:swarm_seed` is optional; when set, the agent process seeds its
      `:rand` state on init, making algorithm decisions reproducible
      across runs that share the same `(swarm_seed, id)` pair.
    - `env` — messaging targets: `%{tracker, relay}`. The PositionTracker
      where the agent reports its position and the CommunicationRelay
      where it broadcasts shared data.
    - `id` — numeric drone identifier.
  """
  def start_link(config, env, id) do
    GenServer.start_link(__MODULE__, %{config: config, env: env, id: id})
  end

  @doc """
  Returns the current `%{x, y}` position of the agent.
  """
  def get_position(pid), do: GenServer.call(pid, :get_position)

  @doc """
  Returns a detail summary of the agent's current state.

  Includes id, position, color, neighbor count, and any algorithm-specific
  keys (e.g. `:target` for AimRandomWalk).
  """
  def get_detail(pid), do: GenServer.call(pid, :get_detail)

  @doc """
  Notifies the agent that another drone entered its detection radius.

  Called by the environment (ProximityDetector) to simulate sensor detection.
  """
  def notify_drone_entered(pid, neighbor_pid, neighbor_position) do
    GenServer.cast(pid, {:drone_entered, neighbor_pid, neighbor_position})
  end

  @doc """
  Notifies the agent that another drone left its detection radius.

  Called by the environment (ProximityDetector) when a previously visible
  drone is no longer in range.
  """
  def notify_drone_left(pid, neighbor_pid) do
    GenServer.cast(pid, {:drone_left, neighbor_pid})
  end

  @doc """
  Delivers shared data from a neighboring drone.

  Called by the CommunicationRelay when a neighbor broadcasts data.
  The agent delegates processing to its algorithm's `handle_received_data/3`.
  """
  def receive_shared_data(pid, sender_pid, data) do
    GenServer.cast(pid, {:received_data, sender_pid, data})
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(%{config: config, env: env, id: id}) do
    seed_rand(Map.get(config, :swarm_seed), id)

    algorithm = resolve_algorithm(Map.fetch!(config, :algorithm))
    map = resolve_map(Map.fetch!(config, :map))

    state = %{
      id: id,
      position: map.spawn_point,
      algorithm: algorithm,
      map: map,
      neighbors: %{},
      tracker: Map.fetch!(env, :tracker),
      relay: Map.fetch!(env, :relay),
      pending_received: []
    }

    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.position, state}
  end

  @impl true
  def handle_call(:get_detail, _from, state) do
    color = if map_size(state.neighbors) > 0, do: "neighbor", else: "alone"

    detail = %{
      id: state.id,
      position: state.position,
      color: color,
      neighbors_count: map_size(state.neighbors),
      algorithm_state: extract_algorithm_state(state)
    }

    {:reply, detail, state}
  end

  @impl true
  def handle_cast({:drone_entered, neighbor_pid, neighbor_position}, state) do
    new_neighbors = Map.put(state.neighbors, neighbor_pid, neighbor_position)
    {:noreply, %{state | neighbors: new_neighbors}}
  end

  @impl true
  def handle_cast({:drone_left, neighbor_pid}, state) do
    new_neighbors = Map.delete(state.neighbors, neighbor_pid)
    {:noreply, %{state | neighbors: new_neighbors}}
  end

  @impl true
  def handle_cast({:received_data, sender_pid, data}, state) do
    # Buffer the message instead of applying it immediately. The tick
    # handler drains the buffer in deterministic order (sorted by
    # sender) before computing the next step, so two runs that share
    # the same `(swarm_seed, id)` see the same input sequence even when
    # the BEAM delivers casts in a different order.
    new_pending = [{sender_pid, data} | state.pending_received]
    {:noreply, %{state | pending_received: new_pending}}
  end

  @impl true
  def handle_info(:tick, state) do
    state_with_messages = flush_pending(state)

    {new_position, updated_state} =
      state_with_messages.algorithm.compute_step(state_with_messages)

    new_state = %{updated_state | position: new_position}

    color = if map_size(new_state.neighbors) > 0, do: "neighbor", else: "alone"

    report_data =
      new_position
      |> Map.put(:color, color)
      |> Map.put(:id, new_state.id)

    PositionTracker.report_position(state.tracker, self(), report_data)

    shared_data = Algorithm.shared_data(state.algorithm, new_state)

    if shared_data != %{} do
      CommunicationRelay.broadcast(state.relay, self(), shared_data)
    end

    schedule_tick()
    {:noreply, new_state}
  end

  # Private ----------------------------------------------------------

  defp seed_rand(nil, _id), do: :ok

  defp seed_rand(swarm_seed, id) when is_integer(swarm_seed) and is_integer(id) do
    :rand.seed(:exsss, {swarm_seed, id, 0})
    :ok
  end

  defp flush_pending(%{pending_received: []} = state), do: state

  defp flush_pending(state) do
    sorted =
      state.pending_received
      |> Enum.reverse()
      |> Enum.sort_by(fn {sender, _data} -> sender end)

    drained =
      Enum.reduce(sorted, state, fn {sender, data}, acc ->
        Algorithm.receive_data(acc.algorithm, sender, data, acc)
      end)

    %{drained | pending_received: []}
  end

  @system_keys [:id, :position, :algorithm, :map, :neighbors, :tracker, :relay, :pending_received]

  defp extract_algorithm_state(state) do
    algo_state = Map.drop(state, @system_keys)
    Algorithm.format_state(state.algorithm, algo_state)
  end

  defp resolve_algorithm(name) do
    algorithm = Algorithms.get_algorithm(name)

    if is_binary(name) and algorithm == Simulator.Algorithms.RandomWalk and name != "random_walk" do
      Logger.warning("PointAgent: unknown algorithm #{inspect(name)}, falling back to RandomWalk")
    end

    algorithm
  end

  defp resolve_map(name) do
    map_module = Maps.get_map(name)

    if map_module == Simulator.Maps.CleanMap and name != "clean" do
      Logger.warning("PointAgent: unknown map #{inspect(name)}, falling back to CleanMap")
    end

    map_module.get_parameters()
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @update_interval)
  end
end
