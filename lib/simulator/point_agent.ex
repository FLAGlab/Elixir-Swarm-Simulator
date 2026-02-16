defmodule PointAgent do
  alias Simulator.Algorithms
  alias Simulator.Maps
  @update_interval 30

  @moduledoc """
  An `Agent` process representing a single swarm member.

  Each agent maintains a state containing its `{x, y}` position, the algorithm
  module used for movement, and the map parameters that define spatial bounds.
  A linked process ticks every `@update_interval` ms, calling the algorithm's
  `update_position/1` to compute the next position.
  """

  # Public API -----------------------------------------------------

  @doc """
  Starts a new agent process with the given algorithm and map names.

  Resolves `algo` and `map` strings to their corresponding modules via
  `Simulator.Algorithms.get_algorithm/1` and `Simulator.Maps.get_map/1`,
  initializes the agent state with position `{255, 255}`, and spawns a
  linked controller process that ticks every `@update_interval` ms.

  Returns `{:ok, pid}` where `pid` is the underlying `Agent` process.
  """
  def start_link(algo, map) do
    IO.inspect({algo, map}, label: "PointAgent: starting with algo and map")
    {:ok, pid} = Agent.start_link(fn ->
      %{
        position: %{
          x: 255,
          y: 255
        },
        algorithm: Algorithms.get_algorithm(algo),
        map: Maps.get_map(map).get_paramethers()
      }
    end)

    # start controller loop
    spawn_link(fn -> controller_loop(pid) end)

    {:ok, pid}
  end

  @doc """
  Returns the current `%{x, y}` position of the agent identified by `pid`.
  """
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
