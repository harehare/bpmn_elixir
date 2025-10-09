defmodule BpmnWorkflow.Builder do
  @moduledoc """
  Helper module for building BPMN workflows with a fluent API.
  """

  @doc """
  Creates a new workflow engine.
  """
  def create_workflow(workflow_id, start_node_id) do
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        BpmnWorkflow.EngineSupervisor,
        {BpmnWorkflow.Engine, workflow_id: workflow_id, start_node_id: start_node_id}
      )

    workflow_id
  end

  @doc """
  Adds a start event to the workflow.
  """
  def add_start_event(workflow_id, id, opts \\ []) do
    name = Keyword.get(opts, :name, "Start Event")
    next_nodes = Keyword.get(opts, :next_nodes, [])

    BpmnWorkflow.Engine.add_node(workflow_id, :start_event,
      id: id,
      name: name,
      next_nodes: next_nodes
    )

    workflow_id
  end

  @doc """
  Adds an end event to the workflow.
  """
  def add_end_event(workflow_id, id, opts \\ []) do
    name = Keyword.get(opts, :name, "End Event")

    BpmnWorkflow.Engine.add_node(workflow_id, :end_event,
      id: id,
      name: name
    )

    workflow_id
  end

  @doc """
  Adds an activity to the workflow.
  Supports multiple activity types:
  - :service_task (default) - executes a function automatically
  - :user_task - waits for user input via API
  - :script_task - executes a script
  - :manual_task - waits for manual confirmation
  """
  def add_activity(workflow_id, id, opts \\ []) do
    name = Keyword.get(opts, :name, "Activity")
    next_nodes = Keyword.get(opts, :next_nodes, [])
    activity_type = Keyword.get(opts, :activity_type, :service_task)
    work_fn = Keyword.get(opts, :work_fn)
    form_fields = Keyword.get(opts, :form_fields, [])
    script = Keyword.get(opts, :script)

    BpmnWorkflow.Engine.add_node(workflow_id, :activity,
      id: id,
      name: name,
      next_nodes: next_nodes,
      activity_type: activity_type,
      work_fn: work_fn,
      form_fields: form_fields,
      script: script
    )

    workflow_id
  end

  @doc """
  Adds a gateway to the workflow.
  """
  def add_gateway(workflow_id, id, opts \\ []) do
    name = Keyword.get(opts, :name, "Gateway")
    type = Keyword.get(opts, :type, :exclusive)
    next_nodes = Keyword.get(opts, :next_nodes, [])
    condition_fn = Keyword.get(opts, :condition_fn)

    BpmnWorkflow.Engine.add_node(workflow_id, :gateway,
      id: id,
      name: name,
      type: type,
      next_nodes: next_nodes,
      condition_fn: condition_fn
    )

    workflow_id
  end

  @doc """
  Adds a user task to the workflow.
  User tasks wait for external user input before continuing.
  This is a convenience wrapper for add_activity with activity_type: :user_task.

  DEPRECATED: Use add_activity with activity_type: :user_task instead.
  """
  def add_user_task(workflow_id, id, opts \\ []) do
    name = Keyword.get(opts, :name, "User Task")
    next_nodes = Keyword.get(opts, :next_nodes, [])
    form_fields = Keyword.get(opts, :form_fields, [])

    add_activity(workflow_id, id,
      name: name,
      next_nodes: next_nodes,
      activity_type: :user_task,
      form_fields: form_fields
    )

    workflow_id
  end

  @doc """
  Starts the workflow execution.
  """
  def start(workflow_id, initial_data \\ %{}) do
    BpmnWorkflow.Engine.start_workflow(workflow_id, initial_data)
  end

  @doc """
  Visualizes the workflow.
  """
  def visualize(workflow_id) do
    BpmnWorkflow.Visualizer.visualize(workflow_id)
    workflow_id
  end

  @doc """
  Displays workflow status.
  """
  def status(workflow_id) do
    BpmnWorkflow.Visualizer.status_line(workflow_id)
    workflow_id
  end
end
