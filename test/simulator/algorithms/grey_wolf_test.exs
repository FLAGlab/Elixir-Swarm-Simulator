defmodule Simulator.Algorithms.GreyWolfTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.GreyWolf
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

  describe "compute_step/1 — role assignment" do
    test "assigns alpha role to id 1" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, id: 1, neighbors: %{}}
      {_pos, new_state} = GreyWolf.compute_step(state)

      assert new_state.role == :alpha
    end

    test "assigns beta role to id 2" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, id: 2, neighbors: %{}}
      {_pos, new_state} = GreyWolf.compute_step(state)

      assert new_state.role == :beta
    end

    test "assigns delta role to id 3" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, id: 3, neighbors: %{}}
      {_pos, new_state} = GreyWolf.compute_step(state)

      assert new_state.role == :delta
    end

    test "assigns omega role to id 4+" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, id: 5, neighbors: %{}}
      {_pos, new_state} = GreyWolf.compute_step(state)

      assert new_state.role == :omega
    end
  end

  describe "compute_step/1 — dispersed hunt" do
    test "alpha generates target in its zone" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, id: 1, neighbors: %{}}
      {_pos, new_state} = GreyWolf.compute_step(state)

      assert Map.has_key?(new_state, :target)
    end

    test "omega generates target when no leaders known" do
      state = %{position: %{x: 250, y: 250}, map: @clean_map, id: 10, neighbors: %{}}
      {_pos, new_state} = GreyWolf.compute_step(state)

      assert Map.has_key?(new_state, :target)
    end

    test "keeps position within map bounds" do
      state = %{position: %{x: 2, y: 2}, map: @clean_map, id: 1, neighbors: %{}}
      {pos, _} = GreyWolf.compute_step(state)

      assert pos.x >= 0 and pos.x <= @clean_map.width
      assert pos.y >= 0 and pos.y <= @clean_map.height
    end

    test "recalculates target on collision" do
      position = %{x: 395, y: 250}
      target = %{x: 500, y: 250}

      state = %{
        position: position,
        map: @obstacle_map,
        id: 1,
        neighbors: %{},
        role: :alpha,
        target: target
      }

      {pos, new_state} = GreyWolf.compute_step(state)

      assert pos == position
      assert new_state.target != target
    end
  end

  describe "compute_step/1 — convergence" do
    test "switches to convergence when objective found" do
      objective = %{x: 400, y: 400}
      position = %{x: 100, y: 100}

      state = %{
        position: position,
        map: @clean_map,
        id: 5,
        neighbors: %{},
        role: :omega,
        objective_found: objective
      }

      {_pos, new_state} = GreyWolf.compute_step(state)

      assert Map.has_key?(new_state, :a_param)
    end

    test "decreases a_param over ticks" do
      objective = %{x: 400, y: 400}

      state = %{
        position: %{x: 100, y: 100},
        map: @clean_map,
        id: 5,
        neighbors: %{},
        role: :omega,
        objective_found: objective,
        a_param: 2.0
      }

      {_pos, new_state} = GreyWolf.compute_step(state)

      assert new_state.a_param < 2.0
    end
  end

  describe "get_shared_data/1" do
    test "includes role, position, and objective" do
      state = %{
        position: %{x: 100, y: 100},
        id: 1,
        role: :alpha,
        objective_found: nil
      }

      data = GreyWolf.get_shared_data(state)

      assert data.type == :gwo
      assert data.role == :alpha
      assert data.position == %{x: 100, y: 100}
      assert data.objective == nil
    end
  end

  describe "handle_received_data/3" do
    test "stores leader position in known_leaders" do
      data = %{type: :gwo, role: :alpha, position: %{x: 100, y: 100}, objective: nil}
      state = %{}

      new_state = GreyWolf.handle_received_data(self(), data, state)

      assert new_state.known_leaders.alpha == %{x: 100, y: 100}
    end

    test "does not store omega positions as leaders" do
      data = %{type: :gwo, role: :omega, position: %{x: 100, y: 100}, objective: nil}
      state = %{}

      new_state = GreyWolf.handle_received_data(self(), data, state)

      known = Map.get(new_state, :known_leaders, %{})
      refute Map.has_key?(known, :omega)
    end

    test "propagates objective from neighbor" do
      objective = %{x: 300, y: 300}
      data = %{type: :gwo, role: :beta, position: %{x: 100, y: 100}, objective: objective}
      state = %{}

      new_state = GreyWolf.handle_received_data(self(), data, state)

      assert new_state.objective_found == objective
    end

    test "does not overwrite existing objective" do
      existing = %{x: 100, y: 100}
      data = %{type: :gwo, role: :alpha, position: %{x: 50, y: 50}, objective: %{x: 300, y: 300}}
      state = %{objective_found: existing}

      new_state = GreyWolf.handle_received_data(self(), data, state)

      assert new_state.objective_found == existing
    end

    test "ignores non-gwo data" do
      state = %{}
      new_state = GreyWolf.handle_received_data(self(), %{type: :other}, state)

      assert new_state == state
    end
  end

  describe "format_state/1" do
    test "removes internal keys" do
      algo_state = %{
        known_leaders: %{alpha: %{x: 1, y: 1}},
        a_param: 1.5,
        role: :omega,
        objective_found: nil
      }

      formatted = GreyWolf.format_state(algo_state)

      refute Map.has_key?(formatted, :known_leaders)
      refute Map.has_key?(formatted, :a_param)
      assert formatted.role == :omega
    end
  end
end
