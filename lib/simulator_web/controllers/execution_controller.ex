defmodule SimulatorWeb.ExecutionController do
  use SimulatorWeb, :controller

  alias Simulator.Simulations

  def show(conn, %{"id" => id}) do
    simulation = Simulations.get_simulation!(id)
    render(conn, :show, simulation: simulation)
  end
end
