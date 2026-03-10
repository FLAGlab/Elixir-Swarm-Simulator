defmodule Simulator.PointAgentTest do
  use ExUnit.Case, async: true

  alias Simulator.Environment.PositionTracker
  alias Simulator.Environment.ProximityDetector
  alias Simulator.Environment.CommunicationRelay

  setup do
    suffix = System.unique_integer([:positive])
    tracker_name = :"tracker_test_#{suffix}"
    proximity_name = :"proximity_test_#{suffix}"
    relay_name = :"relay_test_#{suffix}"

    {:ok, tracker} = PositionTracker.start_link(name: tracker_name)
    {:ok, _proximity} = ProximityDetector.start_link(name: proximity_name, tracker: tracker_name)
    {:ok, _relay} = CommunicationRelay.start_link(name: relay_name, tracker: tracker_name, proximity: proximity_name)

    %{tracker: tracker, tracker_name: tracker_name, relay_name: relay_name}
  end

  test "start_link initializes agent with default position", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} = PointAgent.start_link("static", "clean", tracker, relay)
    assert %{x: 255, y: 255} = PointAgent.get_position(pid)
  end

  test "agent reports position to tracker after tick", %{tracker: tracker, tracker_name: tracker_name, relay_name: relay} do
    {:ok, _pid} = PointAgent.start_link("static", "clean", tracker_name, relay)

    Process.sleep(50)

    %{positions: positions} = PositionTracker.get_positions(tracker)
    assert length(positions) == 1
    assert %{x: 255, y: 255} = hd(positions)
  end

  test "notify_drone_entered adds neighbor to state", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} = PointAgent.start_link("static", "clean", tracker, relay)
    fake_neighbor = self()

    PointAgent.notify_drone_entered(pid, fake_neighbor, %{x: 100, y: 100})
    Process.sleep(10)

    state = :sys.get_state(pid)
    assert Map.has_key?(state.neighbors, fake_neighbor)
    assert state.neighbors[fake_neighbor] == %{x: 100, y: 100}
  end

  test "notify_drone_left removes neighbor from state", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} = PointAgent.start_link("static", "clean", tracker, relay)
    fake_neighbor = self()

    PointAgent.notify_drone_entered(pid, fake_neighbor, %{x: 100, y: 100})
    Process.sleep(10)
    PointAgent.notify_drone_left(pid, fake_neighbor)
    Process.sleep(10)

    state = :sys.get_state(pid)
    refute Map.has_key?(state.neighbors, fake_neighbor)
  end

  test "receive_shared_data delegates to algorithm", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} = PointAgent.start_link("static", "clean", tracker, relay)
    fake_sender = self()

    # Static algorithm doesn't implement handle_received_data,
    # so the state should remain unchanged
    PointAgent.receive_shared_data(pid, fake_sender, %{some: "data"})
    Process.sleep(10)

    state = :sys.get_state(pid)
    assert state.position == %{x: 255, y: 255}
  end
end
