defmodule BpmnWorkflow.Nodes.UserTask do
  @moduledoc """
  UserTask node - waits for user input to continue the workflow.
  Runs as an independent GenServer worker.
  Pauses workflow execution until user completes the task via API.
  """

  use GenServer
  require Logger

  defstruct [:id, :name, :next_nodes, :engine_pid, :waiting_tokens, :form_fields]

  # Client API

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
  end

  def execute(id, token) do
    GenServer.cast(via_tuple(id), {:execute, token})
  end

  @doc """
  Completes a user task with the provided data.
  This is called from the API when a user submits their input.
  """
  def complete(id, token_id, user_data) do
    GenServer.call(via_tuple(id), {:complete, token_id, user_data})
  end

  @doc """
  Gets the current waiting tokens for this user task.
  """
  def get_waiting_tokens(id) do
    GenServer.call(via_tuple(id), :get_waiting_tokens)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: opts[:id],
      name: opts[:name] || "User Task",
      next_nodes: opts[:next_nodes] || [],
      engine_pid: opts[:engine_pid],
      waiting_tokens: %{},
      form_fields: opts[:form_fields] || []
    }

    Logger.info("UserTask[#{state.id}] initialized: #{state.name}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, token}, state) do
    Logger.info("UserTask[#{state.id}] waiting for user input for token #{token.id}")

    # Update token position
    updated_token = BpmnWorkflow.Token.move_to(token, state.id)

    # Store token in waiting state
    new_waiting = Map.put(state.waiting_tokens, token.id, updated_token)

    # Notify engine that we're waiting
    send(state.engine_pid, {:node_executed, state.id, updated_token})
    send(state.engine_pid, {:user_task_waiting, state.id, updated_token})

    {:noreply, %{state | waiting_tokens: new_waiting}}
  end

  @impl true
  def handle_call({:complete, token_id, user_data}, _from, state) do
    case Map.get(state.waiting_tokens, token_id) do
      nil ->
        Logger.warning("UserTask[#{state.id}] token #{token_id} not found")
        {:reply, {:error, :token_not_found}, state}

      token ->
        Logger.info("UserTask[#{state.id}] completing task for token #{token_id}")

        # Update token with user data
        completed_token = BpmnWorkflow.Token.update_data(token, user_data)

        # Remove from waiting tokens
        new_waiting = Map.delete(state.waiting_tokens, token_id)

        # Notify engine that task is completed
        send(state.engine_pid, {:user_task_completed, state.id, completed_token})

        # Forward to next nodes
        Enum.each(state.next_nodes, fn next_node_id ->
          send(state.engine_pid, {:forward_token, next_node_id, completed_token})
        end)

        {:reply, {:ok, completed_token}, %{state | waiting_tokens: new_waiting}}
    end
  end

  @impl true
  def handle_call(:get_waiting_tokens, _from, state) do
    tokens =
      state.waiting_tokens
      |> Map.values()
      |> Enum.map(fn token ->
        %{
          token_id: token.id,
          current_node: token.current_node,
          data: token.data,
          timestamp: token.timestamp
        }
      end)

    {:reply, tokens, state}
  end

  defp via_tuple(id) do
    {:via, Registry, {BpmnWorkflow.NodeRegistry, {:user_task, id}}}
  end
end
