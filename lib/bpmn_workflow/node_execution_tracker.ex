defmodule BpmnWorkflow.NodeExecutionTracker do
  @moduledoc """
  Tracks and persists individual node execution events to the database.
  """

  import Ecto.Query
  alias BpmnWorkflow.Repo
  alias BpmnWorkflow.Schemas.NodeExecution

  @doc """
  Records the start of a node execution.
  """
  def start_execution(attrs) do
    attrs
    |> Map.put(:status, :executing)
    |> Map.put(:started_at, DateTime.utc_now())
    |> NodeExecution.create_changeset()
    |> Repo.insert()
  end

  @doc """
  Updates a node execution to completed status.
  """
  def complete_execution(node_execution_id, output_data \\ %{}) do
    with {:ok, node_execution} <- get_execution(node_execution_id) do
      node_execution
      |> NodeExecution.complete_changeset(%{
        status: :completed,
        output_data: output_data,
        completed_at: DateTime.utc_now()
      })
      |> Repo.update()
    end
  end

  @doc """
  Updates a node execution to failed status.
  """
  def fail_execution(node_execution_id, error_message) do
    with {:ok, node_execution} <- get_execution(node_execution_id) do
      node_execution
      |> NodeExecution.complete_changeset(%{
        status: :failed,
        error_message: error_message,
        completed_at: DateTime.utc_now()
      })
      |> Repo.update()
    end
  end

  @doc """
  Updates a node execution to waiting status (for user tasks).
  """
  def mark_waiting(node_execution_id) do
    with {:ok, node_execution} <- get_execution(node_execution_id) do
      node_execution
      |> NodeExecution.changeset(%{status: :waiting})
      |> Repo.update()
    end
  end

  @doc """
  Updates a node execution to skipped status (for conditional branches).
  """
  def mark_skipped(node_execution_id) do
    with {:ok, node_execution} <- get_execution(node_execution_id) do
      node_execution
      |> NodeExecution.complete_changeset(%{
        status: :skipped,
        completed_at: DateTime.utc_now()
      })
      |> Repo.update()
    end
  end

  @doc """
  Gets a node execution by ID.
  """
  def get_execution(id) do
    case Repo.get(NodeExecution, id) do
      nil -> {:error, :not_found}
      execution -> {:ok, execution}
    end
  end

  @doc """
  Lists node executions for a specific workflow.
  """
  def list_by_workflow(workflow_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    limit = Keyword.get(opts, :limit)

    query =
      from ne in NodeExecution,
        where: ne.workflow_id == ^workflow_id,
        order_by: [desc: ne.started_at]

    query =
      if status do
        from ne in query, where: ne.status == ^status
      else
        query
      end

    query =
      if limit do
        from ne in query, limit: ^limit
      else
        query
      end

    {:ok, Repo.all(query)}
  end

  @doc """
  Lists node executions for a specific token.
  """
  def list_by_token(workflow_id, token_id) do
    query =
      from ne in NodeExecution,
        where: ne.workflow_id == ^workflow_id and ne.token_id == ^token_id,
        order_by: [asc: ne.started_at]

    {:ok, Repo.all(query)}
  end

  @doc """
  Lists node executions for a specific node.
  """
  def list_by_node(workflow_id, node_id, opts \\ []) do
    limit = Keyword.get(opts, :limit)

    query =
      from ne in NodeExecution,
        where: ne.workflow_id == ^workflow_id and ne.node_id == ^node_id,
        order_by: [desc: ne.started_at]

    query =
      if limit do
        from ne in query, limit: ^limit
      else
        query
      end

    {:ok, Repo.all(query)}
  end

  @doc """
  Gets statistics for node executions in a workflow.
  """
  def get_statistics(workflow_id) do
    query =
      from ne in NodeExecution,
        where: ne.workflow_id == ^workflow_id,
        group_by: ne.status,
        select: {ne.status, count(ne.id)}

    status_counts = Repo.all(query) |> Enum.into(%{})

    avg_duration_query =
      from ne in NodeExecution,
        where: ne.workflow_id == ^workflow_id and not is_nil(ne.duration_ms),
        select: avg(ne.duration_ms)

    avg_duration = Repo.one(avg_duration_query)

    {:ok,
     %{
       status_counts: status_counts,
       average_duration_ms: avg_duration && Decimal.to_float(avg_duration)
     }}
  end

  @doc """
  Deletes all node executions for a workflow.
  """
  def delete_by_workflow(workflow_id) do
    from(ne in NodeExecution, where: ne.workflow_id == ^workflow_id)
    |> Repo.delete_all()

    :ok
  end
end
