defmodule SimulatorWeb.SimulationChannel do
  use SimulatorWeb, :channel
  require Logger

  alias Simulator.Simulations

  @tick_interval 30

  @impl true
  def join("simulation:" <> id, _params, socket) do
    simulation = Simulations.get_simulation!(id)

    data = %{simulation: simulation}
    result = GenServer.call(Simulator.SimulationManager, {:start_excution, data})
    Logger.info("SimulationChannel: start execution response #{inspect(result)}")

    schedule_tick()

    socket =
      socket
      |> assign(:simulation, simulation)

    {:ok, socket}
  end

  @impl true
  def handle_info(:tick, socket) do
    simulation = socket.assigns.simulation
    data = %{simulation: simulation}

    case GenServer.call(Simulator.SimulationManager, {:get_positions, data}) do
      %{positions: positions} ->
        push(socket, "positions", %{positions: positions})

      _ ->
        :ok
    end

    schedule_tick()
    {:noreply, socket}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @tick_interval)
  end
end
