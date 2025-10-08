defmodule BpmnWorkflow.DefinitionManagerTest do
  use ExUnit.Case, async: true

  alias BpmnWorkflow.{Repo, DefinitionManager}
  alias BpmnWorkflow.Schemas.WorkflowDefinition

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  describe "create_definition/1" do
    test "creates a valid workflow definition" do
      attrs = %{
        name: "Test Workflow",
        description: "A test workflow",
        definition: %{
          "start_node_id" => "start1",
          "nodes" => [
            %{"id" => "start1", "type" => "start_event", "next_nodes" => ["end1"]},
            %{"id" => "end1", "type" => "end_event"}
          ]
        }
      }

      assert {:ok, %WorkflowDefinition{} = definition} =
               DefinitionManager.create_definition(attrs)

      assert definition.name == "Test Workflow"
      assert definition.version == 1
      assert definition.is_active == true
    end

    test "returns error for invalid definition structure" do
      attrs = %{
        name: "Invalid Workflow",
        definition: %{"invalid" => "structure"}
      }

      assert {:error, changeset} = DefinitionManager.create_definition(attrs)
      assert "invalid workflow definition structure" in errors_on(changeset).definition
    end
  end

  describe "get_definition/1" do
    test "retrieves an existing definition" do
      {:ok, definition} = create_test_definition()

      assert {:ok, fetched} = DefinitionManager.get_definition(definition.id)
      assert fetched.id == definition.id
      assert fetched.name == definition.name
    end

    test "returns error for non-existent definition" do
      assert {:error, :not_found} = DefinitionManager.get_definition(Ecto.UUID.generate())
    end
  end

  describe "list_definitions/1" do
    test "lists all definitions" do
      {:ok, _def1} = create_test_definition("Workflow 1")
      {:ok, _def2} = create_test_definition("Workflow 2")

      assert {:ok, definitions} = DefinitionManager.list_definitions()
      assert length(definitions) == 2
    end

    test "lists only active definitions when active_only is true" do
      {:ok, def1} = create_test_definition("Active Workflow")
      {:ok, _def2} = create_test_definition("Inactive Workflow")

      DefinitionManager.deactivate_definition(def1.id)

      assert {:ok, definitions} = DefinitionManager.list_definitions(active_only: true)
      assert length(definitions) == 1
    end
  end

  describe "update_definition/2" do
    test "updates a definition" do
      {:ok, definition} = create_test_definition()

      assert {:ok, updated} =
               DefinitionManager.update_definition(definition.id, %{
                 description: "Updated description"
               })

      assert updated.description == "Updated description"
    end
  end

  describe "deactivate_definition/1" do
    test "deactivates a definition" do
      {:ok, definition} = create_test_definition()

      assert {:ok, deactivated} = DefinitionManager.deactivate_definition(definition.id)
      assert deactivated.is_active == false
    end
  end

  # Helper functions

  defp create_test_definition(name \\ "Test Workflow") do
    attrs = %{
      name: name,
      definition: %{
        "start_node_id" => "start1",
        "nodes" => [
          %{"id" => "start1", "type" => "start_event", "next_nodes" => ["end1"]},
          %{"id" => "end1", "type" => "end_event"}
        ]
      }
    }

    DefinitionManager.create_definition(attrs)
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
