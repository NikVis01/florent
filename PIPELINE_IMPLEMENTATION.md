# Analysis Pipeline Implementation

## Overview

Complete implementation of the Florent analysis pipeline, integrating graph construction, AI-driven evaluation, risk propagation, and strategic analysis.

## Files Created/Modified

### New Files

1. **`src/services/pipeline.py`**
   - Core analysis pipeline orchestration
   - Functions:
     - `build_infrastructure_graph(project)` - Constructs DAG from project requirements
     - `propagate_risk(graph, assessments)` - Cascades risk through dependencies
     - `detect_critical_chains(graph, risks)` - Identifies high-risk dependency paths
     - `run_analysis(firm, project, budget)` - Main entry point for complete analysis

2. **`tests/test_pipeline.py`**
   - Unit tests for pipeline components
   - Tests graph building, risk propagation, critical chain detection
   - End-to-end pipeline testing with mocked AI evaluation

3. **`scripts/test_integration.py`**
   - Integration test using real POC data
   - Validates complete workflow from JSON files to analysis output
   - Verifies all output fields and data integrity

4. **`scripts/test_e2e_analysis.py`**
   - Comprehensive end-to-end test with detailed output
   - Human-readable analysis results display
   - Useful for manual testing and demos

### Modified Files

1. **`src/main.py`**
   - Integrated `run_analysis()` into `/analyze` endpoint
   - Added entity parsing functions: `parse_firm()`, `parse_project()`
   - Replaced mock response with real pipeline execution
   - Added structured logging throughout

2. **`src/models/entities.py`**
   - Added Pydantic alias for `preferred_project_timeline` field
   - Supports both old (`prefered`) and new (`preferred`) spellings
   - Enables backward compatibility with existing data

3. **`tests/test_e2e_workflow.py`**
   - Fixed field name references to use correct model field
   - Ensured compatibility with updated entity models

4. **`pyproject.toml`**
   - Added `litestar>=2.0.0` dependency for HTTP API

## Pipeline Architecture

### Step-by-Step Flow

```
1. BUILD GRAPH
   ├─ Create entry node (site survey)
   ├─ Create nodes from project.ops_requirements
   ├─ Create exit node (operations handover)
   └─ Link nodes with weighted edges (prerequisites)

2. INITIALIZE ORCHESTRATOR
   ├─ Create AgentOrchestrator with graph
   ├─ Configure DSPy AI evaluator
   └─ Prepare heap for prioritized exploration

3. RUN EXPLORATION (Budget-Limited)
   ├─ Start from entry nodes
   ├─ Evaluate each node for influence & risk
   ├─ Prioritize high-impact nodes (influence * risk)
   ├─ Continue until budget exhausted
   └─ Return node assessments

4. PROPAGATE RISK
   ├─ Topological sort of graph
   ├─ Calculate local risk for each node
   ├─ Compound upstream risk with local risk
   └─ Generate propagated risk scores

5. GENERATE ACTION MATRIX (2×2)
   ├─ Classify each node by influence & risk
   ├─ Quadrants:
   │  ├─ Mitigate: High Risk, High Influence
   │  ├─ Contingency: High Risk, Low Influence
   │  ├─ Automate: Low Risk, High Influence
   │  └─ Delegate: Low Risk, Low Influence
   └─ Return node classifications

6. DETECT CRITICAL CHAINS
   ├─ Find all entry-to-exit paths
   ├─ Calculate aggregate risk per path
   ├─ Flag chains above threshold (default: 0.6)
   └─ Return critical dependency chains

7. GENERATE SUMMARY & RECOMMENDATIONS
   ├─ Calculate overall bankability (1 - avg_risk)
   ├─ Generate strategic recommendations
   ├─ Compile metrics and insights
   └─ Return complete analysis output
```

## API Integration

### Endpoint: `POST /analyze`

**Request Format:**

```json
{
  "firm_path": "/path/to/firm.json",
  "project_path": "/path/to/project.json",
  "budget": 100
}
```

Or with inline data:

```json
{
  "firm_data": { ... },
  "project_data": { ... },
  "budget": 50
}
```

**Response Format:**

```json
{
  "status": "success",
  "message": "Analysis complete for [Project Name]",
  "analysis": {
    "node_assessments": {
      "node_id": {
        "influence": 0.75,
        "risk": 0.60,
        "reasoning": "..."
      }
    },
    "action_matrix": {
      "mitigate": ["node_1", "node_5"],
      "automate": ["node_2"],
      "contingency": ["node_7"],
      "delegate": ["node_3", "node_4"]
    },
    "critical_chains": [
      {
        "chain_id": "chain_entry_to_exit",
        "nodes": ["entry", "node_1", "exit"],
        "aggregate_risk": 0.65,
        "impact_description": "Critical path..."
      }
    ],
    "summary": {
      "firm_id": "firm_001",
      "project_id": "proj_001",
      "nodes_analyzed": 4,
      "budget_used": 4,
      "overall_bankability": 0.389,
      "average_risk": 0.611,
      "maximum_risk": 0.664,
      "critical_chains_detected": 1,
      "high_risk_nodes": 2,
      "recommendations": [
        "Project has significant risk - consider restructuring",
        "Monitor 1 critical dependency chain closely",
        "..."
      ]
    }
  }
}
```

## Risk Propagation Algorithm

The pipeline uses a custom risk propagation algorithm:

```python
# For each node in topological order:
if node.is_entry():
    propagated_risk[node] = local_risk
else:
    max_parent_risk = max(propagated_risk[parent] for parent in parents)
    # Amplifies when both local and upstream are high
    propagated_risk[node] = min(1.0,
        local_risk + (max_parent_risk * local_risk * 0.5)
    )
```

This ensures:
- Entry nodes start with only local risk
- Downstream nodes compound parent risks
- Risk amplifies when both upstream and local risks are high
- Values stay bounded between 0 and 1

## Testing

### Run All Tests

```bash
# Unit tests for pipeline components
uv run pytest tests/test_pipeline.py -v

# Integration tests with POC data
uv run pytest tests/test_e2e_workflow.py -v

# All tests together
make test
```

### Run Integration Test

```bash
# Simplified integration test
uv run python scripts/test_integration.py

# Detailed E2E test with formatted output
uv run python scripts/test_e2e_analysis.py
```

### Expected Output

With the POC data (Nexus Global Infrastructure + Amazonas Smart Grid):

- **Nodes Analyzed:** 4 (entry, 2 ops, exit)
- **Overall Bankability:** ~38.9% (moderate-to-high risk)
- **Critical Chains:** 1 detected (full project path)
- **Action Matrix:** Most nodes in "delegate" quadrant (due to default fallback scores)
- **Recommendations:** Focus on restructuring due to risk levels

## Configuration

### AI Evaluation

The pipeline uses DSPy for AI-driven node evaluation. Configure with:

```python
import dspy

dspy.configure(lm=dspy.LM('openai/gpt-4o-mini'))
```

**Note:** Without an API key, the orchestrator falls back to default scores (0.5, 0.5), which still allows the pipeline to function for testing.

### Logging

Structured JSON logging is automatically configured via `src/services/logging/logger.py`:

```python
from src.services.logging.logger import get_logger

logger = get_logger(__name__)
logger.info("event_name", key1=value1, key2=value2)
```

**Environment Variables:**
- `LOG_LEVEL`: DEBUG, INFO, WARNING, ERROR (default: INFO)
- `LOG_JSON`: true/false (default: true)
- `ENVIRONMENT`: production/development (default: development)

## Graph Construction

The pipeline automatically builds infrastructure graphs from project data:

1. **Entry Node:** Site survey/assessment (uses first op category)
2. **Intermediate Nodes:** One per `ops_requirement`
3. **Exit Node:** Operations handover (uses last op category)
4. **Edges:** Linear dependencies with decreasing weights

**Future Enhancement:** Support complex DAGs with branching, parallel paths, and custom topologies from project specifications.

## Strategic Recommendations

The pipeline generates context-aware recommendations based on:

- **Bankability Score:**
  - ≥ 0.8: "Strong bankability - proceed with confidence"
  - 0.6-0.8: "Moderately bankable - implement risk controls"
  - < 0.6: "Significant risk - consider restructuring"

- **Action Matrix:**
  - Mitigate nodes: "Prioritize mitigation"
  - Contingency nodes: "Develop contingency plans"
  - Automate nodes: "Optimize and automate"

- **Critical Chains:**
  - Detected: "Monitor closely - single points of failure"
  - None: "Good risk distribution"

## Performance

- **Graph Construction:** O(n) where n = number of operations
- **Risk Propagation:** O(V + E) - single topological traversal
- **Critical Chain Detection:** O(V × E) - path enumeration
- **AI Evaluation:** Depends on budget and API latency

**Typical Execution Time:** < 5 seconds for 10-20 node graphs with budget=100

## Known Limitations

1. **Linear Graph Assumption:** Current implementation creates linear dependency chains. Complex DAGs with branching/merging require manual graph construction.

2. **AI Fallback:** Without DSPy configuration, all nodes get default scores (0.5, 0.5), reducing analysis accuracy.

3. **Budget Constraints:** Budget limits exploration depth. For complete analysis, set budget ≥ number of nodes.

4. **Field Name Compatibility:** Firm model accepts both `prefered_project_timeline` and `preferred_project_timeline` for backward compatibility.

## Next Steps

1. **Graph Builder Service:** Auto-generate complex DAGs from project specs
2. **Risk Simulation:** Monte Carlo simulations for probabilistic outcomes
3. **Tensor Operations:** Integrate C++ tensor ops for advanced analytics
4. **Real-time Updates:** WebSocket support for live risk monitoring
5. **Visualization:** Frontend dashboard for graph and matrix visualization

## Test Results

```
======================== 22 passed, 2 warnings ========================

Pipeline Tests: 6/6 ✓
E2E Workflow Tests: 16/16 ✓
Integration Test: PASSED ✓
```

All tests passing with POC data validation.
