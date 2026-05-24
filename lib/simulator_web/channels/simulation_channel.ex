defmodule SimulatorWeb.SimulationChannel do
  @moduledoc """
  Phoenix Channel that drives real-time simulation execution.

  When a client joins `"simulation:<id>"`, the channel starts (or reuses) an
  execution via `SimulationManager`, then enters a tick loop that polls agent
  positions every `@tick_interval` ms and pushes them to the client as
  `"positions"` events.

  Supports a "selected drone" concept: the client can send `"select_drone"`
  or `"deselect_drone"` events. When a drone is selected, each tick also
  pushes a `"drone_detail"` event with that agent's detailed state.

  When the `SimulationManager` reports the run as completed (via the tick
  response), the channel pushes a `"simulation_complete"` event and stops
  scheduling further ticks.
  """

  use SimulatorWeb, :channel
  require Logger

  alias Simulator.Simulations

  @tick_interval Application.compile_env(:simulator, :tick_interval, 30)

  # Callbacks --------------------------------------------------------

  @impl true
  def join("simulation:" <> id, _params, socket) do
    simulation = Simulations.get_simulation!(id)

    result = Simulator.SimulationManager.start_execution(simulation)
    Logger.info("SimulationChannel: start execution response #{inspect(result)}")

    schedule_tick()

    socket =
      socket
      |> assign(:simulation, simulation)
      |> assign(:selected_drone, nil)
      |> assign(:completed, false)

    {:ok, socket}
  end

  @impl true
  def handle_in("select_drone", %{"id" => drone_id}, socket) do
    {:noreply, assign(socket, :selected_drone, drone_id)}
  end

  @impl true
  def handle_in("deselect_drone", _params, socket) do
    {:noreply, assign(socket, :selected_drone, nil)}
  end

  @impl true
  def handle_in("toggle_drone_connection", %{"id" => drone_id, "connected" => connected}, socket) do
    simulation = socket.assigns.simulation
    query = %{simulation: simulation, agent_id: drone_id, connected: connected}
    GenServer.call(Simulator.SimulationManager, {:toggle_drone_connection, query})
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, %{assigns: %{completed: true}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    simulation = socket.assigns.simulation
    data = %{simulation: simulation}

    case GenServer.call(Simulator.SimulationManager, {:get_positions, data}) do
      %{completed: true, execution_run_id: run_id, stats: stats} ->
        push(socket, "simulation_complete", %{
          execution_run_id: run_id,
          finder_drone_id: stats.finder_drone_id,
          duration_ms: stats.duration_ms,
          ticks: stats.ticks
        })

        {:noreply, assign(socket, :completed, true)}

      %{positions: positions} = response ->
        payload = %{positions: positions}

        payload =
          case Map.get(response, :objective) do
            nil -> payload
            objective -> Map.put(payload, :objective, objective)
          end

        push(socket, "positions", payload)
        push_selected_drone_detail(socket)
        schedule_tick()
        {:noreply, socket}

      _ ->
        push_selected_drone_detail(socket)
        schedule_tick()
        {:noreply, socket}
    end
  end

  # Private ----------------------------------------------------------

  defp push_selected_drone_detail(%{assigns: %{selected_drone: nil}}), do: :ok

  defp push_selected_drone_detail(socket) do
    simulation = socket.assigns.simulation
    agent_id = socket.assigns.selected_drone

    query = %{simulation: simulation, agent_id: agent_id}

    case GenServer.call(Simulator.SimulationManager, {:get_agent_detail, query}) do
      {:ok, detail} ->
        push(socket, "drone_detail", detail)

      _ ->
        :ok
    end
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
