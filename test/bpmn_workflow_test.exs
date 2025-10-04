defmodule BpmnWorkflowTest do
  use ExUnit.Case
  doctest BpmnWorkflow

  test "greets the world" do
    assert BpmnWorkflow.hello() == :world
  end
end
