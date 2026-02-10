defmodule SimulatorWeb.ExecutionController do
  use SimulatorWeb, :controller

  alias Simulator.Maps
  alias Simulator.Simulations

  def show(conn, %{"id" => id}) do
    simulation = Simulations.get_simulation!(id)
    map_params = Maps.get_map(simulation.map).get_paramethers()
    render(conn, :show, simulation: simulation, map_params: map_params)
  end
end
