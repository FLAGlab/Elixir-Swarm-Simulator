defmodule SimulatorWeb.ExecutionByIdLive.Index do
  use SimulatorWeb, :live_view
  require Logger
  alias Simulator.Simulations

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    simulation = Simulations.get_simulation!(id)
    dbg(simulation)

    random_value = Enum.random(1..500)
    some_data = %{
      :positions => [],
      :random_value => random_value,
      :simulation => simulation
    }

    already_registered =
      Registry.lookup(Simulator.Registry, "simulation:#{id}")
      |> Enum.any?()

    unless already_registered do
      Task.start(fn ->
        start_simulation(id, simulation)
        Registry.register(Simulator.Registry, "simulation:#{id}", nil)
        loop("simulation:#{id}", simulation)
      end)
    end

    socket = socket
    |> assign(:excutionId, id)
    |> assign(:some_data, some_data)

    Phoenix.PubSub.subscribe(Simulator.PubSub, "simulation:#{id}")
    {:ok, socket}
  end

  defp start_simulation(_id, simulation) do
    data = %{
      :simulation => simulation
    }
    result = GenServer.call(Simulator.SimulationManager, {:start_excution, data})
    Logger.info("ExecutionByIdLive: start excution response #{inspect(result)}")
  end

  defp loop(id, simulation) do
    :timer.sleep(30)
    data = %{
      :simulation => simulation
    }
    result = GenServer.call(Simulator.SimulationManager, {:get_positions, data})
    Phoenix.PubSub.broadcast(Simulator.PubSub, "#{id}", {:lalaevent, result.positions})
    loop(id, simulation)
  end


  @impl true
  def handle_event("some_event", _value, socket) do
    #positions = socket.assigns.some_data.positions
    {:noreply, socket}
  end

  def handle_info({:lalaevent, data}, socket) do
    socket = socket
    some_data = %{
      :positions => data,
      :random_value => Enum.random(1..500),
      :simulation => socket.assigns.some_data.simulation
    }
    socket = socket
    |> assign(:some_data, some_data)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""

    <Layouts.app flash={@flash}>

    <div class="flex justify-center">
      <div class="px-4 m-4">
        <.header>
          <.button navigate={~p"/simulations"}>
            <.icon name="hero-arrow-left" />
          </.button>
          {@some_data.simulation.type}
          <:subtitle>This is a simulation record from your database.</:subtitle>
        </.header>
      </div>
    </div>

    <.map positions={@some_data.positions} randomid={@some_data.random_value}/>
    </Layouts.app>

    """
  end

  embed_templates "components/*"



  #@impl true
  #def handle_params(_params, _url, socket) do
  #  {:noreply, socket}
  #end

  #defp list_simulations do
  #  Simulations.list_simulations()
  #end
end
