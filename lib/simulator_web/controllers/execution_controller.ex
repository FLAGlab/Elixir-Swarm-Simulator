defmodule SimulatorWeb.ExecutionController do
  @moduledoc """
  Controller for the simulation execution view.

  Serves `GET /execution/:id` which renders the execution page. The page
  loads the simulation record and its map parameters, then the frontend
  connects via `SimulationChannel` to receive real-time position updates.
  """

  use SimulatorWeb, :controller

  alias Simulator.Maps
  alias Simulator.Simulations

  @doc """
  Renders the execution page for a given simulation ID.

  Fetches the `Simulation` struct and resolves the corresponding
  `MapParams` to pass dimensions to the canvas.
  """
  def show(conn, %{"id" => id}) do
    simulation = Simulations.get_simulation!(id)
    map_params = Maps.get_map(simulation.map).get_paramethers()

    structures_json =
      map_params.structures
      |> Enum.map(fn structure ->
        %{
          id: structure.id,
          points: Enum.map(structure.points, fn {x, y} -> %{x: x, y: y} end)
        }
      end)
      |> Jason.encode!()

    render(conn, :show,
      simulation: simulation,
      map_params: map_params,
      structures_json: structures_json
    )
  end
end
