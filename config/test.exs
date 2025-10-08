import Config

# Configure database for test
config :bpmn_workflow, BpmnWorkflow.Repo,
  database: "bpmn_workflow_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# For PostgreSQL (optional)
# config :bpmn_workflow, BpmnWorkflow.Repo,
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost",
#   database: "bpmn_workflow_test#{System.get_env("MIX_TEST_PARTITION")}",
#   pool: Ecto.Adapters.SQL.Sandbox,
#   pool_size: 10

# Print only warnings and errors during test
config :logger, level: :warning
