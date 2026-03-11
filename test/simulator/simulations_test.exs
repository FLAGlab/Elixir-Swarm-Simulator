defmodule Simulator.SimulationsTest do
  use Simulator.DataCase

  alias Simulator.Simulations

  describe "simulations" do
    alias Simulator.Simulations.Simulation

    import Simulator.SimulationsFixtures

    @invalid_attrs %{type: nil, algorithm: nil, swarm: nil}

    test "list_simulations/0 returns all simulations" do
      simulation = simulation_fixture()
      assert Simulations.list_simulations() == [simulation]
    end

    test "get_simulation!/1 returns the simulation with given id" do
      simulation = simulation_fixture()
      assert Simulations.get_simulation!(simulation.id) == simulation
    end

    test "create_simulation/1 with valid data creates a simulation" do
      valid_attrs = %{type: "some type", algorithm: "some algorithm", swarm: 42}

      assert {:ok, %Simulation{} = simulation} = Simulations.create_simulation(valid_attrs)
      assert simulation.type == "some type"
      assert simulation.algorithm == "some algorithm"
      assert simulation.swarm == 42
    end

    test "create_simulation/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Simulations.create_simulation(@invalid_attrs)
    end

    test "update_simulation/2 with valid data updates the simulation" do
      simulation = simulation_fixture()
      update_attrs = %{type: "some updated type", algorithm: "some updated algorithm", swarm: 43}

      assert {:ok, %Simulation{} = simulation} =
               Simulations.update_simulation(simulation, update_attrs)

      assert simulation.type == "some updated type"
      assert simulation.algorithm == "some updated algorithm"
      assert simulation.swarm == 43
    end

    test "update_simulation/2 with invalid data returns error changeset" do
      simulation = simulation_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Simulations.update_simulation(simulation, @invalid_attrs)

      assert simulation == Simulations.get_simulation!(simulation.id)
    end

    test "delete_simulation/1 deletes the simulation" do
      simulation = simulation_fixture()
      assert {:ok, %Simulation{}} = Simulations.delete_simulation(simulation)
      assert_raise Ecto.NoResultsError, fn -> Simulations.get_simulation!(simulation.id) end
    end

    test "change_simulation/1 returns a simulation changeset" do
      simulation = simulation_fixture()
      assert %Ecto.Changeset{} = Simulations.change_simulation(simulation)
    end
  end
end
