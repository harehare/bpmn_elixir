import Config

# HTTP API configuration
config :bpmn_workflow, BpmnWorkflowWeb.Endpoint,
  http_port: String.to_integer(System.get_env("PORT") || "4000")
