defmodule PointAgent do
  alias Simulator.Algorithms
  @update_interval 30

  # Public API -----------------------------------------------------

  def start_link(algo) do
    {:ok, pid} = Agent.start_link(fn ->
      %{
        position: %{
          x: 255,
          y: 255
        },
        algorithm: Algorithms.get_algorithm(algo),
        space: %{
          width: 500,
          height: 500
        }
      }
    end)

    # start controller loop
    spawn_link(fn -> controller_loop(pid) end)

    {:ok, pid}
  end

  def get_position(pid), do: Agent.get(pid, fn state ->
    state.position
  end)


  # Controller Process --------------------------------------------

  defp controller_loop(agent_pid) do
    # schedule periodic update
    Process.send_after(self(), :tick, @update_interval)

    loop(agent_pid)
  end

  defp loop(agent_pid) do
    receive do
      :tick ->
        Agent.update(agent_pid, fn state ->
          new_position = state.algorithm.update_position(state)
          %{state | position: new_position}
        end)

        Process.send_after(self(), :tick, @update_interval)
        loop(agent_pid)
    end
  end

end
