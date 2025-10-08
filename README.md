# Bpmn Elixir

A BPMN (Business Process Model and Notation) workflow engine implemented in Elixir with independent worker processes for each node type.

## Features

- **Independent Workers**: Each BPMN node (StartEvent, EndEvent, Activity, Gateway) runs as an independent GenServer process
- **Decoupled Architecture**: Nodes communicate through message passing, ensuring loose coupling
- **Gateway Support**: Exclusive (XOR), Parallel (AND), and Inclusive (OR) gateways
- **In-Memory State**: Fast, in-memory workflow execution and state management
- **Persistent Storage**: Database support for workflow definitions and executions (SQLite/PostgreSQL)
- **REST API**: Full HTTP API for workflow management and execution
- **Console Visualization**: ASCII-based workflow visualization showing current execution state
- **Real-time Monitoring**: Track token flow and execution history
- **User Tasks**: Support for human tasks with HTTP API integration

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

# Run database migrations
mix ecto.create
mix ecto.migrate
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

## REST API

The application provides a complete REST API for managing workflow definitions and executions.

### Start the HTTP Server

```bash
mix run --no-halt
# Server starts on http://localhost:4000
```

### API Endpoints

#### Workflow Definitions

```bash
# Create a workflow definition
curl -X POST http://localhost:4000/api/definitions \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Simple Workflow",
    "description": "A simple workflow example",
    "definition": {
      "start_node_id": "start1",
      "nodes": [
        {"id": "start1", "type": "start_event", "name": "Start", "next_nodes": ["task1"]},
        {"id": "task1", "type": "user_task", "name": "Review Task", "next_nodes": ["end1"], "form_fields": ["comment"]},
        {"id": "end1", "type": "end_event", "name": "End"}
      ]
    }
  }'

# List all definitions
curl http://localhost:4000/api/definitions

# Get a definition by ID
curl http://localhost:4000/api/definitions/{id}

# Get a definition by name
curl http://localhost:4000/api/definitions/by-name/Simple%20Workflow

# Update a definition
curl -X PUT http://localhost:4000/api/definitions/{id} \
  -H "Content-Type: application/json" \
  -d '{"description": "Updated description"}'

# Deactivate a definition (soft delete)
curl -X DELETE http://localhost:4000/api/definitions/{id}/deactivate

# Delete a definition
curl -X DELETE http://localhost:4000/api/definitions/{id}
```

#### Workflow Executions

```bash
# Create and start a workflow execution
curl -X POST http://localhost:4000/api/executions \
  -H "Content-Type: application/json" \
  -d '{
    "definition_id": "definition-uuid-here",
    "workflow_id": "my-workflow-001",
    "initial_data": {"customer": "John Doe"}
  }'

# List all executions
curl http://localhost:4000/api/executions

# List executions by status
curl "http://localhost:4000/api/executions?status=running"

# Get execution by ID
curl http://localhost:4000/api/executions/{id}

# Get execution by workflow_id
curl http://localhost:4000/api/executions/by-workflow-id/my-workflow-001

# Sync execution state to database
curl -X POST http://localhost:4000/api/executions/{id}/sync

# Restore execution to engine
curl -X POST http://localhost:4000/api/executions/{id}/restore

# Delete execution
curl -X DELETE http://localhost:4000/api/executions/{id}
```

#### Workflow Status (In-Memory)

```bash
# Get workflow status
curl http://localhost:4000/api/workflows/my-workflow-001/status

# Get full workflow state
curl http://localhost:4000/api/workflows/my-workflow-001/state

# Get token status
curl http://localhost:4000/api/workflows/my-workflow-001/tokens/{token-id}
```

#### User Tasks

```bash
# List pending user tasks
curl http://localhost:4000/api/user_tasks/workflow/my-workflow-001

# Get user task details
curl http://localhost:4000/api/user_tasks/my-workflow-001/task1/{token-id}

# Complete a user task
curl -X POST http://localhost:4000/api/user_tasks/my-workflow-001/task1/{token-id}/complete \
  -H "Content-Type: application/json" \
  -d '{"comment": "Approved"}'
```

#### Node Executions (Tracking)

```bash
# List all node executions for a workflow
curl http://localhost:4000/api/node_executions/workflow/my-workflow-001

# Filter by status
curl "http://localhost:4000/api/node_executions/workflow/my-workflow-001?status=completed&limit=10"

# Get node executions for a specific token (trace token path)
curl http://localhost:4000/api/node_executions/workflow/my-workflow-001/token/{token-id}

# Get executions for a specific node
curl http://localhost:4000/api/node_executions/workflow/my-workflow-001/node/task1

# Get execution statistics
curl http://localhost:4000/api/node_executions/workflow/my-workflow-001/statistics

# Get specific node execution details
curl http://localhost:4000/api/node_executions/{execution-id}
```

## Database Configuration

### SQLite (Default)

```elixir
# config/dev.exs
config :bpmn_workflow, BpmnWorkflow.Repo,
  database: "bpmn_workflow_dev.db",
  pool_size: 5
```

### PostgreSQL

Set the environment variable:

```bash
export DATABASE_ADAPTER=postgres
```

Then configure in `config/dev.exs`:

```elixir
config :bpmn_workflow, BpmnWorkflow.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "bpmn_workflow_dev",
  pool_size: 10
```

## Testing

```bash
cd bpmn_workflow
mix test
```

## License

This project is created as an example/demo implementation.
