defmodule BpmnWorkflow.Schemas.WorkflowExecution do
  @moduledoc """
  Schema for storing BPMN workflow execution state.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workflow_executions" do
    field :workflow_id, :string
    field :status, Ecto.Enum, values: [:initialized, :running, :waiting, :completed, :failed]
    field :initial_data, :map
    field :current_state, :map
    field :error, :string

    belongs_to :workflow_definition, BpmnWorkflow.Schemas.WorkflowDefinition

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workflow_execution, attrs) do
    workflow_execution
    |> cast(attrs, [
      :workflow_id,
      :workflow_definition_id,
      :status,
      :initial_data,
      :current_state,
      :error
    ])
    |> validate_required([:workflow_id, :workflow_definition_id, :status])
  end

  @doc false
  def update_state_changeset(workflow_execution, attrs) do
    workflow_execution
    |> cast(attrs, [:status, :current_state, :error])
    |> validate_required([:status])
  end
end
