defmodule SimulatorWeb.ExecutionRunController do
  @moduledoc """
  Controller for viewing execution run statistics.
  """

  use SimulatorWeb, :controller

  alias Simulator.Simulations

  @doc """
  Renders the stats page for a completed execution run.
  """
  def show(conn, %{"id" => id}) do
    execution_run = Simulations.get_execution_run!(id)
    render(conn, :show, execution_run: execution_run)
  end
end
