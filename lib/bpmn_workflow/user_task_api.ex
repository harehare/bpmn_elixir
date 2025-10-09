defmodule BpmnWorkflow.UserTaskAPI do
  @moduledoc """
  DEPRECATED: This module is deprecated in favor of BpmnWorkflow.ActivityAPI.
  UserTask functionality has been merged into Activity with activity_type: :user_task.

  This module is kept for backward compatibility and delegates all calls to ActivityAPI.
  """

  @deprecated "Use BpmnWorkflow.ActivityAPI instead"
  defdelegate list_waiting_tasks(workflow_id), to: BpmnWorkflow.ActivityAPI, as: :list_waiting_activities

  @deprecated "Use BpmnWorkflow.ActivityAPI instead"
  defdelegate list_waiting_tasks(workflow_id, node_id), to: BpmnWorkflow.ActivityAPI, as: :list_waiting_activities

  @deprecated "Use BpmnWorkflow.ActivityAPI instead"
  defdelegate complete_task(workflow_id, node_id, token_id, user_data), to: BpmnWorkflow.ActivityAPI, as: :complete_activity

  @deprecated "Use BpmnWorkflow.ActivityAPI instead"
  defdelegate get_token_status(workflow_id, token_id), to: BpmnWorkflow.ActivityAPI
end
