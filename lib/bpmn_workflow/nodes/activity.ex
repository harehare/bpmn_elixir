defmodule BpmnWorkflow.Nodes.Activity do
  @moduledoc """
  Activity node - performs work in the workflow.
  Runs as an independent GenServer worker.
  Supports multiple BPMN activity types:
  - :user_task - waits for user input via API
  - :service_task - executes a function automatically
  - :script_task - executes a script/lambda
  - :manual_task - waits for manual confirmation
  """

  use GenServer
  require Logger

  @activity_types [:user_task, :service_task, :script_task, :manual_task]

  defstruct [
    :id,
    :name,
    :next_nodes,
    :engine_pid,
    :activity_type,
    :work_fn,
    :form_fields,
    :waiting_tokens,
    :script
  ]

  # Client API

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
  end

  def execute(id, token) do
    GenServer.cast(via_tuple(id), {:execute, token})
  end

  @doc """
  Completes a user task or manual task with the provided data.
  This is called from the API when a user submits their input.
  """
  def complete(id, token_id, user_data) do
    GenServer.call(via_tuple(id), {:complete, token_id, user_data})
  end

  @doc """
  Gets the current waiting tokens for this activity.
  """
  def get_waiting_tokens(id) do
    GenServer.call(via_tuple(id), :get_waiting_tokens)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    activity_type = Keyword.get(opts, :activity_type, :service_task)

    unless activity_type in @activity_types do
      raise ArgumentError, "Invalid activity_type: #{activity_type}. Must be one of #{inspect(@activity_types)}"
    end

    state = %__MODULE__{
      id: opts[:id],
      name: opts[:name] || "Activity",
      next_nodes: opts[:next_nodes] || [],
      engine_pid: opts[:engine_pid],
      activity_type: activity_type,
      work_fn: opts[:work_fn] || (&default_work/1),
      form_fields: opts[:form_fields] || [],
      waiting_tokens: %{},
      script: opts[:script]
    }

    Logger.info("Activity[#{state.id}] initialized: #{state.name} (type: #{activity_type})")
    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, token}, state) do
    Logger.info("Activity[#{state.id}] executing: #{state.name} (type: #{state.activity_type})")

    # Update token position
    updated_token = BpmnWorkflow.Token.move_to(token, state.id)

    case state.activity_type do
      :user_task ->
        handle_user_task(state, updated_token)

      :manual_task ->
        handle_manual_task(state, updated_token)

      :service_task ->
        handle_service_task(state, updated_token)

      :script_task ->
        handle_script_task(state, updated_token)
    end
  end

  @impl true
  def handle_call({:complete, token_id, user_data}, _from, state) do
    case Map.get(state.waiting_tokens, token_id) do
      nil ->
        Logger.warning("Activity[#{state.id}] token #{token_id} not found")
        {:reply, {:error, :token_not_found}, state}

      token ->
        Logger.info("Activity[#{state.id}] completing #{state.activity_type} for token #{token_id}")

        # Update token with user data
        completed_token = BpmnWorkflow.Token.update_data(token, user_data)

        # Remove from waiting tokens
        new_waiting = Map.delete(state.waiting_tokens, token_id)

        # Notify engine that task is completed
        send(state.engine_pid, {:activity_completed, state.id, completed_token})

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
          timestamp: token.timestamp,
          activity_type: state.activity_type,
          form_fields: state.form_fields
        }
      end)

    {:reply, tokens, state}
  end

  # Private functions - Activity type handlers

  defp handle_user_task(state, token) do
    Logger.info("Activity[#{state.id}] waiting for user input for token #{token.id}")

    # Store token in waiting state
    new_waiting = Map.put(state.waiting_tokens, token.id, token)

    # Notify engine that we're waiting
    send(state.engine_pid, {:node_executed, state.id, token})
    send(state.engine_pid, {:activity_waiting, state.id, token})

    {:noreply, %{state | waiting_tokens: new_waiting}}
  end

  defp handle_manual_task(state, token) do
    Logger.info("Activity[#{state.id}] waiting for manual confirmation for token #{token.id}")

    # Store token in waiting state
    new_waiting = Map.put(state.waiting_tokens, token.id, token)

    # Notify engine that we're waiting
    send(state.engine_pid, {:node_executed, state.id, token})
    send(state.engine_pid, {:activity_waiting, state.id, token})

    {:noreply, %{state | waiting_tokens: new_waiting}}
  end

  defp handle_service_task(state, token) do
    # Perform work automatically
    result_token =
      try do
        state.work_fn.(token)
      rescue
        error ->
          Logger.error("Activity[#{state.id}] work function failed: #{inspect(error)}")
          # Add error to token data
          BpmnWorkflow.Token.update_data(token, %{error: inspect(error)})
      end

    Logger.info("Activity[#{state.id}] completed service task")

    # Notify engine
    send(state.engine_pid, {:node_executed, state.id, result_token})

    # Forward to next nodes
    Enum.each(state.next_nodes, fn next_node_id ->
      send(state.engine_pid, {:forward_token, next_node_id, result_token})
    end)

    {:noreply, state}
  end

  defp handle_script_task(state, token) do
    result_token =
      if state.script do
        try do
          # Execute script (could be an anonymous function or code string)
          result =
            case state.script do
              script when is_function(script, 1) -> script.(token.data)
              script when is_binary(script) -> execute_script(script, token.data)
              _ -> token.data
            end

          BpmnWorkflow.Token.update_data(token, result)
        rescue
          error ->
            Logger.error("Activity[#{state.id}] script execution failed: #{inspect(error)}")
            BpmnWorkflow.Token.update_data(token, %{error: inspect(error)})
        end
      else
        Logger.warning("Activity[#{state.id}] no script provided, passing through")
        token
      end

    Logger.info("Activity[#{state.id}] completed script task")

    # Notify engine
    send(state.engine_pid, {:node_executed, state.id, result_token})

    # Forward to next nodes
    Enum.each(state.next_nodes, fn next_node_id ->
      send(state.engine_pid, {:forward_token, next_node_id, result_token})
    end)

    {:noreply, state}
  end

  defp default_work(token) do
    # Default behavior: just pass the token through
    token
  end

  defp execute_script(_script, data) do
    # TODO: Implement safe script execution (e.g., using Code.eval_string with sandbox)
    # For now, just return the data as-is
    Logger.warning("Script execution from string is not yet implemented")
    data
  end

  defp via_tuple(id) do
    {:via, Registry, {BpmnWorkflow.NodeRegistry, {:activity, id}}}
  end
end
