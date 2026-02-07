# Agent Service: Neuro-Symbolic Graph Intelligence

This service implements the "Context-Aware Traversal" logic using a modular, neuro-symbolic architecture. We bypass high-level agent frameworks (like LangChain or LangGraph) in favor of a manual, deterministic control loop that manages the project DAG traversal.

## Core Philosophy: "No-LangChain"
We treat the Graph Traversal as a first-class citizen. Instead of letting an LLM decide the next step in a "black box" loop, we use classical data structures (Stack/Heap) to manage the execution state, while using **DSPy** for the intelligent reasoning at each node.

## Architecture

| Module | Component | Responsibility |
| :--- | :--- | :--- |
| **`orchestrator.py`** | Control Loop | Manages the Stack and Heap. Handles early exits for "Cooked" projects and prioritized exploration. |
| **`signatures.py`** | Interfaces | Defines the I/O "shape" for DSPy agents. Ensures structured data/tensors are passed between nodes. |
| **`traversal.py`** | Data Structs | Implements the **NodeStack** (LIFO) for Blast Radius analysis and **NodeHeap** (Priority Queue) for budget-based exploration. |
| **`tensor_ops.py`** | Mathematics | Isolated vector operations (Cosine Similarity, Influence Tensors, Risk Propagation) using NumPy/Torch. |

## Data Structures & Usage

### 1. NodeStack (LIFO)
Used for **Upstream Risk Propagation**. When a node is flagged as high-risk, we push its parents onto the stack to re-evaluate the "Blast Radius" of failure.

### 2. NodeHeap (Priority Queue)
Used for **Budgeted Exploration**. The orchestrator spends its computation budget (tokens) on the most critical infrastructure nodes first, prioritized by their influence and centrality scores.

## Agent Signatures
We use structured signatures to bridge natural language reasoning with mathematical scoring:
- **`NodeSignature`**: `(Firm Context + Node Requirements) -> (Influence Score + Risk Assessment + Reasoning)`
- **`PropagationSignature`**: `(Upstream Risk + Local Factors) -> Cascading Risk Score`

## Deployment
The agent service interacts with a **BGE-M3 Cross-Encoder** inference container for high-fidelity cross-attention between firm capabilities and project requirements.
