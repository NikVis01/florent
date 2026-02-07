# Florent System Audit - Implementation Status & Next Steps

## Executive Summary

**Current State**: Core infrastructure is solid. Mathematical foundations are correct. Data structures are ready. **The blocker is the orchestration layer** - we have all the pieces but they're not connected.

**What Works**:
- ✅ Graph validation (DAG enforcement, cycle detection)
- ✅ Mathematical formulas (risk propagation, influence scoring)
- ✅ Data models (Pydantic schemas with validation)
- ✅ Vector operations (comprehensive, production-ready)
- ✅ Logging infrastructure
- ✅ Error handling patterns
- ✅ DSPy client initialization
- ✅ Traversal data structures (NodeStack, NodeHeap)

**What's Missing**:
- ❌ Agent orchestrator implementation (stub only)
- ❌ Graph utility methods (get_entry_points, get_parents)
- ❌ DSPy signature integration (defined but never called)
- ❌ Risk propagation loop (math exists, not applied)
- ❌ 2x2 matrix classification
- ❌ Critical chain detection
- ❌ End-to-end pipeline

---

## Architectural Decisions (Finalized)

### 1. Influence Formula: Distance-Based Decay Model
**Choice**: Use `risk.py` implementation
```python
I_n = sigmoid(CE_score) × α^(-d)
```

**Rationale**: Infrastructure influence decays with contractual distance. Being an expert 4 nodes away from execution means zero influence. Cross-encoder affinity (`CE_score`) captures local match quality, then topological distance (`d`) applies decay.

**Implementation**: Already in `src/services/math/risk.py:8-17`

---

### 2. Acceleration: Pure Python + NumPy
**Choice**: Defer C++ optimization

**Rationale**: Bottleneck is LLM latency, not tensor ops. NumPy is fast enough for MVP. C++ can wait for scale.

**Action**: Ignore `tensor_ops_cpp.py` and `tensor_ops.cpp` for now.

---

### 3. Cross-Encoder: DSPy Simulation
**Choice**: Use OpenAI embeddings + DSPy reasoning instead of BGE-M3 container

**Rationale**: Simpler infrastructure. DSPy `EvaluatorSignature` can produce relational scores without dedicated cross-encoder service.

**Implementation Path**:
```python
# Instead of: ce_score = bge_client.score_pair(firm_text, node_text)
# Use: ce_score = evaluator(firm_context, node_requirements).influence_score
```

---

### 4. Data Quality: Fail Fast on Invalid Data
**Choice**: **Crash on data inconsistencies** - no silent failures

**Rationale**: Bad data → bad analysis. Better to fail immediately than produce unreliable risk assessments.

**Known Issues** (must fix before use):
- Missing "OIC" in affiliations.json → **Fatal error if referenced**
- Service name mismatches → **Fatal error if not in registry**
- Typo: "prefered_project_timeline" → **Fix in data file**

**Action**: Strict validation in `base.py` - raise exceptions, no warnings.

---

### 5. Entry/Exit Points: Project-Specified Only
**Choice**: Use `project.json` entry_node_id/exit_node_id **exclusively**

**Implementation**:
```python
def get_entry_nodes(self) -> List[Node]:
    """Returns nodes specified by project entry criteria. Raises if not found."""
    if not hasattr(self, 'entry_node_id'):
        raise ValueError("Graph must have explicit entry_node_id from project")

    entry_node = next((n for n in self.nodes if n.id == self.entry_node_id), None)
    if not entry_node:
        raise ValueError(f"Entry node {self.entry_node_id} not found in graph")

    return [entry_node]
```

**Rationale**: Infrastructure projects have explicit contract entry points. No guessing from topology.

---

### 6. Agent Implementation: Hybrid Neuro-Symbolic
**Choice**: DSPy for node evaluation → Manual math for risk propagation

**Pipeline**:
```
1. DSPy Evaluator → Local Risk Assessment (Neuro)
2. Manual traversal → Risk propagation via formulas (Symbolic)
3. Classification → 2x2 Matrix assignment (Deterministic)
4. Analysis → Critical chains, pivotal nodes (Graph algorithms)
```

**Rationale**: Gets reasoning/audit trail from LLM, keeps math deterministic and fast.

---

### 7. Output Format: NumPy Arrays
**Choice**: Replace PyTorch tensors with NumPy

**Rationale**: No neural network training needed. NumPy is lighter, CPU-native, and MATLAB-compatible.

**Action**: Modify `AnalysisOutput` model to use `np.ndarray` or serialize to lists.

---

## Implementation Blockers (Priority Order)

### 🔴 BLOCKER 1: Graph Utility Methods
**File**: `src/models/graph.py`
**Status**: Missing critical methods

**Required Methods**:
```python
def get_entry_nodes(self) -> List[Node]:
    """Nodes with in-degree 0."""

def get_exit_nodes(self) -> List[Node]:
    """Nodes with out-degree 0."""

def get_parents(self, node: Node) -> List[Node]:
    """All nodes with edges pointing to this node."""

def get_children(self, node: Node) -> List[Node]:
    """All nodes this node points to."""

def get_distance(self, source: Node, target: Node) -> int:
    """Shortest path length between nodes."""
```

**Impact**: Orchestrator cannot traverse without these.

---

### 🔴 BLOCKER 2: Agent Orchestrator Core Loop
**File**: `src/services/agent/core/orchestrator.py`
**Status**: Stub implementation (lines 19-43)

**What's Missing**:
```python
def run_exploration(self, budget: int):
    # CURRENT: Only prints, commented-out logic

    # NEEDED:
    # 1. Push entry nodes to heap with priority=1.0
    # 2. While heap not empty and budget > 0:
    #    a. Pop highest priority node
    #    b. Use DSPy NodeSignature to evaluate
    #    c. Calculate influence score with distance decay
    #    d. Calculate local risk
    #    e. Push children to heap with updated priorities
    #    f. Decrement budget
    # 3. Return node_assessments dict
```

**Dependencies**: Needs DSPy signature instantiation and graph methods.

---

### 🔴 BLOCKER 3: DSPy Signature Integration
**File**: `src/services/agent/models/signatures.py`
**Status**: Bare class definitions

**Enhancement Needed**:
```python
class NodeSignature(dspy.Signature):
    """Evaluates firm capability against node requirements."""

    # INPUT
    firm_context: str = dspy.InputField(
        desc="Firm's capabilities, sectors, and strategic focuses as structured text"
    )
    node_requirements: str = dspy.InputField(
        desc="Node's operation type, category, and description"
    )
    distance_from_entry: int = dspy.InputField(
        desc="Graph distance from firm's entry point (topological hops)"
    )

    # OUTPUT
    influence_score: float = dspy.OutputField(
        desc="Cross-encoder affinity score between 0.0 and 1.0. "
             "1.0 = perfect capability match, 0.0 = no capability overlap."
    )
    risk_level: int = dspy.OutputField(
        desc="Risk assessment on scale 1-5. "
             "1 = trivial risk, 5 = critical failure likely."
    )
    reasoning: str = dspy.OutputField(
        desc="Step-by-step explanation of the assessment"
    )
```

**Action**: Instantiate with `dspy.Predict(NodeSignature)` in orchestrator.

---

### 🟡 BLOCKER 4: Risk Propagation Loop
**File**: `src/services/agent/core/orchestrator.py`
**Status**: Not implemented

**Logic Needed**:
```python
def evaluate_blast_radius(self, flagged_node: Node):
    """DFS from flagged node to recompute upstream risks."""

    self.stack.push(flagged_node)
    risk_map = {}

    while not self.stack.is_empty():
        node = self.stack.pop()

        # Get parent nodes
        parents = self.graph.get_parents(node)

        # Calculate cascading risk using formula
        # Parents MUST already be evaluated - enforce topological order
        parent_success_probs = [
            1.0 - risk_map[p.id]  # KeyError if parent not yet computed = bug
            for p in parents
        ]

        local_risk = node_assessments[node.id].risk_level / 5.0  # Normalize to [0,1]
        multiplier = get_critical_path_multiplier(node)

        success_prob = calculate_topological_risk(
            local_failure_prob=local_risk,
            multiplier=multiplier,
            parent_success_probs=parent_success_probs
        )

        risk_map[node.id] = 1.0 - success_prob

        # Push parents to stack for upstream propagation
        for parent in parents:
            if parent.id not in visited:
                self.stack.push(parent)

    return risk_map
```

---

### 🟡 BLOCKER 5: 2x2 Matrix Classification
**File**: Create `src/services/analysis/matrix_classifier.py`
**Status**: Not started

**Implementation**:
```python
from enum import Enum

class RiskQuadrant(Enum):
    Q1_KNOWN_KNOWNS = "High Risk, High Influence - Direct oversight required"
    Q2_NO_BIGGIE = "Low Risk, High Influence - Automate with SOPs"
    Q3_COOKED_ZONE = "High Risk, Low Influence - Contingency/Insurance"
    Q4_BASIC = "Low Risk, Low Influence - Delegate/Monitor minimally"

def classify_node(risk_score: float, influence_score: float) -> RiskQuadrant:
    """
    Classify node into action quadrant.

    Thresholds:
    - Risk: 0.5 (P(failure) > 50%)
    - Influence: 0.5 (I_n > 0.5 after distance decay)
    """
    RISK_THRESHOLD = 0.5
    INFLUENCE_THRESHOLD = 0.5

    high_risk = risk_score > RISK_THRESHOLD
    high_influence = influence_score > INFLUENCE_THRESHOLD

    if high_risk and high_influence:
        return RiskQuadrant.Q1_KNOWN_KNOWNS
    elif not high_risk and high_influence:
        return RiskQuadrant.Q2_NO_BIGGIE
    elif high_risk and not high_influence:
        return RiskQuadrant.Q3_COOKED_ZONE
    else:
        return RiskQuadrant.Q4_BASIC
```

---

### 🟢 BLOCKER 6: Critical Chain Detection
**File**: Create `src/services/analysis/critical_path.py`
**Status**: Not started (but lower priority)

**Algorithm**: Find all paths from entry to exit where failure blocks success.

**Defer this**: Get orchestrator working first, then add critical path analysis.

---

## Data Inconsistencies (Must Fix Before Use)

### Geographic Data
- ✅ `countries.json`: 195 countries, well-formed
- ⚠️ `affiliations.json`: Missing "OIC" (referenced in firm.json)
- ⚠️ Case mismatch: "Mercosur" vs "MERCOSUR"

### Taxonomy Data
- ✅ `sectors.json`, `strategic_focus.json`: Complete
- ✅ `categories.json`: 16 service types
- ⚠️ `services.json`: POC references undefined services ("Grid Integrity Verification")

### POC Data
- ⚠️ Typo: "prefered_project_timeline" → "preferred_project_timeline"
- ⚠️ Service name mismatch: "Public-Private Partnership Management" not in services.json

**Action**: Fix data files immediately. System must crash on invalid references - no tolerance for bad data.

---

## Mathematical Formula Consolidation

### Canonical Formulas (Finalized)

**1. Influence Score (Distance-Decay Model)**
```python
# File: src/services/math/risk.py:8-17
I_n = sigmoid(CE_score) × α^(-d)

Where:
- CE_score: Cross-encoder affinity (from DSPy evaluator)
- α: Attenuation factor (1.2 from metrics.json)
- d: Graph distance from entry point
```

**2. Cascading Risk (Product of Success)**
```python
# File: src/services/math/risk.py:19-35
P(Success_n) = (1 - min(P(failure_local) × μ, 1.0)) × ∏[P(Success_i) for i in parents]

Where:
- P(failure_local): Node's inherent failure probability
- μ: Critical path multiplier (1.25 from metrics.json)
- Parents: All upstream dependencies
```

**3. Weighted Alignment**
```python
# File: src/services/math/risk.py:37-46
Score = Σ(metric_i × weight_i)

Weights from metrics.json:
- growth: 0.25
- innovation: 0.20
- sustainability: 0.20
- efficiency: 0.15
- expansion: 0.10
- public_private_partnership: 0.10
```

---

## Implementation Plan

### Phase 1: Foundation (Core Blockers)
```
1. Add graph utility methods to graph.py
   - get_entry_nodes(), get_exit_nodes()
   - get_parents(), get_children()
   - get_distance() using BFS

2. Enhance DSPy signatures with proper field descriptions
   - Add constraints (score ranges, risk levels)
   - Add reasoning/instruction fields

3. Implement orchestrator.run_exploration()
   - Initialize heap with entry nodes
   - DSPy evaluation loop
   - Budget management
   - Priority updates

4. Implement orchestrator.evaluate_blast_radius()
   - Stack-based parent traversal
   - Risk propagation using formulas
   - Risk map accumulation
```

### Phase 2: Analysis Layer
```
5. Create matrix_classifier.py
   - RiskQuadrant enum
   - classify_node() function
   - Threshold configuration

6. Build end-to-end pipeline
   - Firm/Project → Graph construction
   - Orchestrator execution
   - AnalysisOutput generation

7. Add critical chain detection (optional)
   - All-paths search algorithm
   - Criticality scoring
```

### Phase 3: Integration & Output
```
8. Create API endpoint handler
   - JSON ingestion with strict validation
   - Pipeline orchestration
   - Result serialization

9. Update AnalysisOutput model
   - Replace PyTorch tensors with NumPy
   - Add CriticalChain and PivotalNode objects

10. Fix data issues or fail
    - Add missing "OIC" to affiliations.json
    - Fix service name mismatches
    - Correct typo in firm.json
    - **No tolerance for bad data**
```

---

## Testing Strategy

### Unit Tests (Required)
- `test_graph_methods.py`: Entry/exit nodes, parent/child discovery, distance calculation
- `test_orchestrator.py`: Heap/stack operations, budget tracking
- `test_risk_formulas.py`: Edge cases for influence and propagation formulas
- `test_matrix_classifier.py`: Boundary conditions for quadrant assignment

### Integration Tests
- `test_end_to_end_pipeline.py`: firm.json + project.json → AnalysisOutput
- `test_dspy_integration.py`: Signature instantiation and inference

### Data Validation Tests
- `test_data_integrity.py`: Cross-reference countries, services, affiliations

---

## Known Technical Debt

### High Priority
- Redundant cosine_similarity in `tensor_ops.py` and `vector_ops.py` (use vector_ops everywhere)
- Empty forward() in legacy `main.py` (delete or implement)
- C++ bindings without compiled library (remove or defer)

### Medium Priority
- Inconsistent logging for zero vectors (standardize across modules)
- No centrality calculation (currently using abstract parameter)
- Service references by name instead of ID (add referential integrity)

### Low Priority
- Typo in firm.json ("prefered")
- Unused categories in categories.json
- Case sensitivity in affiliation names

---

## Success Criteria

**MVP is complete when**:
1. ✅ `firm.json` + `project.json` → `AnalysisOutput` end-to-end
2. ✅ DSPy signatures successfully query OpenAI and return structured assessments
3. ✅ Risk propagation produces valid probability distributions [0,1]
4. ✅ 2x2 matrix correctly classifies nodes into quadrants
5. ✅ All unit tests pass
6. ✅ System validates all data strictly (crashes on invalid input)

**What success looks like**:
```python
from src.pipeline import analyze_risk

result = analyze_risk("data/poc/firm.json", "data/poc/project.json")

assert 0 <= result.overall_bankability <= 1
assert len(result.critical_chains) > 0
assert all(0 <= score <= 1 for score in result.scenario_spread)
```

---

## Next Immediate Actions

**Start here** (in order):

1. Implement `Graph.get_entry_nodes()` and `Graph.get_parents()`
2. Enhance `NodeSignature` with proper field descriptions
3. Implement `orchestrator.run_exploration()` core loop
4. Create simple test with mock graph (3 nodes, 2 edges)
5. Verify DSPy can evaluate a single node and return structured output

**Don't start yet**:
- Critical path detection
- C++ optimization
- Data corrections
- BGE-M3 integration
- PyTorch anything

---

**Audit Date**: 2026-02-07
**Status**: Ready for implementation
**Blockers**: 6 items (2 critical, 2 high, 2 medium)
**Estimated Completion**: All blockers can be resolved in a focused implementation session.
