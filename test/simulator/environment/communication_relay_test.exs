defmodule Simulator.Environment.CommunicationRelayTest do
  use ExUnit.Case, async: true

  alias Simulator.Environment.{CommunicationRelay, PositionTracker, ProximityDetector}

  setup do
    suffix = System.unique_integer([:positive])
    tracker_name = :"tracker_relay_test_#{suffix}"
    proximity_name = :"proximity_relay_test_#{suffix}"
    relay_name = :"relay_relay_test_#{suffix}"

    {:ok, _} = PositionTracker.start_link(name: tracker_name)
    {:ok, _} = ProximityDetector.start_link(name: proximity_name, tracker: tracker_name)

    {:ok, relay} =
      CommunicationRelay.start_link(
        name: relay_name,
        tracker: tracker_name,
        proximity: proximity_name
      )

    %{relay: relay, tracker: tracker_name, proximity: proximity_name}
  end

  test "starts without errors", %{relay: relay} do
    assert Process.alive?(relay)
  end

  test "broadcast does not crash with no agents", %{relay: relay} do
    # Should handle gracefully when sender has no neighbors
    CommunicationRelay.broadcast(relay, self(), %{data: "test"})
    Process.sleep(10)

    assert Process.alive?(relay)
  end
end
