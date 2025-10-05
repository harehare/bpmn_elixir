defmodule BpmnWorkflow.UserTaskAPI do
  @moduledoc """
  API module for interacting with user tasks in BPMN workflows.
  Provides functions to list waiting tasks and complete them with user input.
  """

  require Logger

  @doc """
  Gets all waiting user tasks for a specific workflow.
  Returns a list of tasks waiting for user input.
  """
  def list_waiting_tasks(workflow_id) do
    case get_engine_state(workflow_id) do
      {:ok, state} ->
        tasks =
          state.waiting_tokens
          |> Enum.map(fn {token_id, {node_id, token}} ->
            # Get user task details
            task_info = get_user_task_info(node_id)

            %{
              token_id: token_id,
              node_id: node_id,
              task_name: task_info.name,
              form_fields: task_info.form_fields,
              current_data: token.data,
              waiting_since: token.timestamp
            }
          end)

        {:ok, tasks}

      error ->
        error
    end
  end

  @doc """
  Gets waiting tasks for a specific user task node.
  """
  def list_waiting_tasks(workflow_id, node_id) do
    case list_waiting_tasks(workflow_id) do
      {:ok, tasks} ->
        filtered = Enum.filter(tasks, fn task -> task.node_id == node_id end)
        {:ok, filtered}

      error ->
        error
    end
  end

  @doc """
  Completes a user task with the provided data.

  ## Parameters
    - workflow_id: The ID of the workflow
    - node_id: The ID of the user task node
    - token_id: The ID of the token waiting at this task
    - user_data: Map containing the user's input data

  ## Returns
    - {:ok, token} on success
    - {:error, reason} on failure
  """
  def complete_task(workflow_id, node_id, token_id, user_data) do
    Logger.info("UserTaskAPI: Completing task #{node_id} for token #{token_id} in workflow #{workflow_id}")

    # Validate that the token is actually waiting at this node
    case validate_waiting_task(workflow_id, node_id, token_id) do
      :ok ->
        BpmnWorkflow.Nodes.UserTask.complete(node_id, token_id, user_data)

      error ->
        error
    end
  end

  @doc """
  Gets the current status of a specific token in the workflow.
  """
  def get_token_status(workflow_id, token_id) do
    case get_engine_state(workflow_id) do
      {:ok, state} ->
        cond do
          # Check if token is waiting
          Map.has_key?(state.waiting_tokens, token_id) ->
            {node_id, token} = state.waiting_tokens[token_id]
            {:ok, %{status: :waiting, node_id: node_id, token: token}}

          # Check if token is active
          Enum.any?(state.active_tokens, fn t -> t.id == token_id end) ->
            token = Enum.find(state.active_tokens, fn t -> t.id == token_id end)
            {:ok, %{status: :active, node_id: token.current_node, token: token}}

          # Check if token is completed
          Enum.any?(state.completed_tokens, fn t -> t.id == token_id end) ->
            token = Enum.find(state.completed_tokens, fn t -> t.id == token_id end)
            {:ok, %{status: :completed, node_id: token.current_node, token: token}}

          true ->
            {:error, :token_not_found}
        end

      error ->
        error
    end
  end

  # Private functions

  defp get_engine_state(workflow_id) do
    try do
      state = BpmnWorkflow.Engine.get_state(workflow_id)
      {:ok, state}
    catch
      :exit, _ -> {:error, :workflow_not_found}
    end
  end

  defp get_user_task_info(node_id) do
    try do
      waiting_tokens = BpmnWorkflow.Nodes.UserTask.get_waiting_tokens(node_id)

      # Get task info from the GenServer state
      # For now, we'll return a basic structure
      %{
        name: node_id,
        form_fields: []
      }
    catch
      :exit, _ ->
        %{name: node_id, form_fields: []}
    end
  end

  defp validate_waiting_task(workflow_id, node_id, token_id) do
    case get_engine_state(workflow_id) do
      {:ok, state} ->
        case Map.get(state.waiting_tokens, token_id) do
          {^node_id, _token} ->
            :ok

          {other_node_id, _token} ->
            Logger.warning("Token #{token_id} is waiting at #{other_node_id}, not #{node_id}")
            {:error, :token_at_different_node}

          nil ->
            Logger.warning("Token #{token_id} is not waiting in workflow #{workflow_id}")
            {:error, :token_not_waiting}
        end

      error ->
        error
    end
  end
end
