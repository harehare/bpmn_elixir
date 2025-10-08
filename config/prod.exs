import Config

# Configure database for production
# SQLite by default
config :bpmn_workflow, BpmnWorkflow.Repo,
  database: System.get_env("DATABASE_PATH") || "/var/lib/bpmn_workflow/bpmn_workflow.db",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

# For PostgreSQL (recommended for production)
# Uncomment and configure when using PostgreSQL:
# config :bpmn_workflow, BpmnWorkflow.Repo,
#   url: System.get_env("DATABASE_URL"),
#   pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
#   ssl: true
