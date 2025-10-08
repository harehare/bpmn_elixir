defmodule BpmnWorkflow.DefinitionManager do
  @moduledoc """
  Manages BPMN workflow definitions in the database.
  """

  import Ecto.Query
  alias BpmnWorkflow.Repo
  alias BpmnWorkflow.Schemas.WorkflowDefinition

  @doc """
  Creates a new workflow definition.
  """
  def create_definition(attrs) do
    %WorkflowDefinition{}
    |> WorkflowDefinition.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a workflow definition by ID.
  """
  def get_definition(id) do
    case Repo.get(WorkflowDefinition, id) do
      nil -> {:error, :not_found}
      definition -> {:ok, definition}
    end
  end

  @doc """
  Gets a workflow definition by name and version.
  """
  def get_definition_by_name(name, version \\ nil) do
    query =
      if version do
        from d in WorkflowDefinition,
          where: d.name == ^name and d.version == ^version
      else
        from d in WorkflowDefinition,
          where: d.name == ^name and d.is_active == true,
          order_by: [desc: d.version],
          limit: 1
      end

    case Repo.one(query) do
      nil -> {:error, :not_found}
      definition -> {:ok, definition}
    end
  end

  @doc """
  Lists all workflow definitions.
  """
  def list_definitions(opts \\ []) do
    active_only = Keyword.get(opts, :active_only, false)

    query =
      if active_only do
        from d in WorkflowDefinition, where: d.is_active == true
      else
        WorkflowDefinition
      end

    {:ok, Repo.all(query)}
  end

  @doc """
  Updates a workflow definition.
  """
  def update_definition(id, attrs) do
    with {:ok, definition} <- get_definition(id) do
      definition
      |> WorkflowDefinition.changeset(attrs)
      |> Repo.update()
    end
  end

  @doc """
  Deactivates a workflow definition (soft delete).
  """
  def deactivate_definition(id) do
    update_definition(id, %{is_active: false})
  end

  @doc """
  Deletes a workflow definition (hard delete).
  """
  def delete_definition(id) do
    with {:ok, definition} <- get_definition(id) do
      Repo.delete(definition)
    end
  end
end
