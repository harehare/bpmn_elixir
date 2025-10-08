defmodule BpmnWorkflow.MixProject do
  use Mix.Project

  def project do
    [
      app: :bpmn_workflow,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {BpmnWorkflow.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.19"},
      {:ecto_sqlite3, "~> 0.18"}
    ]
  end
end
