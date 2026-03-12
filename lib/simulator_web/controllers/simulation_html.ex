defmodule SimulatorWeb.SimulationHTML do
  use SimulatorWeb, :html

  embed_templates "simulation_html/*"

  @doc """
  Renders a simulation form.

  The form is defined in the template at
  simulation_html/simulation_form.html.heex
  """
  attr :changeset, Ecto.Changeset, required: true
  attr :action, :string, required: true
  attr :return_to, :string, default: nil
  attr :algorithms, :list, default: []
  attr :maps, :list, default: []
  attr :objectives, :list, default: []

  def simulation_form(assigns)
end
