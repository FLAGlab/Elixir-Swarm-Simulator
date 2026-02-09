defmodule Simulator.PointAgentTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.{RandomWalk, Static}

  test "start_link accepts algorithm and stores it" do
    {:ok, pid} = PointAgent.start_link(Static, %{x: 10, y: 20}, start_controller: false)
    assert %{x: 10, y: 20, algorithm: Static} = PointAgent.get_position(pid)
  end

  test "tick uses algorithm to update state" do
    {:ok, pid} = PointAgent.start_link(Static, %{x: 5, y: 5}, start_controller: false)
    PointAgent.tick(pid)
    assert %{x: 5, y: 5, algorithm: Static} = PointAgent.get_position(pid)

    {:ok, pid2} = PointAgent.start_link(RandomWalk, %{x: 50, y: 50}, start_controller: false)
    old = PointAgent.get_position(pid2)
    PointAgent.tick(pid2)
    new = PointAgent.get_position(pid2)
    # With random walk, position should be within bounds and likely changed
    assert new.x in 0..500
    assert new.y in 0..500
    assert {old.x, old.y} != {new.x, new.y}
  end

  test "set_algorithm changes the algorithm used for future ticks" do
    {:ok, pid} = PointAgent.start_link(Static, %{x: 10, y: 10}, start_controller: false)
    PointAgent.set_algorithm(pid, RandomWalk)
    PointAgent.tick(pid)
    new = PointAgent.get_position(pid)
    assert new.algorithm == RandomWalk
    assert new.x in 0..500
    assert new.y in 0..500
  end

  test "set_direction stores dx/dy in state" do
    {:ok, pid} = PointAgent.start_link(Static, %{x: 1, y: 2}, start_controller: false)
    PointAgent.set_direction(pid, {3, 4})
    assert %{dx: 3, dy: 4} = PointAgent.get_position(pid)
  end
end
