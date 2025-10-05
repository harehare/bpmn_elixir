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

  forward("/api/workflows", to: BpmnWorkflowWeb.WorkflowController)
  forward("/api/user_tasks", to: BpmnWorkflowWeb.UserTaskController)

  match _ do
    send_resp(conn, 404, Jason.encode!(%{error: "Not found"}))
  end
end
