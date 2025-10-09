defmodule BpmnWorkflowWeb.ActivityController do
  @moduledoc """
  REST API controller for Activity operations.
  Handles all activity types including user tasks, manual tasks, and service tasks.
  """

  use Plug.Router
  require Logger

  plug(:match)
  plug(:dispatch)

  @doc """
  GET /api/activities/:workflow_id
  List all waiting activities for a workflow
  """
  get "/:workflow_id" do
    workflow_id = conn.path_params["workflow_id"]

    case BpmnWorkflow.ActivityAPI.list_waiting_activities(workflow_id) do
      {:ok, activities} ->
        json_response(conn, 200, %{
          success: true,
          workflow_id: workflow_id,
          activities: activities
        })

      {:error, :workflow_not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Workflow not found"
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/activities/:workflow_id/:node_id
  List waiting activities for a specific activity node
  """
  get "/:workflow_id/:node_id" do
    workflow_id = conn.path_params["workflow_id"]
    node_id = conn.path_params["node_id"]

    case BpmnWorkflow.ActivityAPI.list_waiting_activities(workflow_id, node_id) do
      {:ok, activities} ->
        json_response(conn, 200, %{
          success: true,
          workflow_id: workflow_id,
          node_id: node_id,
          activities: activities
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  POST /api/activities/:workflow_id/:node_id/:token_id/complete
  Complete an activity with provided data

  Body:
  {
    "data": {
      "field1": "value1",
      "field2": "value2"
    }
  }
  """
  post "/:workflow_id/:node_id/:token_id/complete" do
    workflow_id = conn.path_params["workflow_id"]
    node_id = conn.path_params["node_id"]
    token_id = conn.path_params["token_id"]

    user_data = get_in(conn.body_params, ["data"]) || %{}

    Logger.info(
      "ActivityController: Completing activity #{node_id} for token #{token_id} with data: #{inspect(user_data)}"
    )

    case BpmnWorkflow.ActivityAPI.complete_activity(workflow_id, node_id, token_id, user_data) do
      {:ok, token} ->
        json_response(conn, 200, %{
          success: true,
          message: "Activity completed successfully",
          token: %{
            id: token.id,
            current_node: token.current_node,
            data: token.data
          }
        })

      {:error, :token_not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Token not found"
        })

      {:error, :token_at_different_node} ->
        json_response(conn, 400, %{
          success: false,
          error: "Token is at a different node"
        })

      {:error, :token_not_waiting} ->
        json_response(conn, 400, %{
          success: false,
          error: "Token is not waiting for user input"
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/activities/:workflow_id/token/:token_id
  Get status of a specific token
  """
  get "/:workflow_id/token/:token_id" do
    workflow_id = conn.path_params["workflow_id"]
    token_id = conn.path_params["token_id"]

    case BpmnWorkflow.ActivityAPI.get_token_status(workflow_id, token_id) do
      {:ok, status} ->
        json_response(conn, 200, %{
          success: true,
          status: status
        })

      {:error, :token_not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Token not found"
        })

      {:error, :workflow_not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Workflow not found"
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  match _ do
    json_response(conn, 404, %{
      success: false,
      error: "Not found"
    })
  end

  defp json_response(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
