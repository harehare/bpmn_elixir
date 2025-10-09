defmodule BpmnWorkflow.ActivityAPI do
  @moduledoc """
  API module for interacting with activities in BPMN workflows.
  Provides functions to list waiting activities and complete them with user input.
  Supports user tasks, manual tasks, and other activity types that require external completion.
  """

  require Logger

  @doc """
  Gets all waiting activities for a specific workflow.
  Returns a list of activities waiting for user input or manual completion.
  """
  def list_waiting_activities(workflow_id) do
    case get_engine_state(workflow_id) do
      {:ok, state} ->
        activities =
          state.waiting_tokens
          |> Enum.map(fn {token_id, {node_id, token}} ->
            # Get activity details
            activity_info = get_activity_info(node_id)

            %{
              token_id: token_id,
              node_id: node_id,
              activity_name: activity_info.name,
              activity_type: activity_info.activity_type,
              form_fields: activity_info.form_fields,
              current_data: token.data,
              waiting_since: token.timestamp
            }
          end)

        {:ok, activities}

      error ->
        error
    end
  end

  @doc """
  Gets waiting activities for a specific activity node.
  """
  def list_waiting_activities(workflow_id, node_id) do
    case list_waiting_activities(workflow_id) do
      {:ok, activities} ->
        filtered = Enum.filter(activities, fn activity -> activity.node_id == node_id end)
        {:ok, filtered}

      error ->
        error
    end
  end

  @doc """
  Completes an activity with the provided data.

  ## Parameters
    - workflow_id: The ID of the workflow
    - node_id: The ID of the activity node
    - token_id: The ID of the token waiting at this activity
    - user_data: Map containing the user's input data

  ## Returns
    - {:ok, token} on success
    - {:error, reason} on failure
  """
  def complete_activity(workflow_id, node_id, token_id, user_data) do
    Logger.info("ActivityAPI: Completing activity #{node_id} for token #{token_id} in workflow #{workflow_id}")

    # Validate that the token is actually waiting at this node
    case validate_waiting_activity(workflow_id, node_id, token_id) do
      :ok ->
        BpmnWorkflow.Nodes.Activity.complete(node_id, token_id, user_data)

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

  defp get_activity_info(node_id) do
    try do
      waiting_tokens = BpmnWorkflow.Nodes.Activity.get_waiting_tokens(node_id)

      # Extract activity info from the first waiting token (they share the same activity metadata)
      case waiting_tokens do
        [first | _] ->
          %{
            name: node_id,
            activity_type: first.activity_type,
            form_fields: first.form_fields
          }

        [] ->
          %{name: node_id, activity_type: :unknown, form_fields: []}
      end
    catch
      :exit, _ ->
        %{name: node_id, activity_type: :unknown, form_fields: []}
    end
  end

  defp validate_waiting_activity(workflow_id, node_id, token_id) do
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
