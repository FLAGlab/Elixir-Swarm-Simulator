# Elixir Swarm Simulator

An interactive web simulator for swarm behavior built with **Elixir** and the **Phoenix** framework. This project allows you to visualize and experiment with swarm intelligence algorithms in real time.

## Project Description

Elixir Swarm Simulator is a modern web application that simulates the collective behavior of autonomous agents (such as bee swarms, bird flocks, or fish schools). Users can:

- **Create custom simulations** with different parameters
- **Visualize in real time** the movement and behavior of agents
- **Experiment with algorithms** for artificial intelligence and emergent behavior
- **Analyze results** through real-time statistics and metrics

## Technologies Used

- **Elixir 1.15+**: Functional language with native concurrency support
- **Phoenix 1.8.1**: Modern and scalable web framework
- **Phoenix LiveView**: Real-time interactivity without complex JavaScript
- **Ecto + SQLite3**: Data persistence
- **Tailwind CSS 4**: Responsive and modern design
- **Heroicons**: Icon library
- **Req**: HTTP client for integrations

## Prerequisites

Before getting started, make sure you have installed:

- **Elixir 1.15 or higher**
- **Erlang/OTP 26+** (included with Elixir)
- **Node.js 18+** (for compiling assets)
- **SQLite3** (included in most systems)
- **Git**

To verify your installation:

```bash
elixir --version
erl -version
node --version
```

## Installation and Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd Elixir-Swarm-Simulator
```

### 2. Install Dependencies

Run the setup command that automatically configures the project:

```bash
mix setup
```

This command performs:
- Downloads and installs all dependencies with `mix deps.get`
- Sets up the database with `mix ecto.setup`
- Compiles the assets (CSS, JS) with `mix assets.build`

### 3. Start the Server

```bash
mix phx.server
```

Or if you prefer using IEx (Elixir interactive shell):

```bash
iex -S mix phx.server
```

## Accessing the Application

Once the server is started, open your browser and visit:

```
http://localhost:4000
```

The application is ready to use. No initial authentication is required.

## Project Structure

```
├── lib/
│   ├── simulator/              # Business logic (pure Elixir)
│   │   └── agents/             # Agent simulation modules
│   └── simulator_web/          # Web components
│       ├── live/               # Phoenix LiveViews (interactive UI)
│       ├── components/         # Reusable components
│       └── router.ex           # HTTP routes
├── priv/
│   └── repo/                   # Database migrations
├── assets/
│   ├── css/                    # Tailwind CSS styles
│   └── js/                     # JavaScript/TypeScript
├── test/                       # Test suite
├── config/                     # Project configuration
└── mix.exs                     # Dependencies and configuration
```

## Main Features

### Real-Time Simulations
- Interactive visualization of agents in motion
- Multiple behavior algorithms available
- Live parameter adjustment without restarting

### Data Persistence
- Integrated SQLite3 database
- Save and load simulation configurations
- Experiment history

### Modern Interface
- Responsive design with Tailwind CSS
- Interactive components with Phoenix LiveView
- Smooth user experience without page reloads

### Scalability
- Architecture based on Erlang/OTP processes
- Support for multiple concurrent simulations
- Optimized for high performance

## Testing

Run all tests:

```bash
mix test
```

Run tests for a specific file:

```bash
mix test test/simulator_web/live/some_live_test.exs
```

Run only previously failed tests:

```bash
mix test --failed
```

## Useful Commands

| Command | Description |
|---------|-------------|
| `mix setup` | Initial installation and setup |
| `mix phx.server` | Start the development server |
| `mix test` | Run the test suite |
| `mix format` | Automatically format code |
| `mix precommit` | Run linters and tests (use before committing) |
| `mix ecto.setup` | Set up the database |
| `mix ecto.reset` | Reset the database |
| `mix phx.gen.live` | Generate a new LiveView (scaffolding) |

## Configuration

Configuration files are located in `config/`:

- **config.exs**: Global configuration
- **dev.exs**: Development configuration
- **prod.exs**: Production configuration
- **test.exs**: Test configuration
- **runtime.exs**: Runtime configuration

## Production Deployment

For more information on deployment options:

- [Phoenix Deployment Guides](https://hexdocs.pm/phoenix/deployment.html)
- [Deploy with Fly.io](https://hexdocs.pm/phoenix/fly.html)
- [Deploy with Heroku](https://hexdocs.pm/phoenix_heroku/installation.html)

## Resources and Documentation

### Official Documentation
- [Phoenix Documentation](https://hexdocs.pm/phoenix/overview.html)
- [Phoenix LiveView Guide](https://hexdocs.pm/phoenix_live_view/welcome.html)
- [Elixir Documentation](https://elixir-lang.org/docs.html)
- [Ecto Documentation](https://hexdocs.pm/ecto/Ecto.html)

### Community
- [Elixir Forum](https://elixirforum.com/c/phoenix-forum)
- [Elixir Community](https://elixir-lang.org/community)
- [Discord Elixir/Erlang](https://discord.gg/elixir)

## Contributing

Contributions are welcome. Please:

1. Fork the project
2. Create a branch for your feature (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Project Guidelines

See [AGENTS.md](AGENTS.md) for development guidelines, code conventions, and architecture standards.

## License

This project is licensed. See the [LICENSE](LICENSE) file for details.

## Author

Project developed as part of research in swarm intelligence and multi-agent simulation.

---

**Issues or Questions?**

If you find any issues or have questions, please open an issue in the repository.
