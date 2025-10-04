defmodule BpmnWorkflow.Visualizer do
  @moduledoc """
  Console-based visualization for BPMN workflows.
  Displays the current state of the workflow in ASCII art.
  """

  @doc """
  Visualizes the workflow state in the console.
  """
  def visualize(workflow_id) do
    case BpmnWorkflow.Engine.get_state(workflow_id) do
      %{} = state ->
        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("Workflow: #{state.workflow_id}")
        IO.puts("Status: #{state.status}")
        IO.puts(String.duplicate("=", 80))

        display_workflow_diagram(state)
        display_execution_info(state)
        display_history(state)

        IO.puts(String.duplicate("=", 80) <> "\n")

      _ ->
        IO.puts("Workflow not found")
    end
  end

  # Displays a simple ASCII diagram of the workflow.
  defp display_workflow_diagram(state) do
    IO.puts("\nWorkflow Diagram:")
    IO.puts("")

    # Group nodes by type
    start_nodes = get_nodes_by_type(state.nodes, :start_event)
    end_nodes = get_nodes_by_type(state.nodes, :end_event)
    activities = get_nodes_by_type(state.nodes, :activity)
    gateways = get_nodes_by_type(state.nodes, :gateway)

    # Get current node from active tokens
    current_nodes =
      state.active_tokens
      |> Enum.map(& &1.current_node)
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    # Display nodes
    if length(start_nodes) > 0 do
      Enum.each(start_nodes, fn node_id ->
        marker = if MapSet.member?(current_nodes, node_id), do: " ← ACTIVE", else: ""
        IO.puts("  (○) #{node_id}#{marker}")
      end)

      IO.puts("   |")
    end

    if length(activities) > 0 do
      Enum.each(activities, fn node_id ->
        marker = if MapSet.member?(current_nodes, node_id), do: " ← ACTIVE", else: ""
        IO.puts("  [#{String.pad_trailing(node_id, 20)}]#{marker}")
        IO.puts("   |")
      end)
    end

    if length(gateways) > 0 do
      Enum.each(gateways, fn node_id ->
        marker = if MapSet.member?(current_nodes, node_id), do: " ← ACTIVE", else: ""
        IO.puts("  <#{String.pad_trailing(node_id, 20)}>#{marker}")
        IO.puts("   |")
      end)
    end

    if length(end_nodes) > 0 do
      Enum.each(end_nodes, fn node_id ->
        marker = if MapSet.member?(current_nodes, node_id), do: " ← COMPLETED", else: ""
        IO.puts("  (◉) #{node_id}#{marker}")
      end)
    end

    IO.puts("")
  end

  # Displays execution information (tokens, status).
  defp display_execution_info(state) do
    IO.puts("Execution Info:")
    IO.puts("  Active Tokens: #{length(state.active_tokens)}")
    IO.puts("  Completed Tokens: #{length(state.completed_tokens)}")
    IO.puts("  Total Nodes: #{map_size(state.nodes)}")

    if length(state.active_tokens) > 0 do
      IO.puts("\n  Active Token Details:")

      Enum.each(state.active_tokens, fn token ->
        IO.puts("    - Token #{String.slice(token.id, 0..7)}")
        IO.puts("      Current Node: #{token.current_node || "not started"}")
        IO.puts("      Data: #{inspect(token.data)}")
      end)
    end

    IO.puts("")
  end

  # Displays execution history (last 10 events).
  defp display_history(state) do
    if length(state.execution_history) > 0 do
      IO.puts("Recent Execution History (last 10 events):")

      state.execution_history
      |> Enum.take(10)
      |> Enum.reverse()
      |> Enum.each(fn {timestamp, node_id, token_id} ->
        time_str = Calendar.strftime(timestamp, "%H:%M:%S")
        token_short = String.slice(token_id, 0..7)
        IO.puts("  #{time_str} | Node: #{node_id} | Token: #{token_short}")
      end)

      IO.puts("")
    end
  end

  @doc """
  Prints a compact status line for the workflow.
  """
  def status_line(workflow_id) do
    case BpmnWorkflow.Engine.get_status(workflow_id) do
      %{} = status ->
        IO.puts(
          "[#{status.workflow_id}] Status: #{status.status} | " <>
            "Active: #{status.active_tokens} | Completed: #{status.completed_tokens}"
        )

      _ ->
        IO.puts("Workflow not found")
    end
  end

  defp get_nodes_by_type(nodes, type) do
    nodes
    |> Enum.filter(fn {_id, node_type} -> node_type == type end)
    |> Enum.map(fn {id, _type} -> id end)
    |> Enum.sort()
  end
end
