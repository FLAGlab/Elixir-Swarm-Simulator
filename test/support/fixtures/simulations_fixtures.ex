defmodule Simulator.SimulationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Simulator.Simulations` context.
  """

  @doc """
  Generate a simulation.
  """
  def simulation_fixture(attrs \\ %{}) do
    {:ok, simulation} =
      attrs
      |> Enum.into(%{
        algorithm: "some algorithm",
        swarm: 42,
        type: "some type"
      })
      |> Simulator.Simulations.create_simulation()

    simulation
  end
end
