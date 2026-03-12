# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## MANDATORY: Read Documentation Before Any Change

**Before writing or modifying ANY code, you MUST read the relevant documentation in `docs/`:**

- **`docs/Architecture.md`** — Full system architecture, data flows, supervision tree, and design decisions
- **`docs/ProgramingGuide.md`** — All coding conventions, patterns, and rules for Elixir, Phoenix, CSS/JS, and HEEx
- **`docs/algorithms/ALGORITHMS.md`** — How to implement and register new movement algorithms
- **`docs/maps/MAPS.md`** — How to implement and register new simulation maps

**Failing to consult these documents before making changes will lead to inconsistent code.** Always verify your approach aligns with the documented architecture and conventions.

## Project Overview

Multi-agent swarm simulator built with Phoenix 1.8 / Elixir 1.15 / SQLite. Agents are OTP processes (`PointAgent`) with pluggable movement algorithms, visualized in real-time via Phoenix Channels + Canvas.

## Quick Commands

```bash
mix setup              # Install deps, create DB, build assets
mix phx.server         # Start dev server (port 4000)
mix test               # Run all tests
mix test test/path.exs # Run single test file
mix test --failed      # Re-run only previously failed tests
mix precommit          # Lint (warnings as errors) + tests — run before committing
mix format             # Format code
```
