defmodule BpmnWorkflow.Builder do
  @moduledoc """
  A helper module to build workflow definitions programmatically.
  This is primarily intended for use in tests and scripts.
  """

  alias BpmnWorkflow.Engine

  defstruct [:workflow_id, :nodes]

  def new(workflow_id) do
    %__MODULE__{
      workflow_id: workflow_id,
      nodes: []
    }
  end

  def add_start_event(builder, id, opts \\ []) do
    opts = Keyword.put_new(opts, :id, id)
    add_node(builder, :start_event, opts)
  end

  def add_end_event(builder, id, opts \\ []) do
    opts = Keyword.put_new(opts, :id, id)
    add_node(builder, :end_event, opts)
  end

  def add_activity(builder, id, opts \\ []) do
    opts = Keyword.put_new(opts, :id, id)
    add_node(builder, :activity, opts)
  end

  def add_user_task(builder, id, opts \\ []) do
    opts = Keyword.put_new(opts, :id, id)
    add_node(builder, :user_task, opts)
  end

  def add_gateway(builder, id, opts \\ []) do
    opts = Keyword.put_new(opts, :id, id)
    add_node(builder, :gateway, opts)
  end

  def build(builder) do
    # Find the start node to get its ID
    start_node =
      Enum.find(builder.nodes, fn {type, _opts} -> type == :start_event end)

    unless start_node do
      raise "Workflow must have at least one start_event"
    end

    {_type, start_node_opts} = start_node
    start_node_id = Keyword.fetch!(start_node_opts, :id)

    # Start the engine with the correct start_node_id
    case Engine.start_link(workflow_id: builder.workflow_id, start_node_id: start_node_id) do
      {:ok, _pid} ->
        # Add all nodes to the newly started engine
        Enum.each(builder.nodes, fn {type, opts} ->
          :ok = Engine.add_node(builder.workflow_id, type, opts)
        end)

        {:ok, builder.workflow_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Facade functions for interacting with the workflow

  def start(workflow_id, initial_data \\ %{}) do
    Engine.start_workflow(workflow_id, initial_data)
  end

  def visualize(workflow_id) do
    BpmnWorkflow.Visualizer.visualize(workflow_id)
  end

  defp add_node(builder, type, opts) do
    %{builder | nodes: [{type, opts} | builder.nodes]}
  end
end