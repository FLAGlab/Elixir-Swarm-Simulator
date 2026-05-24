# KnowledgeStore

**Module:** `Simulator.Algorithms.Helpers.KnowledgeStore`
**File:** `lib/simulator/algorithms/helpers/knowledge_store.ex`

Utilities for managing shared knowledge between drones. It encapsulates the logic
for storing, decaying, merging, and exporting positions received from other drones,
so algorithms can focus only on their movement strategy.

## Data model

Knowledge is stored as `%{source_pid => [positions]}`, where each entry is attributed
to the drone that originally explored those positions. This per-source attribution:

- **Prevents echo** — `merge/2` filters `self()`, so you don't store your own data back
- **Avoids duplication** — the same source always lives under the same key
- **Enables transitivity** — if A shares B's info, C receives it attributed to B (not A)
- **Decays naturally** — `decay/1` removes one position per tick per entry

## Public functions

### `decay(received_visited)`

Removes the oldest position (the last in the list) from each entry of received
knowledge. Entries that become empty are dropped automatically.

```elixir
received = %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}, %{x: 3, y: 3}]}
KnowledgeStore.decay(received)
#=> %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}]}
```

**When to call:** Once per tick, at the start of `compute_step/1`, before using the
knowledge to make decisions.

---

### `merge(received_visited, incoming_knowledge)`

Merges incoming knowledge with the stored one. Applies two rules:

1. **Anti-echo:** Filters out entries keyed by `self()` from the incoming map
2. **Freshness:** For each source, keeps the longer (fresher) list between the
   existing and the incoming one

```elixir
existing = %{pid_a => [%{x: 1, y: 1}]}
incoming = %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}], self() => [%{x: 3, y: 3}]}
KnowledgeStore.merge(existing, incoming)
#=> %{pid_a => [%{x: 1, y: 1}, %{x: 2, y: 2}]}  # self() filtered, pid_a updated
```

**When to call:** In `handle_received_data/3`, when receiving knowledge from a neighbor.

---

### `all_positions(visited, received_visited)`

Combines the drone's own positions with all received positions into a flat list.
Useful for getting a unified view of the total knowledge.

```elixir
visited = [%{x: 1, y: 1}]
received = %{pid_a => [%{x: 2, y: 2}], pid_b => [%{x: 3, y: 3}]}
KnowledgeStore.all_positions(visited, received)
#=> [%{x: 1, y: 1}, %{x: 2, y: 2}, %{x: 3, y: 3}]
```

**When to call:** In `compute_step/1`, to build the heatmap or make decisions
based on all available knowledge.

---

### `build_shareable(visited, received_visited)`

Builds the knowledge map for broadcast. Includes:
- The drone's own positions keyed by `self()`
- All received knowledge (for transitive propagation)

```elixir
visited = [%{x: 1, y: 1}]
received = %{pid_b => [%{x: 2, y: 2}]}
KnowledgeStore.build_shareable(visited, received)
#=> %{self() => [%{x: 1, y: 1}], pid_b => [%{x: 2, y: 2}]}
```

**When to call:** In `get_shared_data/1`, to assemble the broadcast payload.

---

### `format_for_export(algo_state)`

Prepares the algorithm state for external consumption (drone detail panel).
Combines `:visited` and `:received_visited` into a single `:visited` list and removes
`:received_visited`.

```elixir
algo_state = %{visited: [%{x: 1, y: 1}], received_visited: %{pid_a => [%{x: 2, y: 2}]}}
KnowledgeStore.format_for_export(algo_state)
#=> %{visited: [%{x: 1, y: 1}, %{x: 2, y: 2}]}
```

**When to call:** In the algorithm's `format_state/1`.

## Algorithms that use it

- **HeatmapWalk** — uses every function to share and manage visited positions
