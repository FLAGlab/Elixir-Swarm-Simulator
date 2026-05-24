defmodule Simulator.Environment.ObjectiveServer do
  @moduledoc """
  GenServer that manages a simulation objective entity.

  On each tick the server:
  1. Moves the objective via `objective_module.tick/3`
  2. Reads drone positions from the PositionTracker
  3. Checks if any connected drone is within detection radius
  4. If found, notifies the Executor via `{:objective_found, drone_id, position}`
     and stops ticking
  """

  use GenServer
  require Logger

  alias Simulator.Environment.PositionTracker
  alias Simulator.Algorithms.Helpers.Geometry

  @tick_interval Application.compile_env(:simulator, :tick_interval, 30)
  @detection_radius 25

  # Public API -------------------------------------------------------

  @doc """
  Starts the ObjectiveServer.

  ## Options
    - `:objective_module` — module implementing `Simulator.Objective` (required)
    - `:map_params` — map parameters struct (required)
    - `:tracker` — PositionTracker PID or name (required)
    - `:executor` — Executor PID to notify on detection (required)
    - `:objective_seed` — optional integer; when set, seeds the server's
      `:rand` state so objective placement and movement are reproducible.
      Defaults to nil.
  """
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Returns the current position of the objective.
  """
  def get_position(pid) do
    GenServer.call(pid, :get_position)
  end

  # Callbacks --------------------------------------------------------

  @impl true
  def init(opts) do
    objective_module = Keyword.fetch!(opts, :objective_module)
    map_params = Keyword.fetch!(opts, :map_params)
    tracker = Keyword.fetch!(opts, :tracker)
    executor = Keyword.fetch!(opts, :executor)
    objective_seed = Keyword.get(opts, :objective_seed)

    seed_rand(objective_seed)

    {position, objective_state} = objective_module.init(map_params)

    state = %{
      objective_module: objective_module,
      map_params: map_params,
      tracker: tracker,
      executor: executor,
      position: position,
      objective_state: objective_state,
      found: false
    }

    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, %{found: true} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:tick, state) do
    # Move objective
    {new_position, new_objective_state} =
      state.objective_module.tick(state.position, state.objective_state, state.map_params)

    # Check for drone detection
    all_positions = PositionTracker.get_positions_map(state.tracker)

    active_positions =
      Map.reject(all_positions, fn {_pid, data} ->
        Map.get(data, :disconnected, false)
      end)

    finder =
      Enum.find(active_positions, fn {_pid, pos} ->
        Geometry.euclidean_distance(new_position, pos) <= @detection_radius
      end)

    case finder do
      {_pid, finder_pos} ->
        drone_id = Map.get(finder_pos, :id)
        send(state.executor, {:objective_found, drone_id, new_position})

        {:noreply,
         %{state | position: new_position, objective_state: new_objective_state, found: true}}

      nil ->
        schedule_tick()
        {:noreply, %{state | position: new_position, objective_state: new_objective_state}}
    end
  end

  @impl true
  def handle_call(:get_position, _from, state) do
    {:reply, state.position, state}
  end

  # Private ----------------------------------------------------------

  defp seed_rand(nil), do: :ok

  defp seed_rand(objective_seed) when is_integer(objective_seed) do
    :rand.seed(:exsss, objective_seed)
    :ok
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
