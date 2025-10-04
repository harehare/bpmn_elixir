defmodule BpmnWorkflow.Token do
  @moduledoc """
  Represents a token that flows through the BPMN workflow.
  A token carries data and tracks its current position in the workflow.
  """

  defstruct [:id, :data, :current_node, :timestamp]

  @type t :: %__MODULE__{
          id: String.t(),
          data: map(),
          current_node: String.t(),
          timestamp: DateTime.t()
        }

  @doc """
  Creates a new token with the given data.
  """
  def new(data \\ %{}) do
    %__MODULE__{
      id: generate_id(),
      data: data,
      current_node: nil,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Moves the token to a new node.
  """
  def move_to(token, node_id) do
    %{token | current_node: node_id, timestamp: DateTime.utc_now()}
  end

  @doc """
  Updates the token's data.
  """
  def update_data(token, new_data) do
    %{token | data: Map.merge(token.data, new_data)}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
