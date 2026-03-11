defmodule Simulator.Algorithms.ParticleSwarmTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.ParticleSwarm
  alias Simulator.Maps.MapParams

  @clean_map %MapParams{width: 500, height: 500, structures: [], spawn_point: %{x: 250, y: 250}}

  @obstacle_map %MapParams{
    width: 1000,
    height: 500,
    structures: [
      %{id: 1, points: [{400, 150}, {600, 150}, {600, 350}, {400, 350}]}
    ],
    spawn_point: %{x: 200, y: 250}
  }

  describe "compute_step/1 — exploration" do
    test "initializes velocity on first tick" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, neighbors: %{}}
      {_pos, new_state} = ParticleSwarm.compute_step(state)

      assert Map.has_key?(new_state, :velocity)
      assert is_float(new_state.velocity.vx)
      assert is_float(new_state.velocity.vy)
    end

    test "initializes personal_best on first tick" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, neighbors: %{}}
      {_pos, new_state} = ParticleSwarm.compute_step(state)

      assert Map.has_key?(new_state, :personal_best)
    end

    test "keeps position within map bounds" do
      state = %{position: %{x: 2, y: 2}, map: @clean_map, neighbors: %{}}

      for _ <- 1..20 do
        {pos, _} = ParticleSwarm.compute_step(state)
        assert pos.x >= 0 and pos.x <= @clean_map.width
        assert pos.y >= 0 and pos.y <= @clean_map.height
      end
    end

    test "handles collision by bouncing velocity" do
      position = %{x: 395, y: 250}
      velocity = %{vx: 8.0, vy: 0.0}

      state = %{
        position: position,
        map: @obstacle_map,
        neighbors: %{},
        velocity: velocity,
        personal_best: position
      }

      {pos, new_state} = ParticleSwarm.compute_step(state)

      assert pos == position
      assert new_state.velocity.vx < 0
    end
  end

  describe "compute_step/1 — convergence" do
    test "moves toward objective when found" do
      objective = %{x: 400, y: 400}
      position = %{x: 100, y: 100}

      state = %{
        position: position,
        map: @clean_map,
        neighbors: %{},
        velocity: %{vx: 2.0, vy: 2.0},
        personal_best: %{x: 200, y: 200},
        objective_found: objective
      }

      # Run multiple ticks to verify convergence trend
      closer_count =
        Enum.count(1..20, fn _ ->
          {pos, _} = ParticleSwarm.compute_step(state)
          distance(pos, objective) < distance(position, objective)
        end)

      # Should move closer most of the time (randomness allows some divergence)
      assert closer_count >= 15
    end
  end

  describe "get_shared_data/1" do
    test "returns empty map when no objective" do
      state = %{position: %{x: 100, y: 100}}
      assert ParticleSwarm.get_shared_data(state) == %{}
    end

    test "shares objective when found" do
      objective = %{x: 300, y: 300}
      state = %{position: %{x: 100, y: 100}, objective_found: objective}
      data = ParticleSwarm.get_shared_data(state)

      assert data.type == :pso
      assert data.objective == objective
    end
  end

  describe "handle_received_data/3" do
    test "stores objective from neighbor" do
      objective = %{x: 300, y: 300}
      data = %{type: :pso, objective: objective}
      state = %{}

      new_state = ParticleSwarm.handle_received_data(self(), data, state)

      assert new_state.objective_found == objective
    end

    test "does not overwrite existing objective" do
      existing = %{x: 100, y: 100}
      incoming = %{x: 300, y: 300}
      data = %{type: :pso, objective: incoming}
      state = %{objective_found: existing}

      new_state = ParticleSwarm.handle_received_data(self(), data, state)

      assert new_state.objective_found == existing
    end

    test "ignores non-pso data" do
      state = %{}
      new_state = ParticleSwarm.handle_received_data(self(), %{type: :other}, state)

      assert new_state == state
    end
  end

  describe "format_state/1" do
    test "removes internal keys" do
      algo_state = %{
        velocity: %{vx: 1.0, vy: 2.0},
        personal_best: %{x: 100, y: 100},
        objective_found: nil
      }

      formatted = ParticleSwarm.format_state(algo_state)

      refute Map.has_key?(formatted, :velocity)
      refute Map.has_key?(formatted, :personal_best)
      assert Map.has_key?(formatted, :objective_found)
    end
  end

  defp distance(%{x: x1, y: y1}, %{x: x2, y: y2}) do
    :math.sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
  end
end
