defmodule BpmnWorkflowWeb.NodeExecutionController do
  @moduledoc """
  REST API controller for Node Execution tracking and history.
  """

  use Plug.Router
  require Logger

  alias BpmnWorkflow.NodeExecutionTracker

  plug(:match)
  plug(:dispatch)

  @doc """
  GET /api/node_executions/workflow/:workflow_id
  List all node executions for a workflow
  """
  get "/workflow/:workflow_id" do
    workflow_id = conn.path_params["workflow_id"]
    params = fetch_query_params(conn).query_params

    status =
      if status_str = Map.get(params, "status") do
        String.to_existing_atom(status_str)
      end

    limit =
      if limit_str = Map.get(params, "limit") do
        case Integer.parse(limit_str) do
          {n, _} -> n
          :error -> nil
        end
      end

    opts = []
    opts = if status, do: Keyword.put(opts, :status, status), else: opts
    opts = if limit, do: Keyword.put(opts, :limit, limit), else: opts

    case NodeExecutionTracker.list_by_workflow(workflow_id, opts) do
      {:ok, executions} ->
        json_response(conn, 200, %{
          success: true,
          executions: Enum.map(executions, &serialize_node_execution/1)
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/node_executions/workflow/:workflow_id/token/:token_id
  List node executions for a specific token
  """
  get "/workflow/:workflow_id/token/:token_id" do
    workflow_id = conn.path_params["workflow_id"]
    token_id = conn.path_params["token_id"]

    case NodeExecutionTracker.list_by_token(workflow_id, token_id) do
      {:ok, executions} ->
        json_response(conn, 200, %{
          success: true,
          executions: Enum.map(executions, &serialize_node_execution/1)
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/node_executions/workflow/:workflow_id/node/:node_id
  List executions for a specific node
  """
  get "/workflow/:workflow_id/node/:node_id" do
    workflow_id = conn.path_params["workflow_id"]
    node_id = conn.path_params["node_id"]
    params = fetch_query_params(conn).query_params

    limit =
      if limit_str = Map.get(params, "limit") do
        case Integer.parse(limit_str) do
          {n, _} -> n
          :error -> nil
        end
      end

    opts = if limit, do: [limit: limit], else: []

    case NodeExecutionTracker.list_by_node(workflow_id, node_id, opts) do
      {:ok, executions} ->
        json_response(conn, 200, %{
          success: true,
          executions: Enum.map(executions, &serialize_node_execution/1)
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/node_executions/workflow/:workflow_id/statistics
  Get execution statistics for a workflow
  """
  get "/workflow/:workflow_id/statistics" do
    workflow_id = conn.path_params["workflow_id"]

    case NodeExecutionTracker.get_statistics(workflow_id) do
      {:ok, stats} ->
        json_response(conn, 200, %{
          success: true,
          statistics: stats
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/node_executions/:id
  Get a specific node execution by ID
  """
  get "/:id" do
    id = conn.path_params["id"]

    case NodeExecutionTracker.get_execution(id) do
      {:ok, execution} ->
        json_response(conn, 200, %{
          success: true,
          execution: serialize_node_execution(execution)
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Node execution not found"
        })
    end
  end

  match _ do
    json_response(conn, 404, %{
      success: false,
      error: "Not found"
    })
  end

  # Helper functions

  defp serialize_node_execution(execution) do
    %{
      id: execution.id,
      workflow_id: execution.workflow_id,
      workflow_execution_id: execution.workflow_execution_id,
      token_id: execution.token_id,
      node_id: execution.node_id,
      node_type: execution.node_type,
      status: execution.status,
      input_data: execution.input_data,
      output_data: execution.output_data,
      error_message: execution.error_message,
      started_at: execution.started_at,
      completed_at: execution.completed_at,
      duration_ms: execution.duration_ms,
      inserted_at: execution.inserted_at,
      updated_at: execution.updated_at
    }
  end

  defp json_response(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
