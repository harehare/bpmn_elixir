defmodule BpmnWorkflowWeb.WorkflowController do
  @moduledoc """
  REST API controller for Workflow operations.
  """

  use Plug.Router
  require Logger

  plug(:match)
  plug(:dispatch)

  @doc """
  GET /api/workflows/:workflow_id/status
  Get workflow status
  """
  get "/:workflow_id/status" do
    workflow_id = conn.path_params["workflow_id"]

    try do
      status = BpmnWorkflow.Engine.get_status(workflow_id)

      json_response(conn, 200, %{
        success: true,
        workflow: status
      })
    catch
      :exit, _ ->
        json_response(conn, 404, %{
          success: false,
          error: "Workflow not found"
        })
    end
  end

  @doc """
  GET /api/workflows/:workflow_id/state
  Get full workflow state
  """
  get "/:workflow_id/state" do
    workflow_id = conn.path_params["workflow_id"]

    try do
      state = BpmnWorkflow.Engine.get_state(workflow_id)

      # Convert state to JSON-friendly format
      state_data = %{
        workflow_id: state.workflow_id,
        status: state.status,
        nodes: Map.keys(state.nodes),
        active_tokens:
          Enum.map(state.active_tokens, fn token ->
            %{
              id: token.id,
              current_node: token.current_node,
              data: token.data,
              timestamp: token.timestamp
            }
          end),
        waiting_tokens:
          state.waiting_tokens
          |> Enum.map(fn {token_id, {node_id, token}} ->
            %{
              token_id: token_id,
              node_id: node_id,
              data: token.data,
              timestamp: token.timestamp
            }
          end),
        completed_tokens:
          Enum.map(state.completed_tokens, fn token ->
            %{
              id: token.id,
              current_node: token.current_node,
              data: token.data,
              timestamp: token.timestamp
            }
          end),
        execution_history:
          Enum.take(state.execution_history, 50)
          |> Enum.map(fn {datetime, node_id, token_id} ->
            %{
              timestamp: datetime,
              node_id: node_id,
              token_id: token_id
            }
          end)
      }

      json_response(conn, 200, %{
        success: true,
        workflow: state_data
      })
    catch
      :exit, _ ->
        json_response(conn, 404, %{
          success: false,
          error: "Workflow not found"
        })
    end
  end

  @doc """
  GET /api/workflows/:workflow_id/tokens/:token_id
  Get token status
  """
  get "/:workflow_id/tokens/:token_id" do
    workflow_id = conn.path_params["workflow_id"]
    token_id = conn.path_params["token_id"]

    case BpmnWorkflow.UserTaskAPI.get_token_status(workflow_id, token_id) do
      {:ok, token_status} ->
        response_data = %{
          status: token_status.status,
          node_id: token_status.node_id,
          token: %{
            id: token_status.token.id,
            current_node: token_status.token.current_node,
            data: token_status.token.data,
            timestamp: token_status.token.timestamp
          }
        }

        json_response(conn, 200, %{
          success: true,
          token: response_data
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
