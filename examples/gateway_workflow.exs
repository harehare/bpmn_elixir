#!/usr/bin/env elixir

# Gateway BPMN Workflow Example
# Demonstrates exclusive gateway: Start -> Check Amount -> [Small/Large Path] -> End

alias BpmnWorkflow.Builder

IO.puts("=== Gateway Workflow Example ===\n")

# Start the application
{:ok, _} = Application.ensure_all_started(:bpmn_workflow)

# Give the application time to start
Process.sleep(100)

# Create workflow
workflow_id = "gateway_workflow"

Builder.create_workflow(workflow_id, "start")
|> Builder.add_start_event("start", next_nodes: ["check_amount"])
|> Builder.add_activity("check_amount",
  name: "Check Order Amount",
  next_nodes: ["amount_gateway"],
  work_fn: fn token ->
    amount = Map.get(token.data, :amount, 100)
    IO.puts("\n💰 Checking order amount: $#{amount}")
    Process.sleep(300)
    token
  end
)
|> Builder.add_gateway("amount_gateway",
  name: "Amount Decision",
  type: :exclusive,
  next_nodes: ["small_order", "large_order"],
  condition_fn: fn token, node_id ->
    amount = Map.get(token.data, :amount, 0)

    case node_id do
      "small_order" -> amount < 1000
      "large_order" -> amount >= 1000
      _ -> false
    end
  end
)
|> Builder.add_activity("small_order",
  name: "Process Small Order",
  next_nodes: ["end"],
  work_fn: fn token ->
    IO.puts("📦 Processing as small order (standard shipping)")
    Process.sleep(300)
    BpmnWorkflow.Token.update_data(token, %{shipping: "standard", processing_fee: 5})
  end
)
|> Builder.add_activity("large_order",
  name: "Process Large Order",
  next_nodes: ["end"],
  work_fn: fn token ->
    IO.puts("🎁 Processing as large order (express shipping + discount)")
    Process.sleep(300)
    BpmnWorkflow.Token.update_data(token, %{shipping: "express", discount: 10})
  end
)
|> Builder.add_end_event("end", name: "Order Processed")

IO.puts("\n=== Test 1: Small Order ($500) ===")
Builder.visualize(workflow_id)

{:ok, _token_id} = Builder.start(workflow_id, %{customer: "Alice", amount: 500})
Process.sleep(1500)

IO.puts("\n=== Final State (Small Order) ===")
Builder.visualize(workflow_id)

# Wait a bit before next test
Process.sleep(1000)

# Create another workflow for large order (with different node IDs)
workflow_id2 = "gateway_workflow_2"

Builder.create_workflow(workflow_id2, "start2")
|> Builder.add_start_event("start2", next_nodes: ["check_amount2"])
|> Builder.add_activity("check_amount2",
  name: "Check Order Amount",
  next_nodes: ["amount_gateway2"],
  work_fn: fn token ->
    amount = Map.get(token.data, :amount, 100)
    IO.puts("\n💰 Checking order amount: $#{amount}")
    Process.sleep(300)
    token
  end
)
|> Builder.add_gateway("amount_gateway2",
  name: "Amount Decision",
  type: :exclusive,
  next_nodes: ["small_order2", "large_order2"],
  condition_fn: fn token, node_id ->
    amount = Map.get(token.data, :amount, 0)

    case node_id do
      "small_order2" -> amount < 1000
      "large_order2" -> amount >= 1000
      _ -> false
    end
  end
)
|> Builder.add_activity("small_order2",
  name: "Process Small Order",
  next_nodes: ["end2"],
  work_fn: fn token ->
    IO.puts("📦 Processing as small order (standard shipping)")
    Process.sleep(300)
    BpmnWorkflow.Token.update_data(token, %{shipping: "standard", processing_fee: 5})
  end
)
|> Builder.add_activity("large_order2",
  name: "Process Large Order",
  next_nodes: ["end2"],
  work_fn: fn token ->
    IO.puts("🎁 Processing as large order (express shipping + discount)")
    Process.sleep(300)
    BpmnWorkflow.Token.update_data(token, %{shipping: "express", discount: 10})
  end
)
|> Builder.add_end_event("end2", name: "Order Processed")

IO.puts("\n\n=== Test 2: Large Order ($2500) ===")
Builder.visualize(workflow_id2)

{:ok, _token_id2} = Builder.start(workflow_id2, %{customer: "Bob", amount: 2500})
Process.sleep(1500)

IO.puts("\n=== Final State (Large Order) ===")
Builder.visualize(workflow_id2)
