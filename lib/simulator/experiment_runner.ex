defmodule Simulator.ExperimentRunner do
  @moduledoc """
  Runs N executions of a simulation sequentially.

  Each run goes through the standard `SimulationManager.start_execution/1`
  path and produces an `ExecutionRun` row on completion. The runner polls
  the Manager between runs (`get_positions`) and detects the
  `completed: true` reply that the Manager emits once it has persisted the
  `ExecutionRun`.

  Sequential by design: `SimulationManager` rejects duplicate executions
  for the same `simulation_id` with `:already_running`, so running in
  parallel would require a Manager refactor.

  ## Usage

      Simulator.ExperimentRunner.run(simulation, 30)

  The controller wraps this in a `Task.Supervisor.start_child/2` so the
  HTTP request can return immediately and the runs proceed in the
  background.
  """

  alias Simulator.SimulationManager
  require Logger

  @default_run_timeout 300_000
  @default_poll_interval 100

  @doc """
  Runs `count` executions of `simulation` sequentially. Blocks the
  calling process until all runs complete (or time out).

  ## Options
    - `:run_timeout_ms` — max wait per run before logging a timeout and
      moving to the next one. Defaults to #{@default_run_timeout} ms.
    - `:starter` — 1-arity function used to start each run. Exposed so
      tests can inject a fake without standing up an executor.
      Defaults to `&SimulationManager.start_execution/1`.
    - `:awaiter` — 2-arity function `(simulation, timeout_ms)` that returns
      `{:ok, execution_run_id}` or `{:error, :timeout}`. Exposed so tests
      can inject a fake without standing up a Manager. Defaults to the
      polling-based awaiter that calls `SimulationManager`.

  Returns a list of `{:ok, execution_run_id}` or `{:error, reason}` in
  the order runs completed.
  """
  def run(simulation, count, opts \\ []) when count > 0 do
    run_timeout = Keyword.get(opts, :run_timeout_ms, @default_run_timeout)
    starter = Keyword.get(opts, :starter, &SimulationManager.start_execution/1)
    awaiter = Keyword.get(opts, :awaiter, &poll_until_complete/2)

    Logger.info(
      "ExperimentRunner: starting batch of #{count} runs for simulation #{simulation.id}"
    )

    results = run_loop(simulation, count, run_timeout, starter, awaiter, [])

    Logger.info(
      "ExperimentRunner: batch complete for simulation #{simulation.id} — " <>
        "#{Enum.count(results, &match?({:ok, _}, &1))} ok, " <>
        "#{Enum.count(results, &match?({:error, _}, &1))} errors"
    )

    results
  end

  # Private ----------------------------------------------------------

  defp run_loop(_simulation, 0, _timeout, _starter, _awaiter, acc), do: Enum.reverse(acc)

  defp run_loop(simulation, remaining, timeout, starter, awaiter, acc) do
    case starter.(simulation) do
      :ok ->
        case awaiter.(simulation, timeout) do
          {:ok, _} = result ->
            run_loop(simulation, remaining - 1, timeout, starter, awaiter, [result | acc])

          {:error, :timeout} = result ->
            Logger.warning(
              "ExperimentRunner: run timed out for simulation #{simulation.id}; " <>
                "stopping it and moving on"
            )

            SimulationManager.stop_execution(simulation.id)
            run_loop(simulation, remaining - 1, timeout, starter, awaiter, [result | acc])
        end

      :already_running ->
        # Should not happen in normal flow: the Manager cleans up the
        # previous executor before recording the completion that ends
        # our wait. Brief retry covers any unexpected race.
        Process.sleep(50)
        run_loop(simulation, remaining, timeout, starter, awaiter, acc)

      {:error, reason} = error ->
        Logger.error("ExperimentRunner: start_execution failed: #{inspect(reason)}")

        run_loop(simulation, remaining - 1, timeout, starter, awaiter, [error | acc])
    end
  end

  defp poll_until_complete(simulation, timeout) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_poll(simulation, deadline)
  end

  defp do_poll(simulation, deadline) do
    response =
      GenServer.call(SimulationManager, {:get_positions, %{simulation: simulation}})

    case response do
      %{completed: true, execution_run_id: id} ->
        {:ok, id}

      _ ->
        now = System.monotonic_time(:millisecond)

        if now >= deadline do
          {:error, :timeout}
        else
          sleep_ms = min(@default_poll_interval, deadline - now)
          Process.sleep(max(0, sleep_ms))
          do_poll(simulation, deadline)
        end
    end
  end
end
