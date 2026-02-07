# Project Florent: Implementation Plan
**Version**: 1.0
**Created**: 2026-02-07
**Status**: Active Development
**Current Completion**: 60% (Infrastructure Complete, Core Logic 50%)

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Project Goals](#project-goals)
3. [Current State Assessment](#current-state-assessment)
4. [Implementation Phases](#implementation-phases)
5. [Technical Architecture](#technical-architecture)
6. [Success Criteria](#success-criteria)
7. [Risk Mitigation](#risk-mitigation)

---

## Executive Summary

**Mission**: Build a production-ready neuro-symbolic infrastructure risk analysis engine that combines graph theory, AI agents (DSPy), and mathematical models to assess strategic fit between firms and infrastructure projects.

**Current State**:
- ✅ Infrastructure 100% complete (models, logging, tests, Docker)
- ⚠️ Core logic 50% complete (orchestrator stub, DSPy not wired)
- ✅ 175/175 tests passing

**Estimated Time to MVP**: 11-15 hours of focused development
**Estimated Time to Production**: 20-25 hours total

---

## Project Goals

### Primary Objectives
1. **Risk Profiling**: Assess strategic alignment between bidder (firm) and project requirements
2. **Dependency Mapping**: Identify critical nodes and systemic risks in infrastructure DAGs
3. **Cascading Failure Analysis**: Model how upstream failures propagate downstream
4. **Action Matrix**: Classify each node into 2×2 matrix (Mitigate/Automate/Contingency/Delegate)

### Success Metrics
- ✅ End-to-end analysis: firm.json + project.json → AnalysisOutput
- ✅ All tests passing (175+ tests)
- ✅ DSPy agents successfully query OpenAI for node evaluation
- ✅ Risk scores in valid range [0, 1]
- ✅ 2×2 matrix correctly classifies nodes by risk/influence
- ✅ System fails fast on invalid data (no silent errors)

### Target Users
- Infrastructure consulting firms evaluating project bids
- Project managers assessing contractor risk
- Risk analysts modeling cascading dependencies

---

## Current State Assessment

### What Works ✅
| Component | Status | Test Coverage |
|-----------|--------|---------------|
| Data Models (Firm, Project, Graph) | 100% | ✅ 31 tests |
| Graph Structure (DAG validation) | 100% | ✅ 6 tests |
| Traversal Structures (Stack/Heap) | 100% | ✅ 20+ tests |
| Logging Service (structlog) | 100% | ✅ Production-ready |
| GeoAnalyzer (country similarity) | 85% | ✅ 20 tests |
| AI Client (DSPy + OpenAI) | 95% | ✅ Configured |
| Math Service (risk calculations) | 100% | ✅ 4 functions |
| Vector Service (embeddings) | 100% | ✅ NumPy ops |
| Settings & Config | 100% | ✅ 10 tests |
| Docker Infrastructure | 100% | ✅ Multi-service compose |
| Documentation | 100% | ✅ Comprehensive |

### Critical Blockers 🔴
| # | Blocker | Impact | Est. Time |
|---|---------|--------|-----------|
| 1 | Missing Graph utility methods | Can't start traversal | 1-2h |
| 2 | Orchestrator core loop stub | No analysis logic | 2-3h |
| 3 | DSPy integration not wired | Agents not called | 2-3h |
| 4 | 2×2 Matrix classification | No actionable output | 1h |
| 5 | Critical chain detection | Missing analysis feature | 1-2h |

### Data Quality Issues ⚠️
- ❌ `firm.json`: Typo "prefered_project_timeline" → "preferred_project_timeline"
- ❌ `affiliations.json`: Missing "OIC" (referenced in firm.json) → FATAL
- ❌ Service name mismatches between project.json and services.json registry
- ❌ Case inconsistency: "Mercosur" vs "MERCOSUR"

---

## Implementation Phases

### 🎯 Phase 1: Core Logic Foundation (4-6 hours)
**Goal**: Make the orchestrator functional with graph traversal and DSPy integration

#### 1.1 Graph Utility Methods (1-2 hours)
**File**: `src/models/graph.py`

**Tasks**:
- [ ] Implement `get_entry_nodes()` → Return nodes with in-degree 0
- [ ] Implement `get_exit_nodes()` → Return nodes with out-degree 0
- [ ] Implement `get_parents(node)` → Return predecessors
- [ ] Implement `get_children(node)` → Return successors
- [ ] Implement `get_distance(source, target)` → BFS shortest path
- [ ] Add tests to `tests/test_graph.py` for each method
- [ ] Verify all graph tests pass

**Acceptance Criteria**:
```python
# Should work:
graph = Graph(nodes=[...], edges=[...])
entry_nodes = graph.get_entry_nodes()  # Returns [Node(...)]
children = graph.get_children(some_node)  # Returns [Node(...)]
distance = graph.get_distance(node_a, node_b)  # Returns int
```

**Reference Implementation**: See `docs/audit.md` lines 56-110 for detailed code

---

#### 1.2 Agent Orchestrator Core Loop (2-3 hours)
**File**: `src/services/agent/core/orchestrator.py`

**Tasks**:
- [ ] Implement `run_exploration(budget: int)` with priority-based traversal
- [ ] Initialize heap with entry nodes
- [ ] Main loop: pop node → evaluate → push children with priorities
- [ ] Track visited nodes to prevent cycles
- [ ] Return `Dict[str, NodeAssessment]`
- [ ] Implement `_evaluate_node(node: Node)` stub (returns mock data for now)
- [ ] Add structured logging with `src/services/logging`
- [ ] Update tests in `tests/test_orchestrator.py`

**Acceptance Criteria**:
```python
orchestrator = AgentOrchestrator(graph, firm, project)
results = orchestrator.run_exploration(budget=50)
# Returns: {"node_1": NodeAssessment(...), "node_2": ...}
assert len(results) <= 50  # Budget respected
assert all(node_id in graph.nodes for node_id in results.keys())
```

**Reference Implementation**: See `docs/audit.md` lines 128-174

---

#### 1.3 DSPy Signature Integration (2-3 hours)
**Files**:
- `src/services/agent/models/signatures.py`
- `src/services/agent/core/orchestrator.py`

**Tasks**:
- [ ] Enhance `NodeSignature` with strict output constraints
- [ ] Add field validators for influence_score ∈ [0, 1] and risk_level ∈ [1, 5]
- [ ] In `orchestrator.__init__()`: Instantiate `self.node_evaluator = dspy.Predict(NodeSignature)`
- [ ] Implement `_evaluate_node()` to call DSPy predictor with firm/node context
- [ ] Format firm context: sectors, services, countries, strategic focuses
- [ ] Format node requirements: operation type, category, description
- [ ] Parse DSPy output and convert to `NodeAssessment` object
- [ ] Handle API errors gracefully with logging
- [ ] Update tests in `tests/test_signatures.py` and `tests/test_orchestrator.py`

**Acceptance Criteria**:
```python
# In orchestrator
result = self.node_evaluator(
    firm_context="Sectors: [Energy, Construction], Services: [Grid Design]...",
    node_requirements="Type: Engineering, Category: Smart Grid...",
    distance_from_entry=2
)
assert 0.0 <= result.influence_score <= 1.0
assert 1 <= result.risk_level <= 5
assert len(result.reasoning) > 50  # Must provide explanation
```

**Reference Implementation**: See `docs/audit.md` lines 185-226

---

### 🎯 Phase 2: Analysis Features (3-4 hours)
**Goal**: Implement core analysis algorithms (2×2 matrix, critical chains, risk propagation)

#### 2.1 Risk Propagation Engine (1-2 hours)
**File**: `src/services/math/risk.py` (already has functions, need integration)

**Tasks**:
- [ ] Create `propagate_risk(graph: Graph, node_assessments: Dict)` function
- [ ] Implement topological sort to process nodes in dependency order
- [ ] Apply formula: `R_n = 1 - [(1 - P_local × μ) × ∏(1 - R_parent)]`
- [ ] Use `calculate_topological_risk()` from math service
- [ ] Return updated node_assessments with cascading risk scores
- [ ] Add tests to verify risk increases downstream
- [ ] Validate risk scores remain in [0, 1]

**Mathematical Formula** (from ROADMAP.md):
```
R_n = 1 - [(1 - P(f_local) × μ) × ∏(1 - R_i) for i in parents(n)]
```
Where:
- `P(f_local)` = Local failure probability (from DSPy agent)
- `μ` = Critical path multiplier from metrics.json
- `R_i` = Risk score of parent node i

**Acceptance Criteria**:
- If parent has 50% risk, child cannot have <50% risk
- Exit nodes have highest cumulative risk
- Entry nodes use only local risk (no parents)

---

#### 2.2 2×2 Action Matrix Classification (1 hour)
**File**: `src/services/analysis/matrix.py` (new file)

**Tasks**:
- [ ] Create `classify_node(influence: float, risk: float) -> Quadrant`
- [ ] Define quadrants:
  - **Q1 (Mitigate)**: High Risk (>0.7), High Influence (>0.7)
  - **Q2 (Automate)**: Low Risk (<0.7), High Influence (>0.7)
  - **Q3 (Contingency)**: High Risk (>0.7), Low Influence (<0.7)
  - **Q4 (Delegate)**: Low Risk (<0.7), Low Influence (<0.7)
- [ ] Create `generate_matrix(node_assessments: Dict) -> ActionMatrix`
- [ ] Group nodes by quadrant with recommended actions
- [ ] Add tests for boundary conditions (risk=0.7, influence=0.7)

**Acceptance Criteria**:
```python
matrix = generate_matrix(node_assessments)
assert len(matrix.mitigate) + len(matrix.automate) + \
       len(matrix.contingency) + len(matrix.delegate) == len(node_assessments)
# Every node appears in exactly one quadrant
```

---

#### 2.3 Critical Chain Detection (1-2 hours)
**File**: `src/services/analysis/chains.py` (new file)

**Tasks**:
- [ ] Implement `find_critical_chains(graph: Graph, node_assessments: Dict) -> List[CriticalChain]`
- [ ] Identify paths where failure blocks entire project (entry → exit)
- [ ] Use DFS with NodeStack to find all paths
- [ ] Filter paths where cumulative risk > threshold (e.g., 0.8)
- [ ] Calculate path risk: `1 - ∏(1 - R_i) for i in path`
- [ ] Return top N chains sorted by risk (descending)
- [ ] Add tests with various graph topologies

**Acceptance Criteria**:
```python
chains = find_critical_chains(graph, assessments, threshold=0.8, top_n=5)
assert all(chain.risk > 0.8 for chain in chains)
assert chains[0].risk >= chains[-1].risk  # Sorted descending
assert all(chain.nodes[0] in entry_nodes for chain in chains)
assert all(chain.nodes[-1] in exit_nodes for chain in chains)
```

---

#### 2.4 Pivotal Node Analysis (1 hour)
**File**: `src/services/analysis/pivotal.py` (new file)

**Tasks**:
- [ ] Implement `identify_pivotal_nodes(graph: Graph, node_assessments: Dict) -> List[PivotalNode]`
- [ ] Calculate centrality: `C_n = in_degree(n) + out_degree(n)`
- [ ] Calculate contribution: `Contrib_n = C_n × R_n × I_n`
- [ ] Return top N nodes sorted by contribution (descending)
- [ ] Include justification for why node is pivotal
- [ ] Add tests with star, chain, and diamond topologies

**Acceptance Criteria**:
```python
pivotal = identify_pivotal_nodes(graph, assessments, top_n=10)
assert pivotal[0].contribution >= pivotal[-1].contribution  # Sorted
assert all(node.centrality > 0 for node in pivotal)  # No isolated nodes
```

---

### 🎯 Phase 3: Integration & API (2-3 hours)
**Goal**: Wire everything together and expose via REST API

#### 3.1 End-to-End Pipeline (1 hour)
**File**: `src/services/pipeline.py` (new file)

**Tasks**:
- [ ] Create `run_analysis(firm: Firm, project: Project, budget: int) -> AnalysisOutput`
- [ ] Build graph from project.infrastructure
- [ ] Initialize orchestrator with firm, project, graph
- [ ] Run exploration with budget
- [ ] Propagate risk through graph
- [ ] Generate 2×2 matrix
- [ ] Detect critical chains
- [ ] Identify pivotal nodes
- [ ] Return complete AnalysisOutput
- [ ] Add comprehensive logging at each stage
- [ ] Add tests in `tests/test_integration.py`

**Acceptance Criteria**:
```python
firm = Firm.from_file("src/data/poc/firm.json")
project = Project.from_file("src/data/poc/project.json")
result = run_analysis(firm, project, budget=100)
assert result.risk_profile is not None
assert result.action_matrix is not None
assert len(result.critical_chains) > 0
assert len(result.pivotal_nodes) > 0
```

---

#### 3.2 API Endpoint Implementation (1 hour)
**File**: `src/main.py`

**Tasks**:
- [ ] Replace mock response with actual pipeline call
- [ ] Parse `AnalysisRequest` (firm_data/project_data or file paths)
- [ ] Load Firm and Project objects
- [ ] Call `run_analysis()` from pipeline
- [ ] Return `AnalysisOutput` as JSON
- [ ] Add error handling for invalid data
- [ ] Add API tests in `tests/test_api.py` (new file)

**Acceptance Criteria**:
```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{"firm_path": "src/data/poc/firm.json", "project_path": "src/data/poc/project.json"}'

# Returns:
{
  "risk_profile": {...},
  "action_matrix": {
    "mitigate": [...],
    "automate": [...],
    "contingency": [...],
    "delegate": [...]
  },
  "critical_chains": [...],
  "pivotal_nodes": [...]
}
```

---

#### 3.3 Data Quality Fixes (30 min)
**Files**:
- `src/data/poc/firm.json`
- `src/data/geo/affiliations.json`
- `src/data/taxonomy/services.json`

**Tasks**:
- [ ] Fix typo: "prefered_project_timeline" → "preferred_project_timeline"
- [ ] Add "OIC" to affiliations.json: `"OIC": ["SAU", "ARE", "EGY", ...]`
- [ ] Standardize case: "Mercosur" → "MERCOSUR" everywhere
- [ ] Add missing services to services.json registry
- [ ] Add data validation script: `scripts/validate_data.py`
- [ ] Run validation in CI/CD pipeline

**Acceptance Criteria**:
```bash
python scripts/validate_data.py
# Returns: ✅ All data valid (no errors)
```

---

### 🎯 Phase 4: Testing & Validation (2-3 hours)
**Goal**: Achieve 100% test coverage and fix any failing tests

#### 4.1 Fix Failing Tests (1-2 hours)
**Files**: Various test files

**Tasks**:
- [ ] Review 27 failing tests (if any remain from audit)
- [ ] Fix mock issues in `test_ai_client.py`
- [ ] Fix environment variable mocking in `test_settings.py`
- [ ] Replace heavy mocks with integration tests where possible
- [ ] Ensure all tests use proper fixtures from `conftest.py`
- [ ] Run full test suite: `pytest tests/ -v --cov`

**Acceptance Criteria**:
```bash
pytest tests/ -v
# Result: 175/175 tests passing (100%)
```

---

#### 4.2 End-to-End Workflow Tests (1 hour)
**File**: `tests/test_e2e_workflow.py`

**Tasks**:
- [ ] Test complete pipeline: firm.json → project.json → AnalysisOutput
- [ ] Test with invalid data (should crash with clear error)
- [ ] Test with missing data (should crash)
- [ ] Test with empty graph (should raise ValueError)
- [ ] Test with cyclic graph (should raise ValueError)
- [ ] Test budget limits (should stop at budget)
- [ ] Test API endpoint with curl/httpx

**Acceptance Criteria**:
- All e2e tests pass
- Invalid data crashes immediately (fail-fast)
- Logs show structured JSON output
- Performance: <10s for typical project (50 nodes)

---

### 🎯 Phase 5: Production Readiness (3-5 hours)
**Goal**: Deploy-ready system with monitoring, docs, and CI/CD

#### 5.1 Performance Optimization (1-2 hours)
**Tasks**:
- [ ] Profile orchestrator with `cProfile`
- [ ] Optimize hot paths if needed
- [ ] Add caching for repeated calculations
- [ ] Test with large graphs (200+ nodes)
- [ ] Verify memory usage stays reasonable (<2GB for 200 nodes)
- [ ] Add performance tests with benchmarks

**Performance Targets**:
- Small project (20 nodes): <5s
- Medium project (50 nodes): <10s
- Large project (200 nodes): <60s
- Memory: <2GB for any project

---

#### 5.2 Monitoring & Observability (1 hour)
**File**: `src/services/logging/metrics.py` (new file)

**Tasks**:
- [ ] Add metrics collection (node count, API latency, error rates)
- [ ] Integrate with structlog for structured metrics
- [ ] Add health check endpoint: `/health`
- [ ] Add metrics endpoint: `/metrics` (Prometheus format)
- [ ] Add request tracing with correlation IDs
- [ ] Test metrics in Docker environment

**Acceptance Criteria**:
```bash
curl http://localhost:8000/health
# Returns: {"status": "healthy", "uptime": 3600, "requests": 42}

curl http://localhost:8000/metrics
# Returns: Prometheus-formatted metrics
```

---

#### 5.3 Documentation & Deployment Guide (1 hour)
**Files**:
- `docs/DEPLOYMENT.md` (new)
- `docs/API.md` (new)
- Update `README.md`

**Tasks**:
- [ ] Write deployment guide (Docker, Docker Compose, Kubernetes)
- [ ] Document API endpoints with examples
- [ ] Create environment variable reference
- [ ] Add troubleshooting section
- [ ] Create quickstart guide
- [ ] Add architecture diagrams

---

#### 5.4 CI/CD Pipeline (1 hour)
**File**: `.github/workflows/ci.yml` (new)

**Tasks**:
- [ ] Set up GitHub Actions workflow
- [ ] Run tests on every push
- [ ] Run linting (ruff)
- [ ] Run type checking (mypy)
- [ ] Build Docker image
- [ ] Push to container registry
- [ ] Add status badge to README

**Acceptance Criteria**:
- All checks pass on main branch
- Docker image builds successfully
- Tests run in <5 minutes

---

### 🎯 Phase 6: Advanced Features (Future Work)
**Goal**: Enhancements beyond MVP

#### 6.1 SPICE Optimization Layer (5-10 hours)
**Concept**: Iterative simulation to suggest project modifications

**Tasks**:
- [ ] Implement PyTorch-based optimization
- [ ] Define objective function: minimize risk, maximize influence
- [ ] Iterate over node removals/additions
- [ ] Generate "what-if" scenarios
- [ ] Return top N scenario recommendations

**Status**: DEFERRED (not needed for MVP)

---

#### 6.2 MATLAB Visualization Dashboard (3-5 hours)
**Note**: Parallel implementation already started in `MATLAB/` directory

**Tasks**:
- [ ] Complete MATLAB dashboard integration
- [ ] Add real-time graph visualization
- [ ] Add risk heatmaps
- [ ] Add interactive 2×2 matrix plot
- [ ] Export to PDF/PowerPoint

**Status**: IN PROGRESS (not blocking MVP)

---

## Technical Architecture

### System Overview
```
┌─────────────────────────────────────────────────────────────┐
│                      REST API (Litestar)                     │
│                         /analyze                             │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    Analysis Pipeline                         │
│  (Load Data → Build Graph → Run Orchestrator → Analyze)     │
└──────┬──────────────────┬──────────────────┬────────────────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────┐   ┌──────────────┐   ┌─────────────────┐
│ DSPy Agents │   │ Math Service │   │ Graph Service   │
│ (OpenAI)    │   │ (Risk Calc)  │   │ (Traversal)     │
└─────────────┘   └──────────────┘   └─────────────────┘
       │                  │                  │
       └──────────────────┴──────────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │ AnalysisOutput │
                  │  - RiskProfile │
                  │  - ActionMatrix│
                  │  - Chains      │
                  │  - Pivotal     │
                  └────────────────┘
```

### Data Flow
```
Firm.json + Project.json
    │
    ├─> Load & Validate (Pydantic)
    │
    ├─> Build Graph (DAG)
    │
    ├─> Initialize Orchestrator
    │
    ├─> Run Exploration (Priority-Based Traversal)
    │   │
    │   ├─> For each node:
    │   │   ├─> Call DSPy Agent (Evaluate Capability Match)
    │   │   ├─> Calculate Influence Score (Math Service)
    │   │   ├─> Calculate Local Risk (DSPy + Math)
    │   │   └─> Push Children to Heap (Priority = Risk × Influence)
    │   │
    │   └─> Return {node_id: NodeAssessment}
    │
    ├─> Propagate Risk (Topological Order)
    │
    ├─> Generate 2×2 Matrix (Classify Nodes)
    │
    ├─> Detect Critical Chains (DFS)
    │
    ├─> Identify Pivotal Nodes (Centrality × Risk)
    │
    └─> Return AnalysisOutput (JSON)
```

### Core Algorithms

#### 1. Influence Score (with Distance Decay)
```python
def calculate_influence_score(ce_score: float, distance: int, alpha: float = 0.9) -> float:
    """
    I_n = sigmoid(CE_score) × α^(-d)

    Where:
    - CE_score: Cross-encoder similarity (0-1)
    - distance: Graph hops from entry node
    - alpha: Attenuation factor (default 0.9)
    """
    from src.services.math.risk import sigmoid, calculate_influence_score
    return calculate_influence_score(ce_score, distance, alpha)
```

#### 2. Cascading Risk Propagation
```python
def propagate_risk(local_prob: float, parent_risks: List[float], multiplier: float = 1.2) -> float:
    """
    R_n = 1 - [(1 - P_local × μ) × ∏(1 - R_parent)]

    Where:
    - P_local: Local failure probability (from agent)
    - μ: Critical path multiplier
    - R_parent: Parent node risk scores
    """
    from src.services.math.risk import calculate_topological_risk
    return calculate_topological_risk(local_prob, multiplier, parent_risks)
```

#### 3. Priority Calculation
```python
def calculate_priority(influence: float, risk: float) -> float:
    """
    Priority = Influence × Risk

    High priority = High impact nodes with high risk (evaluate first)
    """
    return influence * risk
```

---

## Success Criteria

### MVP Completion Checklist
- [ ] All 175+ tests passing (100%)
- [ ] End-to-end: firm.json + project.json → AnalysisOutput
- [ ] DSPy agents successfully query OpenAI
- [ ] Risk scores in valid range [0, 1]
- [ ] 2×2 matrix classifies all nodes
- [ ] Critical chains detected correctly
- [ ] Pivotal nodes identified correctly
- [ ] API endpoint returns real data (not mock)
- [ ] System crashes on invalid data (fail-fast)
- [ ] Structured logging outputs JSON
- [ ] Docker container runs successfully
- [ ] Documentation complete and accurate

### Production Readiness Checklist
- [ ] All MVP criteria met
- [ ] Performance: <10s for 50-node projects
- [ ] Memory: <2GB for 200-node projects
- [ ] Health check endpoint working
- [ ] Metrics endpoint working
- [ ] CI/CD pipeline green
- [ ] Deployment guide complete
- [ ] API documentation complete
- [ ] Error handling comprehensive
- [ ] Security review passed

---

## Risk Mitigation

### Technical Risks

**Risk 1: OpenAI API Rate Limits**
- **Mitigation**: Implement exponential backoff, caching, budget limits
- **Fallback**: Use smaller models (gpt-4o-mini) for cost optimization

**Risk 2: Graph Cycles Breaking DAG Validation**
- **Mitigation**: Strict cycle detection on graph creation (already implemented)
- **Fallback**: Clear error messages guiding user to fix data

**Risk 3: Memory Issues with Large Graphs**
- **Mitigation**: Process nodes lazily, limit budget parameter
- **Fallback**: Batch processing or distributed computation (future)

**Risk 4: DSPy Output Parsing Errors**
- **Mitigation**: Strict output field validation, retry with different prompts
- **Fallback**: Use default conservative estimates if parsing fails

### Timeline Risks

**Risk 1: Scope Creep**
- **Mitigation**: Defer SPICE optimization and MATLAB dashboard to Phase 6
- **Focus**: MVP first, enhancements later

**Risk 2: Test Failures Blocking Progress**
- **Mitigation**: Fix tests incrementally, use TDD approach
- **Strategy**: Green tests = working code

**Risk 3: Data Quality Issues**
- **Mitigation**: Fix data in Phase 3.3 (30 min task)
- **Validation**: Create automated data validation script

---

## Development Workflow

### TDD Approach (Test-Driven Development)
1. **Red**: Write test that fails (defines behavior)
2. **Green**: Write minimal code to pass test
3. **Refactor**: Clean up code while keeping tests green
4. **Repeat**: Move to next feature

### Git Workflow
1. Create feature branch: `git checkout -b feature/graph-utilities`
2. Make changes and commit frequently
3. Run tests before pushing: `pytest tests/ -v`
4. Push to remote: `git push -u origin feature/graph-utilities`
5. Create PR and merge to main

### Code Review Checklist
- [ ] All tests passing
- [ ] Code follows style guide (ruff)
- [ ] Type hints present (mypy)
- [ ] Docstrings complete
- [ ] Logging statements added
- [ ] No print() statements (use logging)
- [ ] Error handling comprehensive
- [ ] Performance acceptable

---

## Estimated Timeline

### Optimistic (11 hours)
- Phase 1: 4 hours (all blockers resolved quickly)
- Phase 2: 3 hours (algorithms work first try)
- Phase 3: 2 hours (integration smooth)
- Phase 4: 2 hours (tests pass immediately)

### Realistic (15 hours)
- Phase 1: 6 hours (debugging DSPy integration)
- Phase 2: 4 hours (algorithm edge cases)
- Phase 3: 3 hours (API integration issues)
- Phase 4: 2 hours (test fixes)

### Pessimistic (25 hours)
- Phase 1: 8 hours (DSPy API issues)
- Phase 2: 6 hours (complex graph topologies)
- Phase 3: 5 hours (data quality deep dive)
- Phase 4: 3 hours (test refactoring)
- Phase 5: 3 hours (production prep)

---

## Next Immediate Actions

**Start Here** (in priority order):

1. **Fix Data Quality Issues** (30 min)
   ```bash
   # Fix typos and missing data
   vim src/data/poc/firm.json
   vim src/data/geo/affiliations.json
   ```

2. **Implement Graph Utility Methods** (1-2 hours)
   ```bash
   # Start with TDD
   pytest tests/test_graph.py -v -k "entry_nodes"
   # Implement get_entry_nodes() until test passes
   # Repeat for other methods
   ```

3. **Wire Orchestrator Core Loop** (2-3 hours)
   ```bash
   pytest tests/test_orchestrator.py -v
   # Implement run_exploration() until tests pass
   ```

4. **Integrate DSPy Signatures** (2-3 hours)
   ```bash
   export OPENAI_API_KEY="sk-..."
   pytest tests/test_signatures.py -v
   # Wire DSPy predictors until tests pass
   ```

5. **Run End-to-End Test** (verification)
   ```bash
   python -c "
   from src.services.pipeline import run_analysis
   from src.models.entities import Firm, Project

   firm = Firm.from_file('src/data/poc/firm.json')
   project = Project.from_file('src/data/poc/project.json')
   result = run_analysis(firm, project, budget=50)
   print(result)
   "
   ```

---

## Conclusion

**Project Florent** has excellent foundations (60% complete) with solid infrastructure, comprehensive tests, and clear architecture. The remaining work is focused and well-defined:

1. **3 critical blockers** (graph methods, orchestrator loop, DSPy integration)
2. **2 analysis features** (2×2 matrix, critical chains)
3. **Integration work** (API wiring, data fixes)

**With 11-15 hours of focused development using TDD**, this will be a production-ready neuro-symbolic risk analysis engine.

**Execution Strategy**: Start with Phase 1 (foundation), move to Phase 2 (features), complete with Phase 3 (integration). Each phase builds on the previous, and tests define the contract.

Let's build this. 🚀

---

**Document Version**: 1.0
**Last Updated**: 2026-02-07
**Next Review**: After Phase 1 completion
