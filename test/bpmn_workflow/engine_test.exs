defmodule BpmnWorkflow.EngineTest do
  use ExUnit.Case, async: true

  alias BpmnWorkflow.Engine
  alias BpmnWorkflow.Builder

  setup do
    workflow_id = "test_workflow_#{System.unique_integer()}"
    %{workflow_id: workflow_id}
  end

  test "workflow with UserTask waits for trigger and then completes", %{workflow_id: workflow_id} do
    # Build a simple workflow: Start -> UserTask -> End
    {:ok, _} =
      Builder.new(workflow_id)
      |> Builder.add_start_event("start", next_nodes: ["user_task"])
      |> Builder.add_user_task("user_task", name: "Wait for Approval", next_nodes: ["end"])
      |> Builder.add_end_event("end")
      |> Builder.build()

    # Start the workflow
    {:ok, _token_id} = Engine.start_workflow(workflow_id, %{customer_id: 123})

    # Check status: should be running and waiting for the user task
    status_before = Engine.get_status(workflow_id)
    assert status_before.status == :running
    assert map_size(status_before.waiting_tasks) == 1
    assert Map.has_key?(status_before.waiting_tasks, "user_task")

    # Trigger the user task
    :ok = Engine.trigger_user_task(workflow_id, "user_task", %{approved: true})

    # Check status again: should be completed
    # Allow some time for the process to complete
    Process.sleep(100)
    status_after = Engine.get_status(workflow_id)
    assert status_after.status == :completed
    assert map_size(status_after.waiting_tasks) == 0
    assert length(status_after.completed_tokens) == 1
  end

  test "triggering a non-waiting task returns an error", %{workflow_id: workflow_id} do
    # Build a workflow without a user task
    {:ok, _} =
      Builder.new(workflow_id)
      |> Builder.add_start_event("start", next_nodes: ["end"])
      |> Builder.add_end_event("end")
      |> Builder.build()

    Engine.start_workflow(workflow_id)
    Process.sleep(100) # Let workflow complete

    # Attempt to trigger a task that doesn't exist or isn't waiting
    assert {:error, :not_waiting} == Engine.trigger_user_task(workflow_id, "non_existent_task")
  end
end