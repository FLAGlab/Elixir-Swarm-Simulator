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
    {:ok, pid} =
      Simulator.PointAgent.start_link(
        %{algorithm: "static", map: "clean"},
        %{tracker: tracker, relay: relay},
        1
      )

    assert %{x: 250, y: 250} = Simulator.PointAgent.get_position(pid)
  end

  test "agent reports position to tracker after tick", %{
    tracker: tracker,
    tracker_name: tracker_name,
    relay_name: relay
  } do
    {:ok, _pid} =
      Simulator.PointAgent.start_link(
        %{algorithm: "static", map: "clean"},
        %{tracker: tracker_name, relay: relay},
        1
      )

    Process.sleep(50)

    %{positions: positions} = PositionTracker.get_positions(tracker)
    assert length(positions) == 1
    assert %{x: 250, y: 250} = hd(positions)
  end

  test "notify_drone_entered adds neighbor to state", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} =
      Simulator.PointAgent.start_link(
        %{algorithm: "static", map: "clean"},
        %{tracker: tracker, relay: relay},
        1
      )

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
    {:ok, pid} =
      Simulator.PointAgent.start_link(
        %{algorithm: "static", map: "clean"},
        %{tracker: tracker, relay: relay},
        1
      )

    fake_neighbor = self()

    Simulator.PointAgent.notify_drone_entered(pid, fake_neighbor, %{x: 100, y: 100})
    Process.sleep(10)
    Simulator.PointAgent.notify_drone_left(pid, fake_neighbor)
    Process.sleep(10)

    state = :sys.get_state(pid)
    refute Map.has_key?(state.neighbors, fake_neighbor)
  end

  test "receive_shared_data delegates to algorithm", %{tracker_name: tracker, relay_name: relay} do
    {:ok, pid} =
      Simulator.PointAgent.start_link(
        %{algorithm: "static", map: "clean"},
        %{tracker: tracker, relay: relay},
        1
      )

    fake_sender = self()

    # Static algorithm doesn't implement handle_received_data,
    # so the state should remain unchanged
    Simulator.PointAgent.receive_shared_data(pid, fake_sender, %{some: "data"})
    Process.sleep(10)

    state = :sys.get_state(pid)
    assert state.position == %{x: 250, y: 250}
  end

  describe "seed reproducibility" do
    # These tests rely on each agent firing roughly the same number of ticks
    # within the sleep window. RandomWalk has no neighbor coupling, so the
    # only source of variation between two runs with the same (seed, id) is
    # tick count drift from BEAM scheduler jitter. On a quiet test runner
    # the assertion holds. See the "Partial reproducibility through seeding"
    # design decision in docs/Architecture.md for the broader caveat.

    defp spawn_seeded_random_walk(seed, id) do
      suffix = System.unique_integer([:positive])
      tracker_name = :"tracker_seed_#{suffix}"
      proximity_name = :"proximity_seed_#{suffix}"
      relay_name = :"relay_seed_#{suffix}"

      {:ok, _} = PositionTracker.start_link(name: tracker_name)

      {:ok, _} =
        ProximityDetector.start_link(name: proximity_name, tracker: tracker_name)

      {:ok, _} =
        CommunicationRelay.start_link(
          name: relay_name,
          tracker: tracker_name,
          proximity: proximity_name
        )

      {:ok, agent} =
        Simulator.PointAgent.start_link(
          %{algorithm: "random_walk", map: "clean", swarm_seed: seed},
          %{tracker: tracker_name, relay: relay_name},
          id
        )

      # ~2 ticks at @update_interval = 30ms. Both processes should fire
      # the same number of ticks; if they don't, this assertion will be flaky.
      Process.sleep(60)
      Simulator.PointAgent.get_position(agent)
    end

    test "two agents with the same (seed, id) reach the same position" do
      assert spawn_seeded_random_walk(12345, 7) == spawn_seeded_random_walk(12345, 7)
    end

    test "different seeds produce different positions (sanity)" do
      refute spawn_seeded_random_walk(12345, 7) == spawn_seeded_random_walk(67890, 7)
    end

    test "different ids with the same seed produce different positions" do
      refute spawn_seeded_random_walk(12345, 1) == spawn_seeded_random_walk(12345, 2)
    end
  end
end
