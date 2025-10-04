defmodule BpmnWorkflow.Nodes.Gateway do
  @moduledoc """
  Gateway node - makes routing decisions in the workflow.
  Supports exclusive (XOR), parallel (AND), and inclusive (OR) gateway types.
  Runs as an independent GenServer worker.
  """

  use GenServer
  require Logger

  @type gateway_type :: :exclusive | :parallel | :inclusive

  defstruct [:id, :name, :type, :next_nodes, :engine_pid, :condition_fn]

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
      name: opts[:name] || "Gateway",
      type: opts[:type] || :exclusive,
      next_nodes: opts[:next_nodes] || [],
      engine_pid: opts[:engine_pid],
      condition_fn: opts[:condition_fn] || (&default_condition/2)
    }

    Logger.info("Gateway[#{state.id}] initialized: #{state.name} (#{state.type})")
    {:ok, state}
  end

  @impl true
  def handle_cast({:execute, token}, state) do
    Logger.info("Gateway[#{state.id}] evaluating (#{state.type})")

    # Update token position
    updated_token = BpmnWorkflow.Token.move_to(token, state.id)

    # Notify engine
    send(state.engine_pid, {:node_executed, state.id, updated_token})

    # Route based on gateway type
    route_token(state, updated_token)

    {:noreply, state}
  end

  # Route token based on gateway type
  defp route_token(%{type: :exclusive} = state, token) do
    # Exclusive gateway: take only one path
    target_nodes = Enum.filter(state.next_nodes, fn node_id ->
      state.condition_fn.(token, node_id)
    end)

    case target_nodes do
      [] ->
        Logger.warning("Gateway[#{state.id}] no matching condition, taking first path")
        forward_to_first(state, token)

      [node_id | _] ->
        Logger.info("Gateway[#{state.id}] routing to #{node_id}")
        send(state.engine_pid, {:forward_token, node_id, token})

      _ ->
        Logger.info("Gateway[#{state.id}] multiple matches, taking first: #{hd(target_nodes)}")
        send(state.engine_pid, {:forward_token, hd(target_nodes), token})
    end
  end

  defp route_token(%{type: :parallel} = state, token) do
    # Parallel gateway: forward to all paths
    Logger.info("Gateway[#{state.id}] routing to all #{length(state.next_nodes)} paths")

    Enum.each(state.next_nodes, fn node_id ->
      # Create a copy of the token for each path
      send(state.engine_pid, {:forward_token, node_id, token})
    end)
  end

  defp route_token(%{type: :inclusive} = state, token) do
    # Inclusive gateway: forward to all matching paths
    target_nodes = Enum.filter(state.next_nodes, fn node_id ->
      state.condition_fn.(token, node_id)
    end)

    case target_nodes do
      [] ->
        Logger.warning("Gateway[#{state.id}] no matching conditions, taking all paths")
        Enum.each(state.next_nodes, fn node_id ->
          send(state.engine_pid, {:forward_token, node_id, token})
        end)

      nodes ->
        Logger.info("Gateway[#{state.id}] routing to #{length(nodes)} matching paths")
        Enum.each(nodes, fn node_id ->
          send(state.engine_pid, {:forward_token, node_id, token})
        end)
    end
  end

  defp forward_to_first(state, token) do
    case state.next_nodes do
      [node_id | _] -> send(state.engine_pid, {:forward_token, node_id, token})
      [] -> Logger.warning("Gateway[#{state.id}] has no next nodes")
    end
  end

  # Default condition: always true for first node
  defp default_condition(_token, node_id) do
    is_binary(node_id)
  end

  defp via_tuple(id) do
    {:via, Registry, {BpmnWorkflow.NodeRegistry, {:gateway, id}}}
  end
end
