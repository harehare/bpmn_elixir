defmodule BpmnWorkflow.Engine do
  @moduledoc """
  WorkflowEngine - coordinates the execution of BPMN workflows.
  Manages node lifecycle and token routing.
  Maintains workflow state and history.
  """

  use GenServer
  require Logger

  defstruct [
    :workflow_id,
    :workflow_execution_id,
    :nodes,
    :start_node_id,
    :active_tokens,
    :completed_tokens,
    :waiting_tokens,
    :execution_history,
    :status,
    :node_execution_ids
  ]

  # Client API

  def start_link(opts) do
    workflow_id = Keyword.fetch!(opts, :workflow_id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(workflow_id))
  end

  def add_node(workflow_id, node_type, node_opts) do
    GenServer.call(via_tuple(workflow_id), {:add_node, node_type, node_opts})
  end

  def start_workflow(workflow_id, initial_data \\ %{}) do
    GenServer.call(via_tuple(workflow_id), {:start_workflow, initial_data})
  end

  def get_state(workflow_id) do
    GenServer.call(via_tuple(workflow_id), :get_state)
  end

  def get_status(workflow_id) do
    GenServer.call(via_tuple(workflow_id), :get_status)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    workflow_id = Keyword.fetch!(opts, :workflow_id)
    workflow_execution_id = Keyword.get(opts, :workflow_execution_id)
    start_node_id = Keyword.get(opts, :start_node_id)

    state = %__MODULE__{
      workflow_id: workflow_id,
      workflow_execution_id: workflow_execution_id,
      nodes: %{},
      start_node_id: start_node_id,
      active_tokens: [],
      completed_tokens: [],
      waiting_tokens: %{},
      execution_history: [],
      status: :initialized,
      node_execution_ids: %{}
    }

    Logger.info("WorkflowEngine[#{workflow_id}] initialized")
    {:ok, state}
  end

  @impl true
  def handle_call({:add_node, node_type, node_opts}, _from, state) do
    node_id = Keyword.fetch!(node_opts, :id)

    # Add engine_pid to node options
    node_opts_with_engine = Keyword.put(node_opts, :engine_pid, self())

    # Start the node worker
    result =
      case node_type do
        :start_event ->
          DynamicSupervisor.start_child(
            BpmnWorkflow.NodeSupervisor,
            {BpmnWorkflow.Nodes.StartEvent, node_opts_with_engine}
          )

        :end_event ->
          DynamicSupervisor.start_child(
            BpmnWorkflow.NodeSupervisor,
            {BpmnWorkflow.Nodes.EndEvent, node_opts_with_engine}
          )

        :activity ->
          DynamicSupervisor.start_child(
            BpmnWorkflow.NodeSupervisor,
            {BpmnWorkflow.Nodes.Activity, node_opts_with_engine}
          )

        :gateway ->
          DynamicSupervisor.start_child(
            BpmnWorkflow.NodeSupervisor,
            {BpmnWorkflow.Nodes.Gateway, node_opts_with_engine}
          )

        :user_task ->
          DynamicSupervisor.start_child(
            BpmnWorkflow.NodeSupervisor,
            {BpmnWorkflow.Nodes.UserTask, node_opts_with_engine}
          )

        _ ->
          {:error, :unknown_node_type}
      end

    case result do
      {:ok, _pid} ->
        updated_nodes = Map.put(state.nodes, node_id, node_type)
        new_state = %{state | nodes: updated_nodes}
        Logger.info("WorkflowEngine[#{state.workflow_id}] added node #{node_id} (#{node_type})")
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Failed to add node #{node_id}: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:start_workflow, initial_data}, _from, state) do
    if state.start_node_id do
      # Create initial token
      token = BpmnWorkflow.Token.new(initial_data)

      Logger.info("WorkflowEngine[#{state.workflow_id}] starting workflow with token #{token.id}")

      # Send token to start node
      send(self(), {:forward_token, state.start_node_id, token})

      new_state = %{state | active_tokens: [token], status: :running}
      {:reply, {:ok, token.id}, new_state}
    else
      {:reply, {:error, :no_start_node}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      workflow_id: state.workflow_id,
      status: state.status,
      active_tokens: length(state.active_tokens),
      completed_tokens: length(state.completed_tokens),
      total_nodes: map_size(state.nodes)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({:forward_token, node_id, token}, state) do
    Logger.info("WorkflowEngine[#{state.workflow_id}] forwarding token #{token.id} to #{node_id}")

    # Track node execution start
    node_type = Map.get(state.nodes, node_id)
    node_execution_id = track_node_start(state, node_id, node_type, token)

    # Store node_execution_id for later tracking
    key = {node_id, token.id}
    new_node_execution_ids = Map.put(state.node_execution_ids, key, node_execution_id)

    # Route token to the appropriate node type
    case node_type do
      :start_event -> BpmnWorkflow.Nodes.StartEvent.execute(node_id, token)
      :end_event -> BpmnWorkflow.Nodes.EndEvent.execute(node_id, token)
      :activity -> BpmnWorkflow.Nodes.Activity.execute(node_id, token)
      :gateway -> BpmnWorkflow.Nodes.Gateway.execute(node_id, token)
      :user_task -> BpmnWorkflow.Nodes.UserTask.execute(node_id, token)
      nil -> Logger.warning("WorkflowEngine[#{state.workflow_id}] unknown node: #{node_id}")
    end

    {:noreply, %{state | node_execution_ids: new_node_execution_ids}}
  end

  @impl true
  def handle_info({:node_executed, node_id, token}, state) do
    Logger.info("WorkflowEngine[#{state.workflow_id}] node #{node_id} executed")

    # Track node execution completion
    key = {node_id, token.id}
    if node_execution_id = Map.get(state.node_execution_ids, key) do
      track_node_complete(node_execution_id, token.data)
    end

    # Add to execution history
    history_entry = {DateTime.utc_now(), node_id, token.id}
    new_history = [history_entry | state.execution_history]

    new_state = %{state | execution_history: new_history}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:user_task_waiting, node_id, token}, state) do
    Logger.info("WorkflowEngine[#{state.workflow_id}] token #{token.id} waiting at user task #{node_id}")

    # Track node execution waiting
    key = {node_id, token.id}
    if node_execution_id = Map.get(state.node_execution_ids, key) do
      track_node_waiting(node_execution_id)
    end

    # Move token from active to waiting
    new_active = Enum.reject(state.active_tokens, fn t -> t.id == token.id end)
    new_waiting = Map.put(state.waiting_tokens, token.id, {node_id, token})

    # Update status if no more active tokens but still have waiting tokens
    new_status =
      cond do
        length(new_active) == 0 and map_size(new_waiting) > 0 -> :waiting
        length(new_active) == 0 and map_size(new_waiting) == 0 -> :completed
        true -> state.status
      end

    new_state = %{
      state
      | active_tokens: new_active,
        waiting_tokens: new_waiting,
        status: new_status
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:user_task_completed, node_id, token}, state) do
    Logger.info("WorkflowEngine[#{state.workflow_id}] user task #{node_id} completed for token #{token.id}")

    # Remove token from waiting
    new_waiting = Map.delete(state.waiting_tokens, token.id)

    # Add token back to active (it will be moved by the next node)
    new_active = [token | state.active_tokens]

    new_state = %{
      state
      | waiting_tokens: new_waiting,
        active_tokens: new_active,
        status: :running
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:workflow_completed, _node_id, token}, state) do
    Logger.info("WorkflowEngine[#{state.workflow_id}] workflow completed for token #{token.id}")

    # Move token from active to completed
    new_active = Enum.reject(state.active_tokens, fn t -> t.id == token.id end)
    new_completed = [token | state.completed_tokens]

    # Update status if no more active or waiting tokens
    new_status =
      if length(new_active) == 0 and map_size(state.waiting_tokens) == 0,
        do: :completed,
        else: state.status

    new_state = %{
      state
      | active_tokens: new_active,
        completed_tokens: new_completed,
        status: new_status
    }

    if new_status == :completed do
      Logger.info("WorkflowEngine[#{state.workflow_id}] all tokens completed")
    end

    {:noreply, new_state}
  end

  defp via_tuple(workflow_id) do
    {:via, Registry, {BpmnWorkflow.EngineRegistry, workflow_id}}
  end

  # Node execution tracking helpers

  defp track_node_start(state, node_id, node_type, token) do
    case BpmnWorkflow.NodeExecutionTracker.start_execution(%{
           workflow_id: state.workflow_id,
           workflow_execution_id: state.workflow_execution_id,
           token_id: token.id,
           node_id: node_id,
           node_type: to_string(node_type || :unknown),
           input_data: token.data
         }) do
      {:ok, node_execution} -> node_execution.id
      {:error, _} -> nil
    end
  end

  defp track_node_complete(node_execution_id, output_data) do
    BpmnWorkflow.NodeExecutionTracker.complete_execution(node_execution_id, output_data)
  end

  defp track_node_waiting(node_execution_id) do
    BpmnWorkflow.NodeExecutionTracker.mark_waiting(node_execution_id)
  end
end
