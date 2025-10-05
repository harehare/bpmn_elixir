# Bpmn Elixir

A BPMN (Business Process Model and Notation) workflow engine implemented in Elixir with independent worker processes for each node type.

## Features

- **Independent Workers**: Each BPMN node (StartEvent, EndEvent, Activity, Gateway) runs as an independent GenServer process
- **Decoupled Architecture**: Nodes communicate through message passing, ensuring loose coupling
- **Gateway Support**: Exclusive (XOR), Parallel (AND), and Inclusive (OR) gateways
- **In-Memory State**: Fast, in-memory workflow execution and state management
- **Console Visualization**: ASCII-based workflow visualization showing current execution state
- **Real-time Monitoring**: Track token flow and execution history

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Application Supervisor                     │
├─────────────────────────────────────────────────────────────┤
│  - EngineRegistry (Registry for workflow engines)           │
│  - NodeRegistry (Registry for node workers)                 │
│  - EngineSupervisor (DynamicSupervisor for engines)         │
│  - NodeSupervisor (DynamicSupervisor for nodes)             │
└─────────────────────────────────────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
          ┌──────▼──────┐          ┌──────▼──────┐
          │   Engine    │          │    Nodes    │
          │  (GenServer)│          │ (GenServers)│
          └─────────────┘          └─────────────┘
                 │                         │
                 │                    ┌────┴────┐
                 │                    │         │
                 │              ┌─────▼────┐ ┌─▼────────┐
                 │              │StartEvent│ │Activity  │
                 │              └──────────┘ └──────────┘
                 │              ┌──────────┐ ┌──────────┐
                 └──────────────│  Gateway │ │EndEvent  │
                                └──────────┘ └──────────┘
```

## BPMN Node Types

### StartEvent
- Initiates the workflow
- Can have multiple output flows
- Independent GenServer worker

### EndEvent
- Terminates the workflow
- Marks token as completed
- Independent GenServer worker

### Activity
- Performs work/tasks
- Supports custom work functions
- Independent GenServer worker

### Gateway
- **Exclusive (XOR)**: Takes one path based on condition
- **Parallel (AND)**: Executes all paths simultaneously
- **Inclusive (OR)**: Executes all matching paths
- Independent GenServer worker

## Installation

```bash
cd bpmn_workflow
mix deps.get
```

## Usage

### Basic Example

```elixir
# Start the application
{:ok, _} = Application.ensure_all_started(:bpmn_workflow)

alias BpmnWorkflow.Builder

# Create a simple workflow
workflow_id = "my_workflow"

Builder.create_workflow(workflow_id, "start")
|> Builder.add_start_event("start", next_nodes: ["task1"])
|> Builder.add_activity("task1",
  name: "Process Data",
  next_nodes: ["end"],
  work_fn: fn token ->
    # Perform work here
    BpmnWorkflow.Token.update_data(token, %{processed: true})
  end
)
|> Builder.add_end_event("end")

# Start execution
{:ok, token_id} = Builder.start(workflow_id, %{input: "data"})

# Visualize
Builder.visualize(workflow_id)
```

### Running Examples

```bash
# Simple sequential workflow
cd bpmn_workflow
mix run examples/simple_workflow.exs

# Gateway workflow (conditional branching)
mix run examples/gateway_workflow.exs

# Parallel workflow (concurrent execution)
mix run examples/parallel_workflow.exs
```

## Console Visualization

The visualizer displays:

- **Workflow diagram** with ASCII art
- **Active nodes** marked with indicators
- **Token status** (active/completed)
- **Execution history** with timestamps
- **Token data** for debugging

Example output:

```
================================================================================
Workflow: simple_workflow
Status: running
================================================================================

Workflow Diagram:

  (○) start
   |
  [task1              ] ← ACTIVE
   |
  [task2              ]
   |
  (◉) end

Execution Info:
  Active Tokens: 1
  Completed Tokens: 0
  Total Nodes: 4

  Active Token Details:
    - Token 3a4b5c6d
      Current Node: task1
      Data: %{customer: "John Doe"}

Recent Execution History (last 10 events):
  14:23:45 | Node: start | Token: 3a4b5c6d
  14:23:45 | Node: task1 | Token: 3a4b5c6d

================================================================================
```

## Key Concepts

### Token
- Represents a workflow instance
- Carries data through the workflow
- Tracks current position

### Engine
- Coordinates workflow execution
- Routes tokens between nodes
- Maintains execution state

### Decoupled Workers
- Each node is an independent process
- Communication via message passing
- No direct dependencies between nodes

## Testing

```bash
cd bpmn_workflow
mix test
```

## License

This project is created as an example/demo implementation.
