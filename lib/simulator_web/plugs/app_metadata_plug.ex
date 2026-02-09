defmodule SimulatorWeb.Plugs.AppMetadata do
  @moduledoc """
  Plug that injects app metadata assigns into every connection.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    metadata = Simulator.AppMetadata.all()

    conn
    |> assign(:app_name, metadata.app_name)
    |> assign(:app_version, metadata.app_version)
    |> assign(:repo_url, metadata.repo_url)
  end
end
