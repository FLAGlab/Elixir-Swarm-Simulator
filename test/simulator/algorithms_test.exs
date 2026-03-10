defmodule Simulator.AlgorithmsTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.{RandomWalk, Static}
  alias Simulator.Maps.MapParams

  @default_map %MapParams{width: 500, height: 500, structures: []}

  test "static algorithm leaves position unchanged" do
    state = %{position: %{x: 100, y: 200}, map: @default_map}
    assert Static.update_position(state) == %{x: 100, y: 200}
  end

  test "random walk keeps position within bounds" do
    state = %{position: %{x: 0, y: 0}, map: @default_map}
    new = RandomWalk.update_position(state)

    assert new.x in 0..500
    assert new.y in 0..500
    assert is_integer(new.x)
    assert is_integer(new.y)
  end
end
