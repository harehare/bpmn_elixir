defmodule BpmnWorkflow.Schemas.WorkflowDefinition do
  @moduledoc """
  Schema for storing BPMN workflow definitions.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workflow_definitions" do
    field :name, :string
    field :description, :string
    field :version, :integer, default: 1
    field :definition, :map
    field :is_active, :boolean, default: true

    has_many :workflow_executions, BpmnWorkflow.Schemas.WorkflowExecution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workflow_definition, attrs) do
    workflow_definition
    |> cast(attrs, [:name, :description, :version, :definition, :is_active])
    |> validate_required([:name, :definition])
    |> validate_definition()
  end

  defp validate_definition(changeset) do
    case get_change(changeset, :definition) do
      nil ->
        changeset

      definition ->
        if valid_definition?(definition) do
          changeset
        else
          add_error(changeset, :definition, "invalid workflow definition structure")
        end
    end
  end

  defp valid_definition?(%{"start_node_id" => _, "nodes" => nodes}) when is_list(nodes) do
    Enum.all?(nodes, fn node ->
      Map.has_key?(node, "id") and Map.has_key?(node, "type")
    end)
  end

  defp valid_definition?(_), do: false
end
