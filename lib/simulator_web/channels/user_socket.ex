defmodule SimulatorWeb.UserSocket do
  @moduledoc """
  WebSocket endpoint for simulation clients.

  Routes `"simulation:*"` topics to `SimulatorWeb.SimulationChannel`.
  Accepts all connections without authentication.
  """

  use Phoenix.Socket

  channel "simulation:*", SimulatorWeb.SimulationChannel

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  def id(_socket), do: nil
end
