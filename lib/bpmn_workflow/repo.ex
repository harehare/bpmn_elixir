defmodule BpmnWorkflow.Repo do
  use Ecto.Repo,
    otp_app: :bpmn_workflow,
    adapter: Application.compile_env(:bpmn_workflow, :ecto_adapter, Ecto.Adapters.SQLite3)
end
