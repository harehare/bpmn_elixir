defmodule BpmnWorkflowWeb.UserTaskController do
  @moduledoc """
  REST API controller for UserTask operations.
  """

  use Plug.Router
  require Logger

  plug(:match)
  plug(:dispatch)

  @doc """
  GET /api/user_tasks/:workflow_id
  List all waiting user tasks for a workflow
  """
  get "/:workflow_id" do
    workflow_id = conn.path_params["workflow_id"]

    case BpmnWorkflow.UserTaskAPI.list_waiting_tasks(workflow_id) do
      {:ok, tasks} ->
        json_response(conn, 200, %{
          success: true,
          workflow_id: workflow_id,
          tasks: tasks
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
  GET /api/user_tasks/:workflow_id/:node_id
  List waiting tasks for a specific user task node
  """
  get "/:workflow_id/:node_id" do
    workflow_id = conn.path_params["workflow_id"]
    node_id = conn.path_params["node_id"]

    case BpmnWorkflow.UserTaskAPI.list_waiting_tasks(workflow_id, node_id) do
      {:ok, tasks} ->
        json_response(conn, 200, %{
          success: true,
          workflow_id: workflow_id,
          node_id: node_id,
          tasks: tasks
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  POST /api/user_tasks/:workflow_id/:node_id/:token_id/complete
  Complete a user task with provided data

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
      "UserTaskController: Completing task #{node_id} for token #{token_id} with data: #{inspect(user_data)}"
    )

    case BpmnWorkflow.UserTaskAPI.complete_task(workflow_id, node_id, token_id, user_data) do
      {:ok, token} ->
        json_response(conn, 200, %{
          success: true,
          message: "Task completed successfully",
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
