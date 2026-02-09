defmodule SimulatorWeb.PageController do
  use SimulatorWeb, :controller

  def home(conn, _params) do
    render(conn, :home, version: "1.0.0")
  end
end
