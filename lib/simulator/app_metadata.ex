defmodule Simulator.AppMetadata do
  @moduledoc """
  Centralized application metadata.
  """

  @app :simulator

  def version, do: "1.0.0"
  def name, do: "Elixir Swarm Simulator"

  def repo_url, do: "https://github.com/FLAGlab/Elixir-Swarm-Simulator"

  def all do
    %{
      app_name: name(),
      app_version: version(),
      repo_url: repo_url()
    }
  end
end
