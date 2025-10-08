defmodule BpmnWorkflow.Repo.Migrations.CreateWorkflowTables do
  use Ecto.Migration

  def change do
    create table(:workflow_definitions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :description, :text
      add :version, :integer, default: 1
      add :definition, :map, null: false
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:workflow_definitions, [:name])
    create index(:workflow_definitions, [:is_active])

    create table(:workflow_executions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :workflow_id, :string, null: false
      add :workflow_definition_id, references(:workflow_definitions, type: :binary_id, on_delete: :restrict)
      add :status, :string, null: false
      add :initial_data, :map
      add :current_state, :map
      add :error, :text

      timestamps(type: :utc_datetime)
    end

    create index(:workflow_executions, [:workflow_id])
    create index(:workflow_executions, [:workflow_definition_id])
    create index(:workflow_executions, [:status])
  end
end
