# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Multi-agent swarm simulator built with Phoenix 1.8 / Elixir 1.15 / SQLite. Agents are OTP processes (`PointAgent`) with pluggable movement algorithms, visualized in real-time via LiveView + Canvas.

## Commands

```bash
mix setup              # Install deps, create DB, build assets
mix phx.server         # Start dev server (port 4000)
mix test               # Run all tests
mix test test/path.exs # Run single test file
mix test --failed      # Re-run only previously failed tests
mix precommit          # Lint (warnings as errors) + tests — run before committing
mix format             # Format code
```

## Architecture

### Core Domain (`lib/simulator/`)

- **PointAgent** — An `Agent` process representing one swarm member. Maintains `{x, y}` position and algorithm module. A linked process ticks every 30ms calling the algorithm's `update_position/1`.
- **SimulationExecutor** (`simulation_executor.ex`) — GenServer managing a single simulation: spawns N `PointAgent` processes, aggregates their positions.
- **SimulationManager** — GenServer tracking multiple running executions. Prevents duplicate runs per simulation ID.
- **Simulations context** (`simulations.ex`) — Standard Ecto CRUD for the `simulations` table (fields: `type`, `algorithm`, `swarm`).

### Algorithm System (`lib/simulator/algorithms/`)

Behaviour: `Simulator.Algorithm` requires `update_position(state) :: state`. Registry in `algorithms.ex` maps string names to modules. Current implementations: `RandomWalk`, `Static`. To add an algorithm: implement the behaviour and register it.

### Web Layer (`lib/simulator_web/`)

- **SimulationController** — RESTful CRUD at `/simulations`.
- **ExecutionByIdLive** (`live/execution_live/index.ex`) — LiveView at `/execution_live/:id`. Starts simulation execution, polls positions every 30ms via a Task, broadcasts through PubSub to the canvas component.
- **Canvas component** (`live/execution_live/components/map.html.heex`) — Renders agent positions visually.

### Data Flow for Live Execution

`LiveView mount` → `SimulationManager.start_execution` → `SimulationExecutor` spawns `PointAgent`s → Task loop polls positions every 30ms → PubSub broadcast → LiveView assigns → Canvas renders.

## Key Conventions

- **Always** wrap LiveView templates with `<Layouts.app flash={@flash}>`.
- Use `Req` (`:req`) for HTTP — never HTTPoison/Tesla.
- Tailwind v4 — no `tailwind.config.js`, uses `@import "tailwindcss"` syntax in `app.css`. Never use `@apply`.
- No inline `<script>` tags — all JS goes through `assets/js/app.js` and hooks.
- Use `<.icon name="hero-...">` for Heroicons, `<.input>` for form inputs.
- Use LiveView streams for collections, never deprecated `phx-update="append"`.
- Forms must use `to_form/2` assigns, never pass changesets directly to templates.
- No nested module definitions in the same file.
- Don't use `String.to_atom/1` on user input.
- Access struct fields with dot notation, not map syntax (`[]`).
- Elixir lists don't support index access — use `Enum.at/2`.
- Bind `if`/`case`/`cond` results to variables (immutable rebinding).
- DB uses SQLite via `ecto_sqlite3`. Schema `:text` columns use `:string` type.
