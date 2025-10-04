defmodule BpmnWorkflow.Nodes.UserTask do
  @moduledoc """
  UserTask node - waits for an external trigger to complete.
  Runs as an independent GenServer worker.
  Holds the token until a `trigger` event is received.
  """

  use GenServer
  require Logger

  defstruct [
    :id,
    :name,
    :next_nodes,
    :engine_pid,
    :status,
    :waiting_token
  ]

  # Client API

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
  end

  def execute(id, token) do
    GenServer.cast(via_tuple(id), {:execute, token})
  end

  def trigger(id, trigger_data \\ %{}) do
    GenServer.call(via_tuple(id), {:trigger, trigger_data})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: opts[:id],
      name: opts[:name] || "User Task",
      next_nodes: opts[:next_nodes] || [],
      engine_pid: opts[:engine_pid],
      status: :initialized,
      waiting_token: nil
    }

    Logger.info("UserTask[#{state.id}] initialized: #{state.name}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, token}, state) do
    Logger.info("UserTask[#{state.id}] waiting for trigger: #{state.name}")

    # Update token position
    updated_token = BpmnWorkflow.Token.move_to(token, state.id)

    # Notify engine that we are waiting
    send(state.engine_pid, {:user_task_waiting, state.id, updated_token})

    new_state = %{state | status: :waiting, waiting_token: updated_token}
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:trigger, trigger_data}, _from, state) do
    if state.status == :waiting do
      Logger.info("UserTask[#{state.id}] triggered: #{state.name}")

      # Merge trigger data into token
      result_token =
        BpmnWorkflow.Token.update_data(state.waiting_token, fn data ->
          Map.merge(data, trigger_data)
        end)

      # Notify engine
      send(state.engine_pid, {:node_executed, state.id, result_token})

      # Forward to next nodes
      Enum.each(state.next_nodes, fn next_node_id ->
        send(state.engine_pid, {:forward_token, next_node_id, result_token})
      end)

      new_state = %{state | status: :completed, waiting_token: nil}
      {:reply, :ok, new_state}
    else
      Logger.warning("UserTask[#{state.id}] triggered but not in waiting state")
      {:reply, {:error, :not_waiting}, state}
    end
  end

  defp via_tuple(id) do
    {:via, Registry, {BpmnWorkflow.NodeRegistry, {:user_task, id}}}
  end
end