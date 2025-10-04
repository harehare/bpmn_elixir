#!/usr/bin/env elixir

# Comprehensive BPMN Workflow Demo
# Demonstrates all features: StartEvent, EndEvent, Activity, Gateway (Exclusive, Parallel)

alias BpmnWorkflow.Builder

IO.puts("╔═══════════════════════════════════════════════════════════════╗")
IO.puts("║        BPMN Workflow Engine - Comprehensive Demo             ║")
IO.puts("╚═══════════════════════════════════════════════════════════════╝")

# Start the application
{:ok, _} = Application.ensure_all_started(:bpmn_workflow)
Process.sleep(100)

# Build a complex workflow simulating an e-commerce order process
workflow_id = "ecommerce_order"

IO.puts("\n📋 Building E-Commerce Order Workflow...")
IO.puts("   This workflow demonstrates:")
IO.puts("   - Sequential activities")
IO.puts("   - Exclusive gateway (payment method decision)")
IO.puts("   - Parallel gateway (concurrent tasks)")
IO.puts("")

Builder.create_workflow(workflow_id, "receive_order")
|> Builder.add_start_event("receive_order", next_nodes: ["validate_order"])
|> Builder.add_activity("validate_order",
  name: "Validate Order",
  next_nodes: ["payment_check"],
  work_fn: fn token ->
    IO.puts("✓ Validating order #{token.data.order_id}...")
    Process.sleep(300)
    BpmnWorkflow.Token.update_data(token, %{validated: true})
  end
)
|> Builder.add_gateway("payment_check",
  name: "Check Payment Method",
  type: :exclusive,
  next_nodes: ["process_credit_card", "process_paypal"],
  condition_fn: fn token, node_id ->
    payment_method = Map.get(token.data, :payment_method, "credit_card")

    case node_id do
      "process_credit_card" -> payment_method == "credit_card"
      "process_paypal" -> payment_method == "paypal"
      _ -> false
    end
  end
)
|> Builder.add_activity("process_credit_card",
  name: "Process Credit Card Payment",
  next_nodes: ["parallel_processing"],
  work_fn: fn token ->
    IO.puts("💳 Processing credit card payment...")
    Process.sleep(400)
    BpmnWorkflow.Token.update_data(token, %{payment_processed: true, method: "credit_card"})
  end
)
|> Builder.add_activity("process_paypal",
  name: "Process PayPal Payment",
  next_nodes: ["parallel_processing"],
  work_fn: fn token ->
    IO.puts("🅿️  Processing PayPal payment...")
    Process.sleep(350)
    BpmnWorkflow.Token.update_data(token, %{payment_processed: true, method: "paypal"})
  end
)
|> Builder.add_gateway("parallel_processing",
  name: "Fork Parallel Tasks",
  type: :parallel,
  next_nodes: ["prepare_shipment", "send_confirmation", "update_inventory"]
)
|> Builder.add_activity("prepare_shipment",
  name: "Prepare Shipment",
  next_nodes: ["complete"],
  work_fn: fn token ->
    IO.puts("📦 Preparing shipment...")
    Process.sleep(600)
    BpmnWorkflow.Token.update_data(token, %{shipment_ready: true})
  end
)
|> Builder.add_activity("send_confirmation",
  name: "Send Email Confirmation",
  next_nodes: ["complete"],
  work_fn: fn token ->
    IO.puts("📧 Sending confirmation email to customer...")
    Process.sleep(400)
    BpmnWorkflow.Token.update_data(token, %{email_sent: true})
  end
)
|> Builder.add_activity("update_inventory",
  name: "Update Inventory",
  next_nodes: ["complete"],
  work_fn: fn token ->
    IO.puts("📊 Updating inventory database...")
    Process.sleep(500)
    BpmnWorkflow.Token.update_data(token, %{inventory_updated: true})
  end
)
|> Builder.add_end_event("complete", name: "Order Complete")

IO.puts("✓ Workflow built successfully!\n")

# Show initial state
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("INITIAL WORKFLOW STATE")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Builder.visualize(workflow_id)

# Test 1: Credit Card Payment
IO.puts("\n\n╔═══════════════════════════════════════════════════════════════╗")
IO.puts("║  TEST 1: Order with Credit Card Payment                      ║")
IO.puts("╚═══════════════════════════════════════════════════════════════╝\n")

{:ok, token1} =
  Builder.start(workflow_id, %{
    order_id: "ORD-2024-001",
    customer: "Alice Johnson",
    payment_method: "credit_card",
    total: 159.99
  })

IO.puts("→ Workflow started with token: #{String.slice(token1, 0..7)}")
IO.puts("→ Payment Method: Credit Card")
IO.puts("")

# Wait for completion
Process.sleep(2000)

IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("WORKFLOW STATE AFTER CREDIT CARD ORDER")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Builder.visualize(workflow_id)

# Wait before second test
Process.sleep(1000)

# Create new workflow for PayPal test (unique node IDs)
workflow_id2 = "ecommerce_order_2"

Builder.create_workflow(workflow_id2, "receive_order2")
|> Builder.add_start_event("receive_order2", next_nodes: ["validate_order2"])
|> Builder.add_activity("validate_order2",
  name: "Validate Order",
  next_nodes: ["payment_check2"],
  work_fn: fn token ->
    IO.puts("✓ Validating order #{token.data.order_id}...")
    Process.sleep(300)
    BpmnWorkflow.Token.update_data(token, %{validated: true})
  end
)
|> Builder.add_gateway("payment_check2",
  name: "Check Payment Method",
  type: :exclusive,
  next_nodes: ["process_credit_card2", "process_paypal2"],
  condition_fn: fn token, node_id ->
    payment_method = Map.get(token.data, :payment_method, "credit_card")

    case node_id do
      "process_credit_card2" -> payment_method == "credit_card"
      "process_paypal2" -> payment_method == "paypal"
      _ -> false
    end
  end
)
|> Builder.add_activity("process_credit_card2",
  name: "Process Credit Card Payment",
  next_nodes: ["parallel_processing2"],
  work_fn: fn token ->
    IO.puts("💳 Processing credit card payment...")
    Process.sleep(400)
    BpmnWorkflow.Token.update_data(token, %{payment_processed: true, method: "credit_card"})
  end
)
|> Builder.add_activity("process_paypal2",
  name: "Process PayPal Payment",
  next_nodes: ["parallel_processing2"],
  work_fn: fn token ->
    IO.puts("🅿️  Processing PayPal payment...")
    Process.sleep(350)
    BpmnWorkflow.Token.update_data(token, %{payment_processed: true, method: "paypal"})
  end
)
|> Builder.add_gateway("parallel_processing2",
  name: "Fork Parallel Tasks",
  type: :parallel,
  next_nodes: ["prepare_shipment2", "send_confirmation2", "update_inventory2"]
)
|> Builder.add_activity("prepare_shipment2",
  name: "Prepare Shipment",
  next_nodes: ["complete2"],
  work_fn: fn token ->
    IO.puts("📦 Preparing shipment...")
    Process.sleep(600)
    BpmnWorkflow.Token.update_data(token, %{shipment_ready: true})
  end
)
|> Builder.add_activity("send_confirmation2",
  name: "Send Email Confirmation",
  next_nodes: ["complete2"],
  work_fn: fn token ->
    IO.puts("📧 Sending confirmation email to customer...")
    Process.sleep(400)
    BpmnWorkflow.Token.update_data(token, %{email_sent: true})
  end
)
|> Builder.add_activity("update_inventory2",
  name: "Update Inventory",
  next_nodes: ["complete2"],
  work_fn: fn token ->
    IO.puts("📊 Updating inventory database...")
    Process.sleep(500)
    BpmnWorkflow.Token.update_data(token, %{inventory_updated: true})
  end
)
|> Builder.add_end_event("complete2", name: "Order Complete")

# Test 2: PayPal Payment
IO.puts("\n\n╔═══════════════════════════════════════════════════════════════╗")
IO.puts("║  TEST 2: Order with PayPal Payment                           ║")
IO.puts("╚═══════════════════════════════════════════════════════════════╝\n")

{:ok, token2} =
  Builder.start(workflow_id2, %{
    order_id: "ORD-2024-002",
    customer: "Bob Smith",
    payment_method: "paypal",
    total: 249.99
  })

IO.puts("→ Workflow started with token: #{String.slice(token2, 0..7)}")
IO.puts("→ Payment Method: PayPal")
IO.puts("")

# Wait for completion
Process.sleep(2000)

IO.puts("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
IO.puts("WORKFLOW STATE AFTER PAYPAL ORDER")
IO.puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
Builder.visualize(workflow_id2)

IO.puts("\n\n╔═══════════════════════════════════════════════════════════════╗")
IO.puts("║  Demo Complete!                                               ║")
IO.puts("║                                                               ║")
IO.puts("║  Key Features Demonstrated:                                   ║")
IO.puts("║  ✓ Independent Worker Processes (GenServers)                  ║")
IO.puts("║  ✓ Decoupled Node Architecture                                ║")
IO.puts("║  ✓ Sequential Activities                                      ║")
IO.puts("║  ✓ Exclusive Gateway (XOR) - Payment Routing                  ║")
IO.puts("║  ✓ Parallel Gateway (AND) - Concurrent Tasks                  ║")
IO.puts("║  ✓ Token-based Data Flow                                      ║")
IO.puts("║  ✓ Real-time Console Visualization                            ║")
IO.puts("║  ✓ Execution History Tracking                                 ║")
IO.puts("╚═══════════════════════════════════════════════════════════════╝\n")
