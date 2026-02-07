# Analysis Services

This module provides analytical tools for risk propagation and strategic classification of operations in a directed acyclic graph (DAG).

## Modules

### propagation.py

Implements cascading risk propagation through a DAG using topological sorting.

#### Key Function: `propagate_risk(graph, node_assessments, multiplier=1.2)`

Propagates risk scores through a graph in dependency order.

**Formula:**
```
R_n = 1 - [(1 - P_local × μ) × ∏(1 - R_parent)]
```

Where:
- `R_n`: Risk score for node n (output)
- `P_local`: Local failure probability (input)
- `μ`: Risk multiplier for critical paths (default: 1.2)
- `R_parent`: Risk scores of parent nodes (computed recursively)

**Parameters:**
- `graph`: Graph object containing nodes and edges
- `node_assessments`: Dict mapping node_id to assessment data
  - Must contain `"local_risk"` field with value in [0, 1]
  - Will be updated with `"risk"` field containing propagated score
- `multiplier`: Critical path multiplier (default: 1.2)

**Returns:**
- Updated `node_assessments` dictionary with cascading risk scores

**Example:**
```python
from src.models.graph import Graph
from src.services.analysis.propagation import propagate_risk

# Define initial assessments
assessments = {
    "A": {"local_risk": 0.2},
    "B": {"local_risk": 0.3},
    "C": {"local_risk": 0.1}
}

# Propagate risk through graph
result = propagate_risk(graph, assessments, multiplier=1.2)

# Access propagated risks
print(f"Node A risk: {result['A']['risk']}")
print(f"Node B risk: {result['B']['risk']}")
print(f"Node C risk: {result['C']['risk']}")
```

**Implementation Details:**

1. **Topological Sort**: Uses Kahn's algorithm to process nodes in dependency order
   - Ensures parent nodes are processed before children
   - Validates DAG property (no cycles)

2. **Risk Calculation**: For each node (in topological order):
   - Scales local risk by multiplier: `local_failure = min(1.0, local_risk × μ)`
   - Computes parent success probabilities: `P(success_parent) = 1 - R_parent`
   - Multiplies all parent success probabilities together
   - Combines with local success: `P(success_node) = (1 - local_failure) × ∏P(success_parent)`
   - Converts back to risk: `R_node = 1 - P(success_node)`

3. **Validation**:
   - All risks must be in [0, 1] range
   - All nodes must have assessments
   - Graph must be a valid DAG

### matrix.py

Classifies nodes into strategic action quadrants based on influence and risk scores.

#### Key Function: `generate_matrix(node_assessments)`

Groups nodes by strategic priority using a 2x2 matrix.

**Quadrants:**
- **Mitigate** (Q1): High Risk (>0.7), High Influence (>0.7)
  - Immediate attention required
  - Critical risks that can significantly impact success

- **Automate** (Q2): Low Risk (≤0.7), High Influence (>0.7)
  - Streamline and optimize
  - High-value operations running smoothly

- **Contingency** (Q3): High Risk (>0.7), Low Influence (≤0.7)
  - Prepare backup plans
  - Risky but lower impact operations

- **Delegate** (Q4): Low Risk (≤0.7), Low Influence (≤0.7)
  - Routine operations
  - Low priority for attention

**Parameters:**
- `node_assessments`: Dict with `"influence"` and `"risk"` keys for each node

**Returns:**
- Dict with quadrant names as keys and lists of node IDs as values

**Example:**
```python
from src.services.analysis.matrix import generate_matrix

# After risk propagation
assessments = {
    "A": {"risk": 0.8, "influence": 0.9},  # Mitigate
    "B": {"risk": 0.5, "influence": 0.9},  # Automate
    "C": {"risk": 0.8, "influence": 0.5},  # Contingency
    "D": {"risk": 0.3, "influence": 0.4}   # Delegate
}

matrix = generate_matrix(assessments)
# {
#     "mitigate": ["A"],
#     "automate": ["B"],
#     "contingency": ["C"],
#     "delegate": ["D"]
# }
```

## Complete Workflow Example

```python
from src.models.graph import Node, Edge, Graph
from src.models.base import OperationType
from src.services.analysis.propagation import propagate_risk
from src.services.analysis.matrix import generate_matrix

# 1. Build graph
op_type = OperationType(name="Task", category="technical", description="Work item")
nodes = [
    Node(id="A", name="Requirements", type=op_type),
    Node(id="B", name="Design", type=op_type),
    Node(id="C", name="Implementation", type=op_type)
]
edges = [
    Edge(source=nodes[0], target=nodes[1], weight=0.9, relationship="informs"),
    Edge(source=nodes[1], target=nodes[2], weight=0.8, relationship="guides")
]
graph = Graph(nodes=nodes, edges=edges)

# 2. Define assessments
assessments = {
    "A": {"local_risk": 0.3, "influence": 0.9},
    "B": {"local_risk": 0.2, "influence": 0.8},
    "C": {"local_risk": 0.1, "influence": 0.7}
}

# 3. Propagate risk
result = propagate_risk(graph, assessments, multiplier=1.2)

# 4. Classify into strategic matrix
matrix = generate_matrix(result)

# 5. Take action based on quadrants
for node_id in matrix["mitigate"]:
    print(f"Critical: {node_id} needs immediate attention")

for node_id in matrix["automate"]:
    print(f"Optimize: {node_id} is a candidate for automation")
```

## Testing

Run the comprehensive test suite:

```bash
# Unit tests for propagation logic
uv run pytest tests/test_propagation.py -v

# Integration tests
uv run pytest tests/test_propagation_integration.py -v

# Run demo
uv run python examples/risk_propagation_demo.py
```

## Mathematical Background

The risk propagation formula is based on probabilistic cascading failure analysis:

1. **Local Failure Probability**: Each node has an inherent probability of failure
2. **Critical Path Multiplier**: μ amplifies risk on critical paths (default: 1.2)
3. **Parent Dependencies**: Node succeeds only if all parents succeed
4. **Probability Chain**: Success probabilities multiply (failures are independent)
5. **Risk Conversion**: Risk = 1 - Probability of Success

This model assumes:
- Failures are independent given parent states
- Success requires all dependencies to succeed
- Risk propagates monotonically (can only increase or stay same)
- All probabilities are in [0, 1] range

## References

See MATLAB implementation for original formulation:
- `/MATLAB/Functions/riskCalculations.m` - `calculate_topological_risk()`
- `/MATLAB/Functions/topologicalSort.m` - Kahn's algorithm reference
- `/docs/IMPLEMENTATION_PLAN.md` - System architecture

## Dependencies

- `src.models.graph`: Graph, Node, Edge classes
- `src.services.math.risk`: Low-level risk calculation functions
- `collections.deque`: For topological sort queue
- `logging`: For debug and info messages
