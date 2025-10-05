# Example: Web API User Task Workflow
# This example demonstrates using HTTP API to interact with user tasks.

{:ok, _} = Application.ensure_all_started(:bpmn_workflow)

alias BpmnWorkflow.Builder

workflow_id = "web_api_workflow"

# Create a workflow with user tasks
Builder.create_workflow(workflow_id, "start")
|> Builder.add_start_event("start", next_nodes: ["collect_info"])
|> Builder.add_activity("collect_info",
  name: "Collect Information",
  next_nodes: ["user_input"],
  work_fn: fn token ->
    IO.puts("\n📋 Collecting information...")

    BpmnWorkflow.Token.update_data(token, %{
      form_id: "FORM-#{:rand.uniform(1000)}",
      created_at: DateTime.utc_now()
    })
  end
)
|> Builder.add_user_task("user_input",
  name: "User Input Required",
  next_nodes: ["validate"],
  form_fields: [
    %{name: "name", type: "text", label: "Your Name"},
    %{name: "email", type: "email", label: "Email Address"},
    %{name: "age", type: "number", label: "Age"}
  ]
)
|> Builder.add_activity("validate",
  name: "Validate Input",
  next_nodes: ["end"],
  work_fn: fn token ->
    IO.puts("\n✅ Validating user input...")
    name = Map.get(token.data, "name", "")
    email = Map.get(token.data, "email", "")

    IO.puts("Name: #{name}")
    IO.puts("Email: #{email}")

    BpmnWorkflow.Token.update_data(token, %{
      validated: true,
      validated_at: DateTime.utc_now()
    })
  end
)
|> Builder.add_end_event("end")

IO.puts("=" |> String.duplicate(80))
IO.puts("Web API User Task Workflow Example")
IO.puts("=" |> String.duplicate(80))
IO.puts("\n🌐 HTTP API Server running at http://localhost:4000")

# Start the workflow
{:ok, token_id} = Builder.start(workflow_id, %{source: "web_api"})

IO.puts("\n✨ Workflow started with token: #{token_id}")

# Wait for workflow to reach user task
Process.sleep(200)

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("API Endpoints Available:")
IO.puts(String.duplicate("=", 80))

IO.puts("""

1. Get Workflow Status:
   GET http://localhost:4000/api/workflows/#{workflow_id}/status

2. Get Full Workflow State:
   GET http://localhost:4000/api/workflows/#{workflow_id}/state

3. Get Token Status:
   GET http://localhost:4000/api/workflows/#{workflow_id}/tokens/#{token_id}

4. List Waiting User Tasks:
   GET http://localhost:4000/api/user_tasks/#{workflow_id}

5. Complete User Task:
   POST http://localhost:4000/api/user_tasks/#{workflow_id}/user_input/#{token_id}/complete
   Body:
   {
     "data": {
       "name": "John Doe",
       "email": "john@example.com",
       "age": 30
     }
   }
""")

IO.puts(String.duplicate("=", 80))
IO.puts("\n📝 Example using curl:\n")

IO.puts("""
# List waiting tasks
curl http://localhost:4000/api/user_tasks/#{workflow_id}

# Complete the task
curl -X POST http://localhost:4000/api/user_tasks/#{workflow_id}/user_input/#{token_id}/complete \\
  -H "Content-Type: application/json" \\
  -d '{
    "data": {
      "name": "John Doe",
      "email": "john@example.com",
      "age": 30
    }
  }'

# Check workflow status
curl http://localhost:4000/api/workflows/#{workflow_id}/status
""")

IO.puts(String.duplicate("=", 80))
IO.puts("\n⏳ Workflow is waiting for user input via API...")
IO.puts("The workflow will remain active until you complete the user task via HTTP API.")
IO.puts("\nPress Ctrl+C to exit.")

# Keep the script running
Process.sleep(:infinity)
