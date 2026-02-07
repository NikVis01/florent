# Project Florent: Neuro-Symbolic Infrastructure Risk Analysis

This project represents a synthesis of Traditional Graph Theory (symbolic, deterministic) and Neuro-Symbolic Agentic Intelligence (probabilistic, contextual). By mapping a Firm's capabilities against a Project's DAG topology, we can move beyond simple risk matrices to a dynamic, multi-hop risk assessment.

## The Objective

To determine the Strategic Alignment and Operational Risk between a Firm Object (the Bidder/Consultant) and a Project Object (the Infrastructure DAG).

By traversing the project’s dependencies through the lens of the firm’s specific service portfolio and regional context, the system classifies every node into a 2x2 Risk-Influence Matrix, identifying what is manageable, what is critical, and what is a potential "deal-breaker."

## The Methodology: Agents & Cross-Attention

We utilize DSPy-powered Agents to perform "Context-Aware Traversal." Unlike a standard Breadth-First Search (BFS), our agents use Cross-Attention to weight the importance of nodes based on the intersection of Firm and Project attributes.

### 1. Cross-Attention Mechanism (The Weighting)

We treat the Firm Portfolio as the Query (Q) and the Project Requirements as the Keys (K).

*   **Query (Q)**: Firm's "Strategic Focus" + "Sectors" + "Active Regions."
*   **Key (K)**: Node's "Operation Type" + "Technical Requirements" + "ISO Metadata."
*   **Value (V)**: The base risk/impact score of the node.

The "Attention" score determines how much the Firm’s specific DNA influences a particular node. High attention means the firm has high Influence over that task.

### 2. DSPy Agent Traversal (The Risk Scouts)

We deploy agents using DSPy Signatures to navigate the Graph Topology:

*   **The Extractor Agent**: Pulls context from the Project requirements and Country metadata.
*   **The Evaluator Agent**: Uses a Predict module to assign a probability of failure (P_f) to each node by comparing project requirements against firm history.
*   **The Propagator Agent**: Traverses the DAG to calculate the "Blast Radius." If a high-dependency node fails, how many downstream nodes are "cooked"?

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

## Implementation Architecture

*   **Primitives (base.py)**: The ground-truth metadata (ISO Country codes, Sector enums).
*   **Entities (entities.py)**: The "Firm" and "Project" objects—our data containers.
*   **Topology (graph.py)**: The DAG structure where nodes hold embeddings of the entities.
*   **Inference Layer (agents.py)**: DSPy agents performing the cross-attention weighting and traversal.

**Note on Clustering**: We use traditional K-Means Clustering on the resulting node vectors to group "Risk Clusters," allowing the agent to flag entire sectors of a project as "Systemically Risky" rather than just looking at isolated nodes.
