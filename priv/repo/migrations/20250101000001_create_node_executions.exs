defmodule BpmnWorkflow.Repo.Migrations.CreateNodeExecutions do
  use Ecto.Migration

  def change do
    create table(:node_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workflow_id, :string, null: false
      add :workflow_execution_id, references(:workflow_executions, type: :binary_id, on_delete: :delete_all)
      add :token_id, :string, null: false
      add :node_id, :string, null: false
      add :node_type, :string, null: false
      add :status, :string, null: false
      add :input_data, :map
      add :output_data, :map
      add :error_message, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :duration_ms, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:node_executions, [:workflow_id])
    create index(:node_executions, [:workflow_execution_id])
    create index(:node_executions, [:token_id])
    create index(:node_executions, [:node_id])
    create index(:node_executions, [:status])
    create index(:node_executions, [:started_at])
  end
end
