#!/usr/bin/env elixir

# Simple BPMN Workflow Example
# Demonstrates a basic workflow: Start -> Activity1 -> Activity2 -> End

alias BpmnWorkflow.Builder

IO.puts("=== Simple Sequential Workflow ===\n")

# Start the application
{:ok, _} = Application.ensure_all_started(:bpmn_workflow)

# Give the application time to start
Process.sleep(100)

# Create workflow
workflow_id = "simple_workflow"

Builder.create_workflow(workflow_id, "start")
|> Builder.add_start_event("start", next_nodes: ["task1"])
|> Builder.add_activity("task1",
  name: "Process Order",
  next_nodes: ["task2"],
  work_fn: fn token ->
    IO.puts("\n📋 Processing order...")
    Process.sleep(500)
    BpmnWorkflow.Token.update_data(token, %{order_id: "ORD-001", status: "processing"})
  end
)
|> Builder.add_activity("task2",
  name: "Send Confirmation",
  next_nodes: ["end"],
  work_fn: fn token ->
    IO.puts("📧 Sending confirmation email...")
    Process.sleep(500)
    BpmnWorkflow.Token.update_data(token, %{email_sent: true})
  end
)
|> Builder.add_end_event("end", name: "Order Complete")

IO.puts("\nWorkflow created. Starting execution...\n")

# Visualize initial state
Builder.visualize(workflow_id)

# Start workflow
{:ok, token_id} = Builder.start(workflow_id, %{customer: "John Doe"})
IO.puts("Started workflow with token: #{String.slice(token_id, 0..7)}\n")

# Wait for workflow to complete
Process.sleep(2000)

# Visualize final state
IO.puts("\n=== Final State ===")
Builder.visualize(workflow_id)
