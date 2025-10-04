#!/usr/bin/env elixir

# User Task Workflow Example
# Demonstrates a workflow that waits for an external trigger from a user task.
# Workflow: Start -> UserTask -> End

alias BpmnWorkflow.Builder
alias BpmnWorkflow.Engine

IO.puts("=== User Task Workflow Example ===\n")

# Ensure the application is started
Application.ensure_all_started(:bpmn_workflow)
Process.sleep(100) # Give it a moment to settle

# --- Define the Workflow ---
workflow_id = "user_task_approval"

Builder.new(workflow_id)
|> Builder.add_start_event("start", next_nodes: ["await_approval"])
|> Builder.add_user_task("await_approval", name: "Awaiting Manager Approval", next_nodes: ["end"])
|> Builder.add_end_event("end", name: "Process Finished")
|> Builder.build()

IO.puts("Workflow '#{workflow_id}' created.")
Builder.visualize(workflow_id)

# --- Start the Workflow ---
IO.puts("\nStarting workflow...")
{:ok, token_id} = Builder.start(workflow_id, %{request_id: "REQ-101", user: "jules"})
IO.puts("Workflow started with token: #{String.slice(token_id, 0..7)}")
Process.sleep(200) # Allow time for the workflow to reach the user task

# --- Check Status (Waiting) ---
IO.puts("\n--- Current State (Waiting for Trigger) ---")
Builder.visualize(workflow_id)

status_waiting = Engine.get_status(workflow_id)
IO.puts("Workflow status: #{status_waiting.status}")
IO.inspect(status_waiting.waiting_tasks, label: "Waiting Tasks")

# --- Trigger the User Task ---
IO.puts("\nTriggering user task 'await_approval' with external data...")
:ok = Engine.trigger_user_task(workflow_id, "await_approval", %{approved_by: "manager_user", approved_at: DateTime.utc_now()})
IO.puts("Trigger sent successfully.")
Process.sleep(200) # Allow time for the workflow to complete

# --- Final State ---
IO.puts("\n--- Final State ---")
Builder.visualize(workflow_id)

status_completed = Engine.get_status(workflow_id)
IO.puts("Final workflow status: #{status_completed.status}")
IO.inspect(status_completed.completed_tokens, label: "Completed Tokens")

IO.puts("\n=== Example Complete ===")