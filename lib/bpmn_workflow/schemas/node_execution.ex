defmodule BpmnWorkflow.Schemas.NodeExecution do
  @moduledoc """
  Schema for tracking individual node execution history and status.
  Each record represents a single node execution event in a workflow.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "node_executions" do
    field :workflow_id, :string
    field :token_id, :string
    field :node_id, :string
    field :node_type, :string
    field :status, Ecto.Enum,
      values: [:pending, :executing, :completed, :failed, :waiting, :skipped]
    field :input_data, :map
    field :output_data, :map
    field :error_message, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :duration_ms, :integer

    belongs_to :workflow_execution, BpmnWorkflow.Schemas.WorkflowExecution

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(node_execution, attrs) do
    node_execution
    |> cast(attrs, [
      :workflow_id,
      :workflow_execution_id,
      :token_id,
      :node_id,
      :node_type,
      :status,
      :input_data,
      :output_data,
      :error_message,
      :started_at,
      :completed_at,
      :duration_ms
    ])
    |> validate_required([:workflow_id, :token_id, :node_id, :node_type, :status])
    |> foreign_key_constraint(:workflow_execution_id)
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [
      :workflow_id,
      :workflow_execution_id,
      :token_id,
      :node_id,
      :node_type,
      :status,
      :input_data,
      :started_at
    ])
    |> validate_required([:workflow_id, :token_id, :node_id, :node_type, :status])
    |> put_change(:started_at, attrs[:started_at] || DateTime.utc_now())
  end

  @doc false
  def complete_changeset(node_execution, attrs) do
    completed_at = attrs[:completed_at] || DateTime.utc_now()

    duration_ms =
      if node_execution.started_at do
        DateTime.diff(completed_at, node_execution.started_at, :millisecond)
      else
        nil
      end

    node_execution
    |> cast(attrs, [:status, :output_data, :error_message, :completed_at])
    |> validate_required([:status])
    |> put_change(:completed_at, completed_at)
    |> put_change(:duration_ms, duration_ms)
  end
end
