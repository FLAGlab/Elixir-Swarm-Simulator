defmodule Simulator.Environment.PositionTrackerTest do
  use ExUnit.Case, async: true

  alias Simulator.Environment.PositionTracker

  setup do
    suffix = System.unique_integer([:positive])
    name = :"tracker_test_#{suffix}"
    {:ok, pid} = PositionTracker.start_link(name: name)
    %{tracker: pid}
  end

  test "starts with empty positions", %{tracker: tracker} do
    assert %{positions: []} = PositionTracker.get_positions(tracker)
  end

  test "stores reported position", %{tracker: tracker} do
    agent = self()
    PositionTracker.report_position(tracker, agent, %{x: 100, y: 200, id: 1})

    # Cast is async, give it a moment
    Process.sleep(10)

    %{positions: positions} = PositionTracker.get_positions(tracker)
    assert length(positions) == 1
    assert hd(positions) == %{x: 100, y: 200, id: 1}
  end

  test "updates position on subsequent reports", %{tracker: tracker} do
    agent = self()
    PositionTracker.report_position(tracker, agent, %{x: 100, y: 200})
    Process.sleep(10)
    PositionTracker.report_position(tracker, agent, %{x: 150, y: 250})
    Process.sleep(10)

    %{positions: positions} = PositionTracker.get_positions(tracker)
    assert length(positions) == 1
    assert hd(positions) == %{x: 150, y: 250}
  end

  test "tracks multiple agents independently", %{tracker: tracker} do
    agent1 = spawn(fn -> Process.sleep(1000) end)
    agent2 = spawn(fn -> Process.sleep(1000) end)

    PositionTracker.report_position(tracker, agent1, %{x: 10, y: 20})
    PositionTracker.report_position(tracker, agent2, %{x: 30, y: 40})
    Process.sleep(10)

    %{positions: positions} = PositionTracker.get_positions(tracker)
    assert length(positions) == 2
  end

  test "get_positions_map returns pid-keyed map", %{tracker: tracker} do
    agent = self()
    PositionTracker.report_position(tracker, agent, %{x: 100, y: 200})
    Process.sleep(10)

    positions_map = PositionTracker.get_positions_map(tracker)
    assert is_map(positions_map)
    assert positions_map[agent] == %{x: 100, y: 200}
  end
end
