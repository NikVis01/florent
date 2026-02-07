# Florent Technical Roadmap

## 1. The Math Formulae (The "Three Pillars")

### I. The Cross-Encoder Influence Score ($I_n$)
Used to calculate the Firm’s control over a specific node.
$$I_n = \sigma(\text{MLP}(\text{Attention}(\vec{F}, \vec{R}))) \cdot \gamma^{-d}$$
- **Mechanism**: Concatenate Firm $\vec{F}$ and Requirement $\vec{R}$ vectors.
- **$\gamma^{-d}$**: A decay factor where $d$ is the distance from the firm's direct "entry" node in the project.

### II. The Topological Risk Propagation ($R_n$)
Calculates the "Blast Radius."
$$R_n = 1 - \left[ (1 - P(f_{\text{local}}) \cdot \mu) \cdot \prod_{i \in \text{parents}(n)} (1 - R_i) \right]$$
- **$\mu$**: Critical path multiplier from `metrics.json`.
- **Logic**: If a parent dependency has a 50% risk, the child's risk cannot be lower than 50%.

### III. The Normalized Metric Validation ($V_n$)
The symbolic check against your `metrics.json`.
$$V_n = \sum_{i=1}^{k} (m_i \cdot w_i)$$
- **$m_i$**: Individual scores (Bankability, Sustainability) extracted by agents.
- **$w_i$**: Hard-coded weights.

---

## 2. Agentic Architecture (DSPy Signatures)

Since we are using manual loops, our agents are **Atomic Functions** called during traversal.

### The "Scout" (Evaluator)
- **Input**: Firm object + Node requirements + Country metadata.
- **Output**: Local $P(f)$ and Influence $I_n$.
- **Manual Exit**: If $P(f) > 0.9$ and node is "Critical," the loop triggers an immediate `HEAVY_RISK_EXIT`.

### The "Scribe" (Aggregator)
- **Input**: All traversed node scores.
- **Output**: The final $2 \times 2$ Matrix mapping.

---

## 3. Data Structures & Memory Management

Optimized for a CPU-only environment.

### A. The Stack (Graph Traversal)
- **Use Case**: Depth-First Search (DFS) for Risk Propagation.
- **Why**: When calculating the "Cooked" status of a downstream node, you need to go deep into the dependency chain. A manual Stack (`list.pop()`) is more memory-efficient than recursion for deep infra DAGs.

### B. The Heap / Priority Queue (Risk Frontier)
- **Use Case**: Risk-First Processing.
- **Why**: Use a Min-Heap to store nodes to be processed, prioritized by their Risk Multiplier. Evaluates the most dangerous nodes first. If a high-priority node fails validation, the loop exits before wasting tokens.

### C. Linked List (Audit Trail / Provenance)
- **Use Case**: Explanation Path.
- **Why**: Each node points to its "Risk Parent" via a Linked List structure. Allows traversing back from a "Cooked" node to the root cause (e.g., country affiliation failure).

---

## 4. Implementation Overview

- **Dataclasses**: Located in `src/models/entities.py`.
- **Manual Control Loop**: The "Engine" coordinating agents and traversal.

---

## 5. Summary Table

| Component | Responsibility | Performance Target |
| :--- | :--- | :--- |
| **Scout Agent** | Local Node Evaluation | < 2s Latency |
| **Scribe Agent** | Global Aggregation | Single Token Pass |
| **Risk Heap** | Priority Computation | $O(\log N)$ |
| **Audit LL** | Tracking Provenance | $O(D)$ where $D$ is depth |
