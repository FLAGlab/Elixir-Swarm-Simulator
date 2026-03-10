defmodule Simulator.Algorithm do
  @moduledoc """
  Behaviour for drone movement and communication algorithms.

  Algorithms are the brain of the drone. They define three capabilities:

  - **Movement**: `update_position/1` decides where the drone moves next
  - **Broadcasting**: `get_shared_data/1` decides what information the drone
    shares with nearby drones (e.g., explored zones, detected targets)
  - **Receiving**: `handle_received_data/3` decides how the drone processes
    information received from a neighbor

  All three callbacks receive only the agent's local state. An algorithm
  must never reach outside this state for information — the drone only knows
  what it has locally and what the environment tells it.

  `get_shared_data/1` and `handle_received_data/3` have default implementations
  that do nothing, so existing algorithms (like `Static` and `RandomWalk`)
  continue to work without changes.
  """

  @doc """
  Decides the drone's next position based on its local state.

  Receives the full agent state (`%{position, map, neighbors, ...}`) and
  returns the new `%{x, y}` position map.
  """
  @callback update_position(state :: map()) :: map()

  @doc """
  Returns the data this drone wants to broadcast to its neighbors.

  Called on every tick. The returned map is sent via the CommunicationRelay
  to all drones currently within detection radius. Return an empty map
  to broadcast nothing.
  """
  @callback get_shared_data(state :: map()) :: map()

  @doc """
  Processes data received from a neighboring drone.

  Called when the CommunicationRelay delivers a message from a neighbor.
  Receives the sender's PID, the data they shared, and the current state.
  Returns the updated state.
  """
  @callback handle_received_data(sender :: pid(), data :: map(), state :: map()) :: map()

  @optional_callbacks [get_shared_data: 1, handle_received_data: 3]

  @doc """
  Calls `get_shared_data/1` on the algorithm module if implemented,
  otherwise returns an empty map.
  """
  def shared_data(algorithm, state) do
    if function_exported?(algorithm, :get_shared_data, 1) do
      algorithm.get_shared_data(state)
    else
      %{}
    end
  end

  @doc """
  Calls `handle_received_data/3` on the algorithm module if implemented,
  otherwise returns the state unchanged.
  """
  def receive_data(algorithm, sender, data, state) do
    if function_exported?(algorithm, :handle_received_data, 3) do
      algorithm.handle_received_data(sender, data, state)
    else
      state
    end
  end
end
