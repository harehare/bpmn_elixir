defmodule BpmnWorkflow.Nodes.StartEvent do
  @moduledoc """
  StartEvent node - initiates the workflow.
  Runs as an independent GenServer worker.
  """

  use GenServer
  require Logger

  defstruct [:id, :name, :next_nodes, :engine_pid]

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
      name: opts[:name] || "Start Event",
      next_nodes: opts[:next_nodes] || [],
      engine_pid: opts[:engine_pid]
    }

    Logger.info("StartEvent[#{state.id}] initialized: #{state.name}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, token}, state) do
    Logger.info("StartEvent[#{state.id}] executing with token #{token.id}")

    # Update token position
    updated_token = BpmnWorkflow.Token.move_to(token, state.id)

    # Notify engine
    send(state.engine_pid, {:node_executed, state.id, updated_token})

    # Forward to next nodes
    Enum.each(state.next_nodes, fn next_node_id ->
      send(state.engine_pid, {:forward_token, next_node_id, updated_token})
    end)

    {:noreply, state}
  end

  defp via_tuple(id) do
    {:via, Registry, {BpmnWorkflow.NodeRegistry, {:start_event, id}}}
  end
end
