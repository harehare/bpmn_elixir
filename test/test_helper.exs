ExUnit.start()

# Start the Repo for tests
Ecto.Adapters.SQL.Sandbox.mode(BpmnWorkflow.Repo, :manual)
