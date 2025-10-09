defmodule BpmnWorkflowWeb.Router do
  use Plug.Router

  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json],
    pass: ["application/json"],
    json_decoder: Jason
  )

  plug(:dispatch)

  forward("/api/definitions", to: BpmnWorkflowWeb.DefinitionController)
  forward("/api/executions", to: BpmnWorkflowWeb.ExecutionController)
  forward("/api/node_executions", to: BpmnWorkflowWeb.NodeExecutionController)
  forward("/api/workflows", to: BpmnWorkflowWeb.WorkflowController)
  forward("/api/activities", to: BpmnWorkflowWeb.ActivityController)
  # Backward compatibility: keep user_tasks endpoint
  forward("/api/user_tasks", to: BpmnWorkflowWeb.UserTaskController)

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end
end
