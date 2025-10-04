defmodule BpmnWorkflow.Nodes.Activity do
  @moduledoc """
  Activity node - performs work in the workflow.
  Runs as an independent GenServer worker.
  Can execute custom functions passed during initialization.
  """

  use GenServer
  require Logger

  defstruct [:id, :name, :next_nodes, :engine_pid, :work_fn]

  # Client API

  def start_link(opts) do
    id = Keyword.fetch!(opts, :id)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(id))
  end

  def execute(id, token) do
    GenServer.cast(via_tuple(id), {:execute, token})
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    state = %__MODULE__{
      id: opts[:id],
      name: opts[:name] || "Activity",
      next_nodes: opts[:next_nodes] || [],
      engine_pid: opts[:engine_pid],
      work_fn: opts[:work_fn] || (&default_work/1)
    }

    Logger.info("Activity[#{state.id}] initialized: #{state.name}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, token}, state) do
    Logger.info("Activity[#{state.id}] executing work: #{state.name}")

    # Update token position
    updated_token = BpmnWorkflow.Token.move_to(token, state.id)

    # Perform work
    result_token = state.work_fn.(updated_token)

    Logger.info("Activity[#{state.id}] completed work")

    # Notify engine
    send(state.engine_pid, {:node_executed, state.id, result_token})

    # Forward to next nodes
    Enum.each(state.next_nodes, fn next_node_id ->
      send(state.engine_pid, {:forward_token, next_node_id, result_token})
    end)

    {:noreply, state}
  end

  defp default_work(token) do
    # Default behavior: just pass the token through
    token
  end

  defp via_tuple(id) do
    {:via, Registry, {BpmnWorkflow.NodeRegistry, {:activity, id}}}
  end
end
