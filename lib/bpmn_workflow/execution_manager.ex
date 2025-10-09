defmodule BpmnWorkflow.ExecutionManager do
  @moduledoc """
  Manages BPMN workflow execution state in the database.
  Bridges the gap between the in-memory Engine and persistent storage.
  """

  import Ecto.Query
  alias BpmnWorkflow.Repo
  alias BpmnWorkflow.Schemas.{WorkflowExecution, WorkflowDefinition}
  alias BpmnWorkflow.{Engine, Builder}

  @doc """
  Creates a new workflow execution from a definition.
  """
  def create_execution(definition_id, workflow_id, initial_data \\ %{}) do
    with {:ok, definition} <- BpmnWorkflow.DefinitionManager.get_definition(definition_id) do
      attrs = %{
        workflow_id: workflow_id,
        workflow_definition_id: definition_id,
        status: :initialized,
        initial_data: initial_data,
        current_state: %{}
      }

      case Repo.insert(WorkflowExecution.changeset(%WorkflowExecution{}, attrs)) do
        {:ok, execution} ->
          # Start the in-memory workflow engine with execution_id
          case start_engine_from_definition(workflow_id, execution.id, definition, initial_data) do
            {:ok, _token_id} ->
              {:ok, execution}

            {:error, reason} ->
              # Update execution with error
              execution
              |> WorkflowExecution.update_state_changeset(%{
                status: :failed,
                error: inspect(reason)
              })
              |> Repo.update()

              {:error, reason}
          end

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc """
  Gets a workflow execution by ID.
  """
  def get_execution(id) do
    case Repo.get(WorkflowExecution, id) do
      nil -> {:error, :not_found}
      execution -> {:ok, execution}
    end
  end

  @doc """
  Gets a workflow execution by workflow_id.
  """
  def get_execution_by_workflow_id(workflow_id) do
    case Repo.get_by(WorkflowExecution, workflow_id: workflow_id) do
      nil -> {:error, :not_found}
      execution -> {:ok, execution}
    end
  end

  @doc """
  Lists all workflow executions.
  """
  def list_executions(opts \\ []) do
    status = Keyword.get(opts, :status)
    definition_id = Keyword.get(opts, :definition_id)

    query = WorkflowExecution

    query =
      if status do
        from e in query, where: e.status == ^status
      else
        query
      end

    query =
      if definition_id do
        from e in query, where: e.workflow_definition_id == ^definition_id
      else
        query
      end

    {:ok, Repo.all(query)}
  end

  @doc """
  Synchronizes the in-memory engine state to the database.
  """
  def sync_execution_state(workflow_id) do
    with {:ok, execution} <- get_execution_by_workflow_id(workflow_id),
         {:ok, engine_state} <- get_engine_state(workflow_id) do
      attrs = %{
        status: engine_state.status,
        current_state: serialize_state(engine_state)
      }

      execution
      |> WorkflowExecution.update_state_changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Restores a workflow execution from the database to the in-memory engine.
  """
  def restore_execution(id) do
    with {:ok, execution} <- get_execution(id),
         {:ok, definition} <- BpmnWorkflow.DefinitionManager.get_definition(execution.workflow_definition_id) do
      # Check if engine is already running
      case get_engine_state(execution.workflow_id) do
        {:ok, _state} ->
          {:ok, execution}

        {:error, :workflow_not_found} ->
          # Restore the engine from definition
          start_engine_from_definition(
            execution.workflow_id,
            execution.id,
            definition,
            execution.initial_data
          )

          {:ok, execution}
      end
    end
  end

  @doc """
  Deletes a workflow execution.
  """
  def delete_execution(id) do
    with {:ok, execution} <- get_execution(id) do
      # TODO: Stop the in-memory engine if running
      Repo.delete(execution)
    end
  end

  # Private functions

  defp start_engine_from_definition(workflow_id, execution_id, definition, initial_data) do
    %{"start_node_id" => start_node_id, "nodes" => nodes} = definition.definition

    # Create workflow engine with execution_id
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        BpmnWorkflow.EngineSupervisor,
        {BpmnWorkflow.Engine,
         workflow_id: workflow_id,
         workflow_execution_id: execution_id,
         start_node_id: start_node_id}
      )

    # Add all nodes
    Enum.each(nodes, fn node ->
      add_node_from_definition(workflow_id, node)
    end)

    # Start workflow
    Engine.start_workflow(workflow_id, initial_data)
  end

  defp add_node_from_definition(workflow_id, node) do
    node_type = String.to_atom(node["type"])
    opts = build_node_opts(node)

    case node_type do
      :start_event -> Builder.add_start_event(workflow_id, node["id"], opts)
      :end_event -> Builder.add_end_event(workflow_id, node["id"], opts)
      :activity -> Builder.add_activity(workflow_id, node["id"], opts)
      :gateway -> Builder.add_gateway(workflow_id, node["id"], opts)
      # For backward compatibility, treat user_task as activity with activity_type: :user_task
      :user_task -> Builder.add_activity(workflow_id, node["id"], Keyword.put(opts, :activity_type, :user_task))
      _ -> :ok
    end
  end

  defp build_node_opts(node) do
    opts = []

    opts =
      if Map.has_key?(node, "name") do
        Keyword.put(opts, :name, node["name"])
      else
        opts
      end

    opts =
      if Map.has_key?(node, "next_nodes") do
        Keyword.put(opts, :next_nodes, node["next_nodes"])
      else
        opts
      end

    opts =
      if Map.has_key?(node, "form_fields") do
        Keyword.put(opts, :form_fields, node["form_fields"])
      else
        opts
      end

    opts =
      if Map.has_key?(node, "activity_type") do
        Keyword.put(opts, :activity_type, String.to_atom(node["activity_type"]))
      else
        opts
      end

    opts =
      if Map.has_key?(node, "script") do
        Keyword.put(opts, :script, node["script"])
      else
        opts
      end

    opts
  end

  defp get_engine_state(workflow_id) do
    try do
      state = Engine.get_state(workflow_id)
      {:ok, state}
    catch
      :exit, _ -> {:error, :workflow_not_found}
    end
  end

  defp serialize_state(engine_state) do
    %{
      workflow_id: engine_state.workflow_id,
      status: engine_state.status,
      nodes: Map.keys(engine_state.nodes),
      active_tokens:
        Enum.map(engine_state.active_tokens, fn token ->
          %{
            id: token.id,
            current_node: token.current_node,
            data: token.data
          }
        end),
      waiting_tokens:
        engine_state.waiting_tokens
        |> Enum.map(fn {token_id, {node_id, token}} ->
          %{token_id: token_id, node_id: node_id, data: token.data}
        end),
      completed_tokens: length(engine_state.completed_tokens)
    }
  end
end
