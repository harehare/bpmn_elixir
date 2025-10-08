import Config

# Configure database for development
config :bpmn_workflow, BpmnWorkflow.Repo,
  database: "bpmn_workflow_dev.db",
  pool_size: 5,
  show_sensitive_data_on_connection_error: true

# For PostgreSQL (optional)
# config :bpmn_workflow, BpmnWorkflow.Repo,
#   username: "postgres",
#   password: "postgres",
#   hostname: "localhost",
#   database: "bpmn_workflow_dev",
#   stacktrace: true,
#   show_sensitive_data_on_connection_error: true,
#   pool_size: 10
