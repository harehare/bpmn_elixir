defmodule BpmnWorkflowWeb.ExecutionController do
  @moduledoc """
  REST API controller for Workflow Execution operations.
  """

  use Plug.Router
  require Logger

  alias BpmnWorkflow.ExecutionManager

  plug(:match)
  plug(:dispatch)

  @doc """
  POST /api/executions
  Create and start a new workflow execution from a definition
  """
  post "/" do
    case conn.body_params do
      %{"definition_id" => definition_id, "workflow_id" => workflow_id} = params ->
        initial_data = Map.get(params, "initial_data", %{})

        case ExecutionManager.create_execution(definition_id, workflow_id, initial_data) do
          {:ok, execution} ->
            json_response(conn, 201, %{
              success: true,
              execution: serialize_execution(execution)
            })

          {:error, %Ecto.Changeset{} = changeset} ->
            errors = format_changeset_errors(changeset)

            json_response(conn, 422, %{
              success: false,
              errors: errors
            })

          {:error, :not_found} ->
            json_response(conn, 404, %{
              success: false,
              error: "Definition not found"
            })

          {:error, reason} ->
            json_response(conn, 500, %{
              success: false,
              error: inspect(reason)
            })
        end

      _ ->
        json_response(conn, 400, %{
          success: false,
          error: "definition_id and workflow_id are required"
        })
    end
  end

  @doc """
  GET /api/executions
  List all workflow executions
  """
  get "/" do
    params = fetch_query_params(conn).query_params
    status = Map.get(params, "status")
    definition_id = Map.get(params, "definition_id")

    opts = []
    opts = if status, do: Keyword.put(opts, :status, String.to_atom(status)), else: opts

    opts =
      if definition_id, do: Keyword.put(opts, :definition_id, definition_id), else: opts

    case ExecutionManager.list_executions(opts) do
      {:ok, executions} ->
        json_response(conn, 200, %{
          success: true,
          executions: Enum.map(executions, &serialize_execution/1)
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/executions/:id
  Get a workflow execution by ID
  """
  get "/:id" do
    id = conn.path_params["id"]

    case ExecutionManager.get_execution(id) do
      {:ok, execution} ->
        json_response(conn, 200, %{
          success: true,
          execution: serialize_execution(execution)
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Execution not found"
        })
    end
  end

  @doc """
  GET /api/executions/by-workflow-id/:workflow_id
  Get a workflow execution by workflow_id
  """
  get "/by-workflow-id/:workflow_id" do
    workflow_id = conn.path_params["workflow_id"]

    case ExecutionManager.get_execution_by_workflow_id(workflow_id) do
      {:ok, execution} ->
        json_response(conn, 200, %{
          success: true,
          execution: serialize_execution(execution)
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Execution not found"
        })
    end
  end

  @doc """
  POST /api/executions/:id/sync
  Sync the in-memory engine state to database
  """
  post "/:id/sync" do
    id = conn.path_params["id"]

    with {:ok, execution} <- ExecutionManager.get_execution(id),
         {:ok, updated_execution} <-
           ExecutionManager.sync_execution_state(execution.workflow_id) do
      json_response(conn, 200, %{
        success: true,
        execution: serialize_execution(updated_execution)
      })
    else
      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Execution not found"
        })

      {:error, :workflow_not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Engine not running for this execution"
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  POST /api/executions/:id/restore
  Restore a workflow execution to the in-memory engine
  """
  post "/:id/restore" do
    id = conn.path_params["id"]

    case ExecutionManager.restore_execution(id) do
      {:ok, execution} ->
        json_response(conn, 200, %{
          success: true,
          execution: serialize_execution(execution),
          message: "Execution restored to engine"
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Execution not found"
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  DELETE /api/executions/:id
  Delete a workflow execution
  """
  delete "/:id" do
    id = conn.path_params["id"]

    case ExecutionManager.delete_execution(id) do
      {:ok, _execution} ->
        json_response(conn, 200, %{
          success: true,
          message: "Execution deleted"
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Execution not found"
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

  # Helper functions

  defp serialize_execution(execution) do
    %{
      id: execution.id,
      workflow_id: execution.workflow_id,
      workflow_definition_id: execution.workflow_definition_id,
      status: execution.status,
      initial_data: execution.initial_data,
      current_state: execution.current_state,
      error: execution.error,
      inserted_at: execution.inserted_at,
      updated_at: execution.updated_at
    }
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp json_response(conn, status, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(data))
  end
end
