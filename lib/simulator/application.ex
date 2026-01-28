defmodule Simulator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Simulator.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:simulator, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:simulator, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Simulator.PubSub},
      # Start a worker by calling: Simulator.Worker.start_link(arg)
      # {Simulator.Worker, arg},
      # Start to serve requests, typically the last entry
      SimulatorWeb.Endpoint,
      {Simulator.SimulationManager, interval: 300},
      {Registry, keys: :unique, name: Simulator.Registry}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Simulator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SimulatorWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
