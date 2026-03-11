# Programming Guide

Rules and conventions to follow when writing code in this project. Clarity and readability are prioritized over clever or overly declarative code.

## Code Style

### Clarity over cleverness

Balance Elixir's declarative capabilities with readable, clean code. If a pipe chain or pattern match makes the code harder to follow, use a simpler approach. Three clear lines are better than one cryptic expression.

### Module organization

Follow this order within every module:

```elixir
defmodule MyModule do
  use GenServer                    # 1. use/require/import
  require Logger
  alias Simulator.SomeModule

  @some_attribute 30               # 2. Module attributes

  @moduledoc """..."""             # 3. @moduledoc

  # Public API -------             # 4. Public functions with @doc
  @doc """..."""
  def start_link(opts) do
  end

  # Callbacks -------              # 5. GenServer/@impl callbacks
  @impl true
  def init(state) do
  end

  # Private ---------              # 6. Private functions
  defp helper do
  end
end
```

Use comment separators (`# Section Name -----`) to visually divide sections in larger modules.

### Documentation

- Every public function gets `@doc` with a clear description
- Every module gets `@moduledoc` explaining its purpose and role
- Use `@doc false` for internal public functions
- Include `## Examples` in `@doc` when behavior isn't obvious
- Keep comments minimal — only for non-obvious logic. The code should be self-explanatory

### Naming

- Variables: descriptive snake_case (`agent_pid`, `new_position`, `structures_json`)
- Unused params: explicit underscore prefix (`_from`, `_opts`, `_map`)
- Temporary/transformed: prefix with `new_` (`new_state`, `new_executions`)
- Module attributes: descriptive snake_case (`@update_interval`, `@tick_interval`)
- No abbreviations unless universally understood (`pid`, `opts`)

### Pipes

Use pipes for sequential data transformations. Do not overuse — single operations stay inline.

```elixir
# Good: pipe for sequential transformation
%Simulation{}
|> Simulation.changeset(attrs)
|> Repo.insert()

# Good: pipe for building state
socket
|> assign(:simulation, simulation)

# Good: inline for single operation
def get_position(pid), do: Agent.get(pid, fn state -> state.position end)

# Bad: unnecessary pipe for one call
pid
|> PointAgent.get_position()
```

### Pattern matching

Prefer pattern matching in function heads over body matching when possible:

```elixir
# Good: function head
def compute_step(%{position: position, map: map} = state) do
  ...
end

# Good: function head with struct
def delete_simulation(%Simulation{} = simulation) do
  ...
end

# Good: channel join with string pattern
def join("simulation:" <> id, _params, socket) do
  ...
end
```

Use `case` for branching on return values, `cond` for multiple conditions, `with/else` for chained operations that can fail:

```elixir
# case for pattern matching results
case Map.fetch(state.executions, simulation.id) do
  {:ok, _pid} -> {:reply, :already_running, state}
  :error -> ...
end

# cond for multi-way branching
cond do
  value < min -> min
  value > max -> max
  true -> value
end

# with/else for chained fallible operations
with {:ok, pid} <- SimulationExecutor.start_link(%{simulation: simulation}) do
  ...
else
  {:error, reason} -> ...
end
```

### Maps and state

- Atom keys for internal state: `%{position: %{x: 0, y: 0}, algorithm: module}`
- String keys only for external data (registries, user input): `%{"random_walk" => RandomWalk}`
- Struct updates with `%{state | key: value}` syntax
- `Map.put/3` when adding new keys to a plain map
- Access struct fields with dot notation, never bracket syntax

### Functions

- Keep functions short (5-15 lines). Extract helpers when a function grows beyond that
- Use `for` comprehensions for list generation, `Enum` functions for transformation
- Mark unused parameters explicitly with `_`

### GenServer conventions

- Public API functions at the top, callbacks below
- Always use `@impl true` on callbacks
- Use `Logger` for production logging, `IO.inspect` only for temporary debugging (with `label:`)
- Register with meaningful names via `name:` option

### Error handling

- Use `with/else` for operations that can fail in sequence
- Let processes crash on unexpected errors (OTP supervision handles recovery)
- Log errors with `Logger.error/1` before returning error tuples
- Never silently swallow errors

## Elixir

- Lists do not support index-based access — use `Enum.at/2`, pattern matching, or `List`
- Variables are immutable but can be rebound — always bind `if`/`case`/`cond` results to variables
- Never nest multiple modules in the same file
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should end in `?`, not start with `is_`
- Elixir does NOT support `if/else if` or `if/elsif` — use `cond` or `case`

## Phoenix

- Router `scope` blocks include an optional alias prefixed to all routes — be mindful to avoid duplicate module prefixes
- `Phoenix.View` is not included — don't use it
- Always use `~H` or `.html.heex` templates, never `~E`
- Use `Phoenix.Component.to_form/2` for forms, never pass changesets directly to templates
- Use the imported `<.input>` component for form inputs
- Use `<.icon name="hero-...">` for icons (from `core_components.ex`)
- Never write inline `<script>` tags — all JS goes through `assets/js/app.js`
- `<.flash_group>` must only be called inside the `layouts.ex` module

## Ecto / Database

- DB uses SQLite via `ecto_sqlite3`
- Always preload associations in queries when they'll be accessed in templates
- Remember `import Ecto.Query` when writing queries or seeds
- `Ecto.Changeset.validate_number/2` does not support `:allow_nil`
- Schema `:text` columns use `:string` type
- Use `Ecto.Changeset.get_field/2` to access changeset fields
- Fields set programmatically must not be in `cast` calls
- Never commit secrets or credentials to the repository

## CSS / JavaScript

- **Tailwind CSS v4** — no `tailwind.config.js`, uses `@import "tailwindcss"` syntax in `app.css`
- Never use `@apply`
- **DaisyUI** is available but prefer Tailwind classes when practical
- Only `app.js` and `app.css` bundles are supported — import vendor deps into those files
- No external script `src` or link `href` in layouts
- Never write inline `<script>` tags in templates
- JS: use `const` by default, `let` only when mutation is needed
- JS: named functions for exports, arrow functions for callbacks
- JS: always clean up connections/state before re-initializing

## HEEx Templates

- Use `{...}` for interpolation in tag attributes and tag bodies
- Use `<%= ... %>` only for block constructs (`if`, `cond`, `case`, `for`) inside tag bodies
- HEEx comments: `<%!-- comment --%>`
- Class attributes support lists: `class={["px-2", @flag && "py-5"]}`
- Wrap `if` inside class lists with parens: `if(@cond, do: "a", else: "b")`
- Use `<%= for item <- @collection do %>` for iteration, never `<% Enum.each %>`
- Use `phx-no-curly-interpolation` on tags that contain literal `{`/`}` in text content

## Related Documentation

- **[Architecture.md](./Architecture.md)** — System architecture, process tree, data flows, design decisions
- **[ALGORITHMS.md](./ALGORITHMS.md)** — How to implement and register movement algorithms
- **[MAPS.md](./MAPS.md)** — How to implement and register simulation maps

## Mix Commands

```bash
mix setup              # Install deps, create DB, build assets
mix phx.server         # Start dev server (port 4000)
mix test               # Run all tests
mix test test/path.exs # Run single test file
mix test --failed      # Re-run only previously failed tests
mix precommit          # Lint (warnings as errors) + tests — run before committing
mix format             # Format code
```

Always run `mix precommit` before committing changes.
