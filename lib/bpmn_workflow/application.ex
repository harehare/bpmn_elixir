defmodule BpmnWorkflow.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Registry for workflow engines
      {Registry, keys: :unique, name: BpmnWorkflow.EngineRegistry},
      # Registry for node workers
      {Registry, keys: :unique, name: BpmnWorkflow.NodeRegistry},
      # DynamicSupervisor for node workers
      {DynamicSupervisor, strategy: :one_for_one, name: BpmnWorkflow.NodeSupervisor},
      # DynamicSupervisor for workflow engines
      {DynamicSupervisor, strategy: :one_for_one, name: BpmnWorkflow.EngineSupervisor}
    ]

    opts = [strategy: :one_for_one, name: BpmnWorkflow.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
