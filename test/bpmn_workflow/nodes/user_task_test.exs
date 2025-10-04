defmodule BpmnWorkflow.Nodes.UserTaskTest do
  use ExUnit.Case, async: true

  alias BpmnWorkflow.Nodes.UserTask
  alias BpmnWorkflow.Token

  setup do
    # Start the UserTask node
    opts = [
      id: "test_user_task",
      name: "Test User Task",
      next_nodes: ["next_node"],
      engine_pid: self()
    ]

    {:ok, pid} = UserTask.start_link(opts)
    %{user_task_pid: pid}
  end

  test "execute puts the task in a waiting state", %{user_task_pid: _pid} do
    token = Token.new(%{some_data: "initial"})
    :ok = UserTask.execute("test_user_task", token)

    # Assert that the engine received the waiting message
    assert_receive {:user_task_waiting, "test_user_task", received_token}
    assert received_token.data == %{some_data: "initial"}
  end

  test "trigger completes the task and forwards the token", %{user_task_pid: _pid} do
    token = Token.new(%{some_data: "initial"})
    UserTask.execute("test_user_task", token)

    # Clear the waiting message from the mailbox
    receive do
      {:user_task_waiting, _, _} -> :ok
    after
      100 -> :no_message
    end

    # Trigger the task
    :ok = UserTask.trigger("test_user_task", %{extra_data: "triggered"})

    # Assert that the node was executed
    assert_receive {:node_executed, "test_user_task", result_token}
    assert result_token.data == %{some_data: "initial", extra_data: "triggered"}

    # Assert that the token was forwarded
    assert_receive {:forward_token, "next_node", result_token}
    assert result_token.data == %{some_data: "initial", extra_data: "triggered"}
  end

  test "trigger returns an error if the task is not waiting", %{user_task_pid: _pid} do
    # Don't execute the task, so it's not waiting
    assert {:error, :not_waiting} == UserTask.trigger("test_user_task", %{})
  end
end