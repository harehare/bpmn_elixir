defmodule BpmnWorkflowWeb.DefinitionController do
  @moduledoc """
  REST API controller for Workflow Definition operations.
  """

  use Plug.Router
  require Logger

  alias BpmnWorkflow.DefinitionManager

  plug(:match)
  plug(:dispatch)

  @doc """
  POST /api/definitions
  Create a new workflow definition
  """
  post "/" do
    case conn.body_params do
      %{"name" => _name, "definition" => _definition} = params ->
        case DefinitionManager.create_definition(params) do
          {:ok, definition} ->
            json_response(conn, 201, %{
              success: true,
              definition: serialize_definition(definition)
            })

          {:error, %Ecto.Changeset{} = changeset} ->
            errors = format_changeset_errors(changeset)

            json_response(conn, 422, %{
              success: false,
              errors: errors
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
          error: "name and definition are required"
        })
    end
  end

  @doc """
  GET /api/definitions
  List all workflow definitions
  """
  get "/" do
    params = fetch_query_params(conn).query_params
    active_only = Map.get(params, "active_only") == "true"

    case DefinitionManager.list_definitions(active_only: active_only) do
      {:ok, definitions} ->
        json_response(conn, 200, %{
          success: true,
          definitions: Enum.map(definitions, &serialize_definition/1)
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  GET /api/definitions/:id
  Get a workflow definition by ID
  """
  get "/:id" do
    id = conn.path_params["id"]

    case DefinitionManager.get_definition(id) do
      {:ok, definition} ->
        json_response(conn, 200, %{
          success: true,
          definition: serialize_definition(definition)
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Definition not found"
        })
    end
  end

  @doc """
  GET /api/definitions/by-name/:name
  Get a workflow definition by name (latest active version)
  """
  get "/by-name/:name" do
    name = conn.path_params["name"]
    params = fetch_query_params(conn).query_params
    version = Map.get(params, "version")

    version =
      if version do
        case Integer.parse(version) do
          {v, _} -> v
          :error -> nil
        end
      end

    case DefinitionManager.get_definition_by_name(name, version) do
      {:ok, definition} ->
        json_response(conn, 200, %{
          success: true,
          definition: serialize_definition(definition)
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Definition not found"
        })
    end
  end

  @doc """
  PUT /api/definitions/:id
  Update a workflow definition
  """
  put "/:id" do
    id = conn.path_params["id"]

    case DefinitionManager.update_definition(id, conn.body_params) do
      {:ok, definition} ->
        json_response(conn, 200, %{
          success: true,
          definition: serialize_definition(definition)
        })

      {:error, :not_found} ->
        json_response(conn, 404, %{
          success: false,
          error: "Definition not found"
        })

      {:error, %Ecto.Changeset{} = changeset} ->
        errors = format_changeset_errors(changeset)

        json_response(conn, 422, %{
          success: false,
          errors: errors
        })

      {:error, reason} ->
        json_response(conn, 500, %{
          success: false,
          error: inspect(reason)
        })
    end
  end

  @doc """
  DELETE /api/definitions/:id/deactivate
  Deactivate a workflow definition (soft delete)
  """
  delete "/:id/deactivate" do
    id = conn.path_params["id"]

    case DefinitionManager.deactivate_definition(id) do
      {:ok, definition} ->
        json_response(conn, 200, %{
          success: true,
          definition: serialize_definition(definition)
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
  end

  @doc """
  DELETE /api/definitions/:id
  Delete a workflow definition (hard delete)
  """
  delete "/:id" do
    id = conn.path_params["id"]

    case DefinitionManager.delete_definition(id) do
      {:ok, _definition} ->
        json_response(conn, 200, %{
          success: true,
          message: "Definition deleted"
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
  end

  match _ do
    json_response(conn, 404, %{
      success: false,
      error: "Not found"
    })
  end

  # Helper functions

  defp serialize_definition(definition) do
    %{
      id: definition.id,
      name: definition.name,
      description: definition.description,
      version: definition.version,
      definition: definition.definition,
      is_active: definition.is_active,
      inserted_at: definition.inserted_at,
      updated_at: definition.updated_at
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
