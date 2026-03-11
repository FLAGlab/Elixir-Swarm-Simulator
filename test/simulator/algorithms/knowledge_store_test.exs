defmodule Simulator.Algorithms.Helpers.KnowledgeStoreTest do
  use ExUnit.Case, async: true

  alias Simulator.Algorithms.Helpers.KnowledgeStore

  describe "decay/1" do
    test "returns empty map for empty input" do
      assert KnowledgeStore.decay(%{}) == %{}
    end

    test "removes last position from each entry" do
      source = make_ref()
      received = %{source => [%{x: 1, y: 1}, %{x: 2, y: 2}, %{x: 3, y: 3}]}

      decayed = KnowledgeStore.decay(received)

      assert length(decayed[source]) == 2
      assert decayed[source] == [%{x: 1, y: 1}, %{x: 2, y: 2}]
    end

    test "removes entry when fully decayed" do
      source = make_ref()
      received = %{source => [%{x: 1, y: 1}]}

      decayed = KnowledgeStore.decay(received)

      assert decayed == %{}
    end

    test "decays multiple entries independently" do
      s1 = make_ref()
      s2 = make_ref()
      received = %{s1 => [%{x: 1, y: 1}, %{x: 2, y: 2}], s2 => [%{x: 3, y: 3}]}

      decayed = KnowledgeStore.decay(received)

      assert length(decayed[s1]) == 1
      refute Map.has_key?(decayed, s2)
    end
  end

  describe "merge/2" do
    test "adds new sources from incoming" do
      source = make_ref()
      incoming = %{source => [%{x: 1, y: 1}]}

      merged = KnowledgeStore.merge(%{}, incoming)

      assert merged[source] == [%{x: 1, y: 1}]
    end

    test "keeps fresher (longer) list per source" do
      source = make_ref()
      existing = %{source => [%{x: 1, y: 1}]}
      incoming = %{source => [%{x: 1, y: 1}, %{x: 2, y: 2}, %{x: 3, y: 3}]}

      merged = KnowledgeStore.merge(existing, incoming)

      assert length(merged[source]) == 3
    end

    test "keeps existing when it is fresher" do
      source = make_ref()
      existing = %{source => [%{x: 1, y: 1}, %{x: 2, y: 2}, %{x: 3, y: 3}]}
      incoming = %{source => [%{x: 1, y: 1}]}

      merged = KnowledgeStore.merge(existing, incoming)

      assert length(merged[source]) == 3
    end

    test "filters out self PID to prevent echo" do
      self_pid = self()
      other = make_ref()
      incoming = %{self_pid => [%{x: 1, y: 1}], other => [%{x: 2, y: 2}]}

      merged = KnowledgeStore.merge(%{}, incoming)

      refute Map.has_key?(merged, self_pid)
      assert Map.has_key?(merged, other)
    end
  end

  describe "all_positions/2" do
    test "returns own visited when no received" do
      visited = [%{x: 1, y: 1}]

      assert KnowledgeStore.all_positions(visited, %{}) == visited
    end

    test "combines own and received positions" do
      visited = [%{x: 1, y: 1}]
      received = %{make_ref() => [%{x: 2, y: 2}], make_ref() => [%{x: 3, y: 3}]}

      all = KnowledgeStore.all_positions(visited, received)

      assert length(all) == 3
    end
  end

  describe "build_shareable/2" do
    test "includes own positions keyed by self PID" do
      visited = [%{x: 1, y: 1}]
      shareable = KnowledgeStore.build_shareable(visited, %{})

      assert shareable[self()] == visited
    end

    test "includes received knowledge for transitivity" do
      source = make_ref()
      visited = [%{x: 1, y: 1}]
      received = %{source => [%{x: 2, y: 2}]}

      shareable = KnowledgeStore.build_shareable(visited, received)

      assert shareable[self()] == visited
      assert shareable[source] == [%{x: 2, y: 2}]
    end
  end

  describe "format_for_export/1" do
    test "combines visited and received into single visited list" do
      source = make_ref()

      algo_state = %{
        visited: [%{x: 1, y: 1}],
        received_visited: %{source => [%{x: 2, y: 2}]}
      }

      exported = KnowledgeStore.format_for_export(algo_state)

      assert length(exported.visited) == 2
      refute Map.has_key?(exported, :received_visited)
    end
  end
end
