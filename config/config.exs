import Config

# Configure ecto repos
config :bpmn_workflow, ecto_repos: [BpmnWorkflow.Repo]

# HTTP API configuration
config :bpmn_workflow, BpmnWorkflowWeb.Endpoint,
  http_port: String.to_integer(System.get_env("PORT") || "4000")

# Database configuration
# By default use SQLite, can be changed to PostgreSQL by setting DATABASE_ADAPTER env var
database_adapter =
  case System.get_env("DATABASE_ADAPTER") do
    "postgres" -> Ecto.Adapters.Postgres
    _ -> Ecto.Adapters.SQLite3
  end

config :bpmn_workflow, :ecto_adapter, database_adapter

# SQLite configuration (default)
config :bpmn_workflow, BpmnWorkflow.Repo,
  database: System.get_env("DATABASE_PATH") || "bpmn_workflow.db",
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

# Import environment specific config
import_config "#{config_env()}.exs"
