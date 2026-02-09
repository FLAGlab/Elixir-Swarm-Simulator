defmodule Simulator.AlgorithmsTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.{RandomWalk, Static}

  test "static algorithm leaves state unchanged" do
    state = %{x: 100, y: 200}
    assert Static.update_position(state) == state
  end

  test "random walk keeps position within bounds" do
    state = %{x: 0, y: 0}
    new = RandomWalk.update_position(state)

    assert new.x in 0..500
    assert new.y in 0..500
    assert is_integer(new.x)
    assert is_integer(new.y)
  end
end
