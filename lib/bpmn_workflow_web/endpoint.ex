defmodule BpmnWorkflowWeb.Endpoint do
  @moduledoc """
  HTTP endpoint for BPMN Workflow API.
  """

  use Plug.Builder

  plug(BpmnWorkflowWeb.Router)
end
