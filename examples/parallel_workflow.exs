#!/usr/bin/env elixir

# Parallel Gateway BPMN Workflow Example
# Demonstrates parallel execution: Start -> Fork -> [TaskA + TaskB] -> Join -> End

alias BpmnWorkflow.Builder

IO.puts("=== Parallel Gateway Workflow Example ===\n")

# Start the application
{:ok, _} = Application.ensure_all_started(:bpmn_workflow)

# Give the application time to start
Process.sleep(100)

# Create workflow
workflow_id = "parallel_workflow"

Builder.create_workflow(workflow_id, "start")
|> Builder.add_start_event("start", next_nodes: ["parallel_fork"])
|> Builder.add_gateway("parallel_fork",
  name: "Fork Tasks",
  type: :parallel,
  next_nodes: ["task_a", "task_b", "task_c"]
)
|> Builder.add_activity("task_a",
  name: "Verify Inventory",
  next_nodes: ["end"],
  work_fn: fn token ->
    IO.puts("📦 Task A: Verifying inventory...")
    Process.sleep(800)
    IO.puts("✓ Task A: Inventory verified")
    BpmnWorkflow.Token.update_data(token, %{inventory_ok: true})
  end
)
|> Builder.add_activity("task_b",
  name: "Check Payment",
  next_nodes: ["end"],
  work_fn: fn token ->
    IO.puts("💳 Task B: Checking payment...")
    Process.sleep(600)
    IO.puts("✓ Task B: Payment confirmed")
    BpmnWorkflow.Token.update_data(token, %{payment_ok: true})
  end
)
|> Builder.add_activity("task_c",
  name: "Validate Address",
  next_nodes: ["end"],
  work_fn: fn token ->
    IO.puts("📍 Task C: Validating shipping address...")
    Process.sleep(400)
    IO.puts("✓ Task C: Address validated")
    BpmnWorkflow.Token.update_data(token, %{address_ok: true})
  end
)
|> Builder.add_end_event("end", name: "All Tasks Complete")

IO.puts("\nWorkflow created. Starting parallel execution...\n")

# Visualize initial state
Builder.visualize(workflow_id)

# Start workflow
{:ok, token_id} =
  Builder.start(workflow_id, %{
    order_id: "ORD-123",
    customer: "Charlie"
  })

IO.puts("Started workflow with token: #{String.slice(token_id, 0..7)}\n")
IO.puts("Watch as tasks execute in parallel!\n")

# Wait for workflow to complete
Process.sleep(2000)

# Visualize final state
IO.puts("\n=== Final State ===")
Builder.visualize(workflow_id)

IO.puts("\nNote: All three tasks (A, B, C) executed in parallel!")
