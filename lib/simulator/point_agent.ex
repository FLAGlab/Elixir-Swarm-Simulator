defmodule PointAgent do
  @update_interval 30

  # Public API -----------------------------------------------------

  def start_link() do
    {:ok, pid} = Agent.start_link(fn ->
       %{
        x: 255,
        y: 255
      }
    end)

    # start controller loop
    spawn_link(fn -> controller_loop(pid) end)

    {:ok, pid}
  end

  def get_position(pid), do: Agent.get(pid, fn state -> state end)


  # Controller Process --------------------------------------------

  defp controller_loop(agent_pid) do
    # schedule periodic update
    Process.send_after(self(), :tick, @update_interval)

    loop(agent_pid)
  end

  defp loop(agent_pid) do
    receive do
      :tick ->
        Agent.update(agent_pid, fn st ->
          update_position(st)
        end)

        Process.send_after(self(), :tick, @update_interval)
        loop(agent_pid)

      {:set_direction, {dx, dy}} ->
        Agent.update(agent_pid, fn st -> %{st | dx: dx, dy: dy} end)
        loop(agent_pid)
    end
  end

  def update_position(%{x: x, y: y}) do
    valor_x = clamp(x + Enum.random(-5..5), 0, 500)
    valor_y = clamp(y + Enum.random(-5..5), 0, 500)
    new_position = %{x: valor_x, y: valor_y}

    new_position
  end

  def clamp(numero, cota_inferior, cota_superior) do
    cond do
      numero < cota_inferior -> cota_inferior
      numero > cota_superior -> cota_superior
      true -> numero
    end
  end
end
