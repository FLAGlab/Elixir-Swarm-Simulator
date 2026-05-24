defmodule Simulator.ExperimentRunnerTest do
  use ExUnit.Case, async: true

  alias Simulator.ExperimentRunner

  describe "run/3" do
    test "returns one {:ok, id} entry per requested run" do
      simulation_id = System.unique_integer([:positive])

      simulation = %Simulator.Simulations.Simulation{
        id: simulation_id,
        name: "test_sim_#{simulation_id}",
        algorithm: "static",
        map: "clean",
        objective: "static",
        swarm: 1,
        objective_seed: 1,
        swarm_seed: 1
      }

      parent = self()

      starter = fn sim ->
        send(parent, {:starter_called, sim.id})
        :ok
      end

      awaiter = fn _sim, _timeout ->
        {:ok, System.unique_integer([:positive])}
      end

      results = ExperimentRunner.run(simulation, 3, starter: starter, awaiter: awaiter)

      assert length(results) == 3
      assert Enum.all?(results, &match?({:ok, _}, &1))

      for _ <- 1..3 do
        assert_receive {:starter_called, ^simulation_id}, 1_000
      end

      refute_receive {:starter_called, ^simulation_id}, 50
    end

    test "returns {:error, :timeout} when the awaiter times out" do
      simulation = %Simulator.Simulations.Simulation{
        id: System.unique_integer([:positive]),
        name: "timeout_sim",
        algorithm: "static",
        map: "clean",
        objective: "static",
        swarm: 1,
        objective_seed: 1,
        swarm_seed: 1
      }

      starter = fn _sim -> :ok end
      awaiter = fn _sim, _timeout -> {:error, :timeout} end

      results =
        ExperimentRunner.run(simulation, 1,
          starter: starter,
          awaiter: awaiter,
          run_timeout_ms: 50
        )

      assert results == [{:error, :timeout}]
    end

    test "surfaces start_execution errors as {:error, reason}" do
      simulation = %Simulator.Simulations.Simulation{
        id: System.unique_integer([:positive]),
        name: "error_sim",
        algorithm: "static",
        map: "clean",
        objective: "static",
        swarm: 1,
        objective_seed: 1,
        swarm_seed: 1
      }

      starter = fn _sim -> {:error, :boom} end
      awaiter = fn _sim, _timeout -> {:ok, 1} end

      results =
        ExperimentRunner.run(simulation, 2, starter: starter, awaiter: awaiter)

      assert results == [{:error, :boom}, {:error, :boom}]
    end
  end
end
