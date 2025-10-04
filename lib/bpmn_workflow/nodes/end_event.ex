defmodule BpmnWorkflow.Nodes.EndEvent do
  @moduledoc """
  EndEvent node - terminates the workflow.
  Runs as an independent GenServer worker.
  """

  use GenServer
  require Logger

  defstruct [:id, :name, :engine_pid]

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
      name: opts[:name] || "End Event",
      engine_pid: opts[:engine_pid]
    }

    Logger.info("EndEvent[#{state.id}] initialized: #{state.name}")
    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, token}, state) do
    Logger.info("EndEvent[#{state.id}] executing with token #{token.id}")

    # Update token position
    updated_token = BpmnWorkflow.Token.move_to(token, state.id)

    # Notify engine that workflow is complete
    send(state.engine_pid, {:node_executed, state.id, updated_token})
    send(state.engine_pid, {:workflow_completed, state.id, updated_token})

    {:noreply, state}
  end

  defp via_tuple(id) do
    {:via, Registry, {BpmnWorkflow.NodeRegistry, {:end_event, id}}}
  end
end
