# Project Florent: Neuro-Symbolic Infrastructure Risk Analysis

This project represents a synthesis of Traditional Graph Theory (symbolic, deterministic) and Neuro-Symbolic Agentic Intelligence (probabilistic, contextual). By mapping a Firm's capabilities against a Project's DAG topology, we can move beyond simple risk matrices to a dynamic, multi-hop risk assessment.

## Primary Objectives

The system focuses on two critical pillars of infrastructure analysis:

1.  **Risk Profiling**: Determining the Strategic Alignment and Operational Risk between a Firm Object (the Bidder/Consultant) and a Project Object (the Infrastructure DAG).
2.  **Dependency Mapping & Propagation (Critical)**: Identifying nodes most critical to project success and those that pose systemic risks to the firm. The system predicts and visualizes how a failure in a single upstream node propagates down the chain, potentially blocking entire project routes.

By traversing the project dependencies, the system classifies every node into a 2x2 Risk-Influence Matrix, identifying manageable tasks, critical dependencies, and potential deal-breakers.

## The Methodology: Agents & Cross-Attention

We utilize DSPy-powered Agents to perform "Context-Aware Traversal." Unlike a standard Breadth-First Search (BFS), our agents use Cross-Attention to weight the importance of nodes based on the intersection of Firm and Project attributes.

### Logical End-to-End Flow

The system processes data through the following pipeline:

1.  **Data Ingestion**: Loading `firm.json` (bidder portfolio) and `project.json` (infrastructure requirements) into our Entity models.
2.  **Topological Construction**: Initializing the `Graph` object and building the DAG where each node is enriched with embeddings from the entity's attributes.
3.  **Agentic Weighting (DSPy)**: 
    *   Deploying the **Extractor Agent** to pull deep context from project requirements and country-specific registries.
    *   Using the **Evaluator Agent** with a BGE-M3 Cross-Encoder to perform "Cross-Attention" between the Firm’s Query and the Node’s Key, generating a raw Influence Score ($I_n$).
4.  **Graph Traversal & Propagation**: 
    *   Navigating the DAG to find all paths/chains from the primary project entry point.
    *   The **Propagator Agent** applies the mathematical formulas from `risk.py` to calculate the Cascading Risk Score ($R_{total}$) across every downstream dependency.
5.  **Risk Clustering & Evaluation**:
    *   Using K-Means Clustering on the resulting node vectors to identify systemically risky sectors.
    *   The system identifies "Critical Chains"—sequences of tasks that, if failed, block the entire project.
6.  **Matrix Output**: Mapping findings to the 2x2 Action Matrix to determine Strategic Actions (Mitigate, Automate, Contingency, Delegate).

### Dependency & Inference Deployment

For the "Cross-Attention" weighting, we utilize the **BGE-M3 Cross-Encoder** (Re-ranker) via a high-performance inference container.

**Docker Configuration:**
```yaml
services:
  cross-encoder:
    image: ghcr.io/huggingface/text-embeddings-inference:cpu-latest
    command: --model-id BAAI/bge-reranker-v2-m3
    ports:
      - "8080:80"
```

*Note: For GPU acceleration, use the `gpu-latest` tag.*

## Mathematical Framework

### A. Influence Score (I_n)

The influence a firm has over a node n is calculated by the cosine similarity between the Firm's capability vector (F) and the Node's requirement vector (R), scaled by the node's Centrality in the DAG.

$$I_n = (\frac{\vec{F} \cdot \vec{R}}{\|\vec{F}\| \|\vec{R}\|}) \times EigenCentrality(n)$$

### B. Cascading Risk Score (R_total)

We use a Product of Success formula to determine the risk of a node n based on its parents (pa):

$$P(Success_n) = (1 - P(Failure_{local})) \times \prod_{i \in pa(n)} P(Success_i)$$

## The Output: The 2x2 Action Matrix

The system maps every node n into one of four quadrants for the Consultant/Bidder:

| Quadrant | Risk vs. Influence | Description | Strategic Action |
| :--- | :--- | :--- | :--- |
| **Q1: Known Knowns** | High Risk, High Influence | Complex tasks where the firm has deep expertise. | **Mitigate**: Direct oversight and custom workflows. |
| **Q2: The "No Biggie"** | Low Risk, High Influence | Routine tasks that the firm excels at. | **Automate**: Use standard operating procedures. |
| **Q3: The "Cooked" Zone** | High Risk, Low Influence | Critical project dependencies outside the firm's control. | **Contingency**: Buy insurance or demand legal indemnification. |
| **Q4: The Basic Shit** | Low Risk, Low Influence | Minor peripheral tasks. | **Delegate**: Subcontract or monitor minimally. |

## Future Direction: Iterative Optimization (The "SPICE" Method)

To reach the high-impact threshold, we are building an **Optimization Layer** that treats the infrastructure DAG as a dynamic circuit:

1.  **PyTorch Topology**: We generate a PyTorch module whose internal neural structure is a 1:1 topological map of the project DAG.
2.  **Iterative Simulation**: Using an approach inspired by SPICE (Simulation Program with Integrated Circuit Emphasis), the system performs iterative passes over the graph.
3.  **Combinatorial Search**: It simulates a range of realistic project alterations and recommended customizations (e.g., extended timelines, adjusted budget allocations, or phased mobilizations).
4.  **Risk Minimization & Scenario Generation**: The model weights metrics across these iterations to find the **Optimal Outcome** while also identifying the **Worst-Case Scenario**. It returns a distribution of different outcomes/scenarios, allowing stakeholders to visualize the variance between the safest and riskiest paths.

This makes the system not just an "analyzer" but a "simulator" capable of prescribing the safest path and stress-testing the project against a spread of probable outcomes.

## The I/O Contract (Proof of Concept)

To ensure the system provides actionable insights and rich visualizations, we follow a strict I/O contract:

### 1. Ingestion (Input)
We use standardized JSON payloads for the **Firm** (bidder) and **Project** (requirements):
- **`firm.json`**: Portfolio data including regional footprint, sector expertise, and service offerings.
- **`project.json`**: Infrastructure DAG requirements, including topological constraints, budget/timeline bounds, and entry/exit criteria.

### 2. Intelligent Output (Client-Centric Insights)
The system returns a high-value **Analysis Output Object** designed for both automated dashboards and strategic advisory:

- **Risk Tensors**: Raw PyTorch tensors representing the multi-dimensional distribution of risk across the topological manifold.
- **Critical Failure Chains**: Identified sequences of dependent nodes where a single failure propagates a non-recoverable project state.
- **Pivotal Linchpins**: High-importance nodes that have the highest mathematical weight in determining downstream project integrity.
- **Stress-Test Spreads**: Simulations showing the gap between the **Optimal Path** and the **Systemic Worst-Case**.

This makes Florent a "Decision Support Engine" rather than a simple data visualizer, providing the Firm with the exact levers they need to pull to secure project success.

## Implementation Architecture

*   **Primitives (base.py)**: The ground-truth metadata (ISO Country codes, Sector enums).
*   **Entities (entities.py)**: The "Firm" and "Project" objects—our data containers.
*   **Topology (graph.py)**: The DAG structure where nodes hold embeddings of the entities.
*   **Inference Layer (agents.py)**: DSPy agents performing the cross-attention weighting and traversal.

**Note on Clustering**: We use traditional K-Means Clustering on the resulting node vectors to group "Risk Clusters," allowing the agent to flag entire sectors of a project as "Systemically Risky" rather than just looking at isolated nodes.