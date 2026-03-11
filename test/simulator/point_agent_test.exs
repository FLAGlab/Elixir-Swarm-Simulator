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

    {:ok, _relay} =
      CommunicationRelay.start_link(
        name: relay_name,
        tracker: tracker_name,
        proximity: proximity_name
      )

    %{tracker: tracker, tracker_name: tracker_name, relay_name: relay_name}
  end

  test "start_link initializes agent with default position", %{
    tracker_name: tracker,
    relay_name: relay
  } do
    {:ok, pid} = Simulator.PointAgent.start_link("static", "clean", tracker, relay, 1)
    assert %{x: 250, y: 250} = Simulator.PointAgent.get_position(pid)
  end

  test "agent reports position to tracker after tick", %{
    tracker: tracker,
    tracker_name: tracker_name,
    relay_name: relay
  } do
    {:ok, _pid} = Simulator.PointAgent.start_link("static", "clean", tracker_name, relay, 1)

    Process.sleep(50)

    %{positions: positions} = PositionTracker.get_positions(tracker)
    assert length(positions) == 1
    assert %{x: 250, y: 250} = hd(positions)
  end

  test "notify_drone_entered adds neighbor to state", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} = Simulator.PointAgent.start_link("static", "clean", tracker, relay, 1)
    fake_neighbor = self()

    Simulator.PointAgent.notify_drone_entered(pid, fake_neighbor, %{x: 100, y: 100})
    Process.sleep(10)

    state = :sys.get_state(pid)
    assert Map.has_key?(state.neighbors, fake_neighbor)
    assert state.neighbors[fake_neighbor] == %{x: 100, y: 100}
  end

  test "notify_drone_left removes neighbor from state", %{
    tracker_name: tracker,
    relay_name: relay
  } do
    {:ok, pid} = Simulator.PointAgent.start_link("static", "clean", tracker, relay, 1)
    fake_neighbor = self()

    Simulator.PointAgent.notify_drone_entered(pid, fake_neighbor, %{x: 100, y: 100})
    Process.sleep(10)
    Simulator.PointAgent.notify_drone_left(pid, fake_neighbor)
    Process.sleep(10)

    state = :sys.get_state(pid)
    refute Map.has_key?(state.neighbors, fake_neighbor)
  end

  test "receive_shared_data delegates to algorithm", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} = Simulator.PointAgent.start_link("static", "clean", tracker, relay, 1)
    fake_sender = self()

    # Static algorithm doesn't implement handle_received_data,
    # so the state should remain unchanged
    Simulator.PointAgent.receive_shared_data(pid, fake_sender, %{some: "data"})
    Process.sleep(10)

    state = :sys.get_state(pid)
    assert state.position == %{x: 250, y: 250}
  end
end
