defmodule Simulator.Environment.ProximityDetectorTest do
  use ExUnit.Case, async: true

  alias Simulator.Environment.ProximityDetector

  describe "compute_neighbors/2" do
    test "detects agents within radius" do
      pid1 = make_ref()
      pid2 = make_ref()
      positions = %{pid1 => %{x: 0, y: 0}, pid2 => %{x: 30, y: 0}}

      neighbors = ProximityDetector.compute_neighbors(positions, 50)

      assert MapSet.member?(neighbors[pid1], pid2)
      assert MapSet.member?(neighbors[pid2], pid1)
    end

    test "does not detect agents outside radius" do
      pid1 = make_ref()
      pid2 = make_ref()
      positions = %{pid1 => %{x: 0, y: 0}, pid2 => %{x: 100, y: 0}}

      neighbors = ProximityDetector.compute_neighbors(positions, 50)

      refute MapSet.member?(neighbors[pid1], pid2)
    end

    test "does not include self as neighbor" do
      pid1 = make_ref()
      positions = %{pid1 => %{x: 0, y: 0}}

      neighbors = ProximityDetector.compute_neighbors(positions, 50)

      refute MapSet.member?(neighbors[pid1], pid1)
    end

    test "handles empty positions" do
      neighbors = ProximityDetector.compute_neighbors(%{}, 50)
      assert neighbors == %{}
    end

    test "detects multiple neighbors" do
      pid1 = make_ref()
      pid2 = make_ref()
      pid3 = make_ref()

      positions = %{
        pid1 => %{x: 0, y: 0},
        pid2 => %{x: 20, y: 0},
        pid3 => %{x: 40, y: 0}
      }

      neighbors = ProximityDetector.compute_neighbors(positions, 50)

      assert MapSet.size(neighbors[pid1]) == 2
      assert MapSet.size(neighbors[pid2]) == 2
      assert MapSet.size(neighbors[pid3]) == 2
    end

    test "asymmetric distances when one is in range and another is not" do
      pid1 = make_ref()
      pid2 = make_ref()
      pid3 = make_ref()

      positions = %{
        pid1 => %{x: 0, y: 0},
        pid2 => %{x: 30, y: 0},
        pid3 => %{x: 100, y: 0}
      }

      neighbors = ProximityDetector.compute_neighbors(positions, 50)

      assert MapSet.member?(neighbors[pid1], pid2)
      refute MapSet.member?(neighbors[pid1], pid3)
      assert MapSet.member?(neighbors[pid3] |> MapSet.new(), pid3) == false
    end
  end

  describe "get_neighbors/2" do
    setup do
      suffix = System.unique_integer([:positive])
      tracker_name = :"tracker_prox_test_#{suffix}"
      proximity_name = :"proximity_prox_test_#{suffix}"

      {:ok, _} = Simulator.Environment.PositionTracker.start_link(name: tracker_name)

      {:ok, pid} =
        ProximityDetector.start_link(name: proximity_name, tracker: tracker_name)

      %{proximity: pid}
    end

    test "returns empty MapSet for unknown agent", %{proximity: proximity} do
      fake_pid = make_ref()
      neighbors = ProximityDetector.get_neighbors(proximity, fake_pid)

      assert neighbors == MapSet.new()
    end
  end
end
