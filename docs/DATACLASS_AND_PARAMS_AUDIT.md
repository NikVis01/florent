# Dataclass Utilization & Parameter Audit

**Generated:** 2026-02-08
**Scope:** Agent + Cross-Encoder Flow Analysis

---

## Executive Summary

This audit identifies:
1. **Dataclass/Struct Under-Utilization**: Where we're using primitives instead of structured types
2. **Hardcoded Parameters**: Magic numbers and thresholds scattered across the codebase
3. **Tunable Parameters**: Configuration options that should be externalized to `.env`

---

## Part 1: Dataclass/Struct Under-Utilization

### 🔴 CRITICAL: Cross-Encoder Client (cross_encoder_client.py)

**Current State:**
- Returns raw `List[float]` for scores
- Returns `List[Tuple[Node, float]]` for batch scoring
- No structured output for reranking results

**Recommended Dataclasses:**
```python
@dataclass
class CrossEncoderScore:
    """Structured cross-encoder scoring result."""
    query_text: str
    passage_text: str
    similarity_score: float  # 0-1 range
    raw_cosine: float  # -1 to 1 before normalization
    timestamp: datetime

@dataclass
class FirmNodeScore:
    """Firm-to-node compatibility score."""
    firm: Firm
    node: Node
    cross_encoder_score: float
    firm_embedding: List[float]
    node_embedding: List[float]
    metadata: Dict[str, Any]  # For debugging/auditing

@dataclass
class BatchScoringResult:
    """Batch scoring result with full context."""
    firm: Firm
    nodes: List[Node]
    scores: List[FirmNodeScore]
    total_time_ms: float
    endpoint: str
```

**Impact:** HIGH - Improves type safety, debugging, and caching capabilities

---

### 🔴 CRITICAL: Graph Builder (graph_builder.py)

**Current State:**
- Gaps represented as simple `List[Edge]` with threshold checks
- Discovery context passed as raw strings
- No structured representation of gap analysis

**Recommended Dataclasses:**
```python
@dataclass
class CapabilityGap:
    """Structured representation of a capability gap."""
    source_node: Node
    target_node: Node
    edge: Edge
    gap_size: float  # How far below threshold
    gap_severity: GapSeverity  # Enum: LOW, MEDIUM, HIGH, CRITICAL
    firm_similarity: float
    discovery_priority: int

@dataclass
class GapAnalysisResult:
    """Result of gap detection iteration."""
    iteration: int
    gaps_found: List[CapabilityGap]
    threshold: float
    graph_snapshot: Graph  # For rollback if needed

@dataclass
class NodeDiscoveryContext:
    """Context for agent-driven node discovery."""
    source_node: Node
    target_node: Node
    gap: CapabilityGap
    firm_context: str
    existing_graph_summary: str
    valid_categories: List[str]
    persona: str

@dataclass
class DiscoveredNode:
    """Result from agent discovery."""
    node: Node
    source_gap: CapabilityGap
    discovery_reasoning: str
    confidence: float
    persona: str
    iteration: int
```

**Impact:** HIGH - Better tracking of discovery provenance and gap resolution

---

### 🟡 MEDIUM: Orchestrator V2 (orchestrator_v2.py)

**Current State:**
- Cache keys are raw strings (line 74-77)
- Token counting is a simple int accumulator
- Discovery personas are hardcoded list of strings (line 200-204)
- Critical path markers stored as `Dict[str, bool]` (line 71)

**Recommended Dataclasses:**
```python
@dataclass
class CacheKey:
    """Structured cache key with metadata."""
    firm_id: str
    project_id: str
    node_id: str
    node_name: str
    node_type: str
    hash: str

    @classmethod
    def from_node(cls, node: Node, firm_id: str, project_id: str) -> "CacheKey":
        key_str = f"{firm_id}:{project_id}:{node.id}:{node.name}:{node.type.name}"
        return cls(
            firm_id=firm_id,
            project_id=project_id,
            node_id=node.id,
            node_name=node.name,
            node_type=node.type.name,
            hash=hashlib.sha256(key_str.encode()).hexdigest()
        )

@dataclass
class TokenUsageTracker:
    """Track token usage by operation type."""
    node_evaluation: int = 0
    discovery: int = 0
    cache_hits: int = 0
    cache_misses: int = 0
    total_cost_usd: float = 0.0

    def add_node_eval(self, tokens: int):
        self.node_evaluation += tokens

    def add_discovery(self, tokens: int):
        self.discovery += tokens

    def calculate_cost(self, model: str):
        # Price per 1k tokens
        rates = {"gpt-4o-mini": 0.00015, "gpt-4": 0.03}
        self.total_cost_usd = (self.node_evaluation + self.discovery) / 1000 * rates.get(model, 0.0)

@dataclass
class DiscoveryPersona:
    """Structured persona configuration for discovery."""
    name: str
    description: str
    expertise_areas: List[str]
    bias_towards: List[str]  # e.g., ["technical", "financial"]
    discovery_weight: float  # How much to trust this persona's discoveries

@dataclass
class CriticalPathMarker:
    """Enhanced critical path tracking."""
    node_id: str
    is_critical: bool
    chain_ids: List[str]  # Which chains include this node
    criticality_score: float  # 0-1, how critical
    rank: int  # Position in critical chain
```

**Impact:** MEDIUM - Improves observability and debugging

---

### 🟡 MEDIUM: Pipeline (pipeline.py)

**Current State:**
- Returns unstructured dicts with mixed types (line 405-411)
- Matrix input constructed as nested dicts (line 336-343)
- Recommendations are raw list of strings

**Recommended Dataclasses:**
```python
@dataclass
class PipelineExecutionTrace:
    """Full trace of pipeline execution."""
    firm_id: str
    project_id: str
    start_time: datetime
    end_time: datetime
    steps_completed: List[str]
    steps_failed: List[str]
    budget_allocated: int
    budget_used: int

@dataclass
class MatrixInput:
    """Structured input for matrix generation."""
    node_id: str
    node_name: str
    influence_score: float
    risk_level: float
    assessment: NodeAssessment

@dataclass
class Recommendation:
    """Structured recommendation."""
    category: RecommendationCategory  # Enum: RISK_MITIGATION, OPPORTUNITY, etc.
    priority: Priority  # Enum: HIGH, MEDIUM, LOW
    message: str
    affected_nodes: List[str]
    estimated_impact: float
```

**Impact:** MEDIUM - Cleaner pipeline API, easier testing

---

### 🟢 LOW: Matrix Classifier (matrix_classifier.py)

**Current State:**
- Already has good dataclass usage with `NodeClassification`
- `RiskQuadrant` is a proper enum

**Recommendation:**
```python
@dataclass
class MatrixThresholds:
    """Configurable thresholds for matrix classification."""
    influence_threshold: float = 0.6
    importance_threshold: float = 0.6
    high_risk_boundary: float = 0.7

    def validate(self):
        assert 0.0 <= self.influence_threshold <= 1.0
        assert 0.0 <= self.importance_threshold <= 1.0
```

**Impact:** LOW - Already well-structured, just needs threshold configuration

---

## Part 2: Hardcoded Parameters Inventory

### Cross-Encoder Client (cross_encoder_client.py)

| Line | Parameter | Value | Tunable? | Suggested Config |
|------|-----------|-------|----------|------------------|
| 18 | Default endpoint | `"http://localhost:8080"` | ✅ | `CROSS_ENCODER_ENDPOINT` (already in .env) |
| 25 | Health check timeout | `2` seconds | ✅ | `CROSS_ENCODER_HEALTH_TIMEOUT` |
| 76, 87 | Request timeout | `10` seconds | ✅ | `CROSS_ENCODER_REQUEST_TIMEOUT` |
| 98 | Cosine normalization | `(similarity + 1.0) / 2.0` | ❌ | Fixed formula |
| 106 | Fallback score | `0.5` | ✅ | `CROSS_ENCODER_FALLBACK_SCORE` |

---

### Orchestrator V2 (orchestrator_v2.py)

| Line | Parameter | Value | Tunable? | Suggested Config |
|------|-----------|-------|----------|------------------|
| 36 | Cache directory | `~/.cache/florent/dspy_cache` | ✅ | `DSPY_CACHE_DIR` |
| 55 | Default max retries | `3` | ✅ | `AGENT_MAX_RETRIES` |
| 56 | Default cache enabled | `True` | ✅ | `AGENT_CACHE_ENABLED` |
| 69 | Discovery limit | `250` (from settings) | ✅ | `GRAPH_MAX_DISCOVERED_NODES` (already in .env) |
| 134 | Default importance score | `0.5` | ✅ | `AGENT_DEFAULT_IMPORTANCE` |
| 135 | Default influence score | `0.5` | ✅ | `AGENT_DEFAULT_INFLUENCE` |
| 139 | Risk formula | `importance * (1.0 - influence)` | ❌ | Core algorithm |
| 142 | Token count estimate | `300` per node eval | ✅ | `AGENT_TOKENS_PER_EVAL` |
| 165 | Exponential backoff base | `2 ** attempt` | ✅ | `AGENT_BACKOFF_BASE` |
| 200-204 | Discovery personas | Hardcoded list | ✅ | `DISCOVERY_PERSONAS` (JSON config) |
| 286 | Discovered edge weight | `0.8` | ✅ | `GRAPH_DISCOVERED_EDGE_WEIGHT` |
| 291 | Infrastructure sustainment weight | `0.5` | ✅ | `GRAPH_INFRASTRUCTURE_WEIGHT` |
| 296 | Token count per discovery | `500` | ✅ | `AGENT_TOKENS_PER_DISCOVERY` |
| 372-380 | Default node assessment | Multiple defaults | ✅ | `AGENT_DEFAULT_NODE_*` |
| 405-407 | Matrix thresholds | `0.6` for both | ✅ | `MATRIX_INFLUENCE_THRESHOLD`, `MATRIX_IMPORTANCE_THRESHOLD` (already in code, should be in .env) |
| 417 | High confidence threshold | `0.9` | ✅ | `RECOMMENDATION_HIGH_CONFIDENCE` |
| 417 | Low confidence threshold | `0.6` | ✅ | `RECOMMENDATION_LOW_CONFIDENCE` |
| 426 | Critical failure default | `0.5` | ✅ | `METRICS_DEFAULT_FAILURE_LIKELIHOOD` |

---

### Matrix Classifier (matrix_classifier.py)

| Line | Parameter | Value | Tunable? | Suggested Config |
|------|-----------|-------|----------|------------------|
| 32 | Default influence threshold | `0.6` | ✅ | `MATRIX_INFLUENCE_THRESHOLD` |
| 32 | Default importance threshold | `0.6` | ✅ | `MATRIX_IMPORTANCE_THRESHOLD` |
| 125 | Critical dependency ratio | `0.5` (50%) | ✅ | `BID_CRITICAL_DEP_MAX_RATIO` |

---

### Analysis Matrix (analysis/matrix.py)

| Line | Parameter | Value | Tunable? | Suggested Config |
|------|-----------|-------|----------|------------------|
| 22 | High risk threshold | `0.7` | ✅ | `MATRIX_HIGH_RISK_THRESHOLD` |
| 23 | High influence threshold | `0.7` | ✅ | `MATRIX_HIGH_INFLUENCE_THRESHOLD` |

**⚠️ NOTE:** This file seems to be a duplicate/legacy implementation. Consider consolidating with `matrix_classifier.py`

---

### Graph Builder (graph_builder.py)

| Line | Parameter | Value | Tunable? | Suggested Config |
|------|-----------|-------|----------|------------------|
| 29 | Gap threshold | from settings (0.3) | ✅ | `GRAPH_GAP_THRESHOLD` (already in .env) |
| 30 | Max iterations | from settings (10) | ✅ | `GRAPH_MAX_ITERATIONS` (already in .env) |
| 31 | Max discovered nodes | from settings (50) | ✅ | `GRAPH_MAX_DISCOVERED_NODES` (already in .env) |
| 101 | Default edge weight | `0.8` | ✅ | `GRAPH_DEFAULT_EDGE_WEIGHT` |
| 114 | Decay factor | `0.9` | ✅ | `GRAPH_DISTANCE_DECAY_FACTOR` |
| 185 | Max nodes per gap | `3` | ✅ | `GRAPH_MAX_NODES_PER_GAP` |
| 263 | Discovered node min weight | `0.4` | ✅ | `GRAPH_DISCOVERED_MIN_WEIGHT` |
| 264 | Discovered node default weight | `0.6` | ✅ | `GRAPH_DISCOVERED_DEFAULT_WEIGHT` |
| 271 | Bridge gap final weight | `0.7` | ✅ | `GRAPH_BRIDGE_GAP_WEIGHT` |
| 274 | Bridge gap min weight | `0.5` | ✅ | `GRAPH_BRIDGE_GAP_MIN_WEIGHT` |
| 327 | Max gaps per iteration | `5` | ✅ | `GRAPH_MAX_GAPS_PER_ITERATION` |

---

### Pipeline (pipeline.py)

| Line | Parameter | Value | Tunable? | Suggested Config |
|------|-----------|-------|----------|------------------|
| 68-69 | Entry node default embedding | `[0.1, 0.2, 0.3]` | ❌ | Auto-generated |
| 78 | Intermediate embeddings | `[0.2+i*0.1, ...]` | ❌ | Auto-generated |
| 94 | Exit node default embedding | `[0.8, 0.9, 1.0]` | ❌ | Auto-generated |
| 105 | Min edge weight | `0.6` | ✅ | `PIPELINE_MIN_EDGE_WEIGHT` |
| 101 | Weight decay per edge | `0.05` | ✅ | `PIPELINE_EDGE_WEIGHT_DECAY` |
| 100 | Initial edge weight | `0.9` | ✅ | `PIPELINE_INITIAL_EDGE_WEIGHT` |
| 182 | Risk propagation multiplier | `0.5` | ✅ | `PIPELINE_RISK_PROPAGATION_FACTOR` |
| 195 | Critical chain threshold | `0.1` | ✅ | `PIPELINE_CRITICAL_CHAIN_THRESHOLD` |
| 275 | Default budget | `100` | ✅ | `PIPELINE_DEFAULT_BUDGET` |
| 392 | Bid threshold (bankability) | `0.7` | ✅ | `BID_MIN_BANKABILITY_THRESHOLD` |
| 432-437 | Bankability thresholds | `0.8`, `0.6` | ✅ | `RECOMMENDATION_BANKABILITY_HIGH`, `RECOMMENDATION_BANKABILITY_MEDIUM` |

---

### Settings (settings.py)

**✅ Already Configured:**
- `OPENAI_API_KEY`
- `LLM_MODEL`
- `BGE_M3_URL`
- `BGE_M3_MODEL`
- `CROSS_ENCODER_ENDPOINT`
- `USE_CROSS_ENCODER`
- `DEFAULT_ATTENUATION_FACTOR`
- `MAX_TRAVERSAL_DEPTH`
- `GRAPH_GAP_THRESHOLD`
- `GRAPH_MAX_ITERATIONS`
- `GRAPH_MAX_DISCOVERED_NODES`

**❌ Missing from Settings:**
(See recommendations below)

---

## Part 3: Recommendations

### Immediate Actions (High Priority)

1. **Add Missing .env Variables:**
```bash
# Cross-Encoder Tuning
CROSS_ENCODER_HEALTH_TIMEOUT=2
CROSS_ENCODER_REQUEST_TIMEOUT=10
CROSS_ENCODER_FALLBACK_SCORE=0.5

# Agent Orchestrator
AGENT_MAX_RETRIES=3
AGENT_CACHE_ENABLED=true
DSPY_CACHE_DIR=~/.cache/florent/dspy_cache
AGENT_DEFAULT_IMPORTANCE=0.5
AGENT_DEFAULT_INFLUENCE=0.5
AGENT_TOKENS_PER_EVAL=300
AGENT_TOKENS_PER_DISCOVERY=500
AGENT_BACKOFF_BASE=2

# Matrix Classification
MATRIX_INFLUENCE_THRESHOLD=0.6
MATRIX_IMPORTANCE_THRESHOLD=0.6
MATRIX_HIGH_RISK_THRESHOLD=0.7
MATRIX_HIGH_INFLUENCE_THRESHOLD=0.7

# Bidding Logic
BID_CRITICAL_DEP_MAX_RATIO=0.5
BID_MIN_BANKABILITY_THRESHOLD=0.7

# Recommendations
RECOMMENDATION_HIGH_CONFIDENCE=0.9
RECOMMENDATION_LOW_CONFIDENCE=0.6
RECOMMENDATION_BANKABILITY_HIGH=0.8
RECOMMENDATION_BANKABILITY_MEDIUM=0.6

# Graph Builder Edge Weights
GRAPH_DEFAULT_EDGE_WEIGHT=0.8
GRAPH_DISTANCE_DECAY_FACTOR=0.9
GRAPH_MAX_NODES_PER_GAP=3
GRAPH_DISCOVERED_MIN_WEIGHT=0.4
GRAPH_DISCOVERED_DEFAULT_WEIGHT=0.6
GRAPH_DISCOVERED_EDGE_WEIGHT=0.8
GRAPH_INFRASTRUCTURE_WEIGHT=0.5
GRAPH_BRIDGE_GAP_WEIGHT=0.7
GRAPH_BRIDGE_GAP_MIN_WEIGHT=0.5
GRAPH_MAX_GAPS_PER_ITERATION=5

# Pipeline Risk Propagation
PIPELINE_MIN_EDGE_WEIGHT=0.6
PIPELINE_EDGE_WEIGHT_DECAY=0.05
PIPELINE_INITIAL_EDGE_WEIGHT=0.9
PIPELINE_RISK_PROPAGATION_FACTOR=0.5
PIPELINE_CRITICAL_CHAIN_THRESHOLD=0.1
PIPELINE_DEFAULT_BUDGET=100

# Metrics Defaults
METRICS_DEFAULT_FAILURE_LIKELIHOOD=0.5
```

2. **Create Dataclass Module:**
```
src/models/scoring.py          # Cross-encoder dataclasses
src/models/gaps.py             # Gap analysis dataclasses
src/models/caching.py          # Cache key dataclasses
src/models/recommendations.py  # Recommendation dataclasses
```

3. **Consolidate Duplicate Code:**
- `src/services/analysis/matrix.py` vs `src/services/agent/analysis/matrix_classifier.py`
- Both implement similar matrix classification logic with different thresholds

### Medium Priority

4. **Create Configuration Schemas:**
```python
# src/config/schemas.py
@dataclass
class CrossEncoderConfig:
    endpoint: str
    health_timeout: float
    request_timeout: float
    fallback_score: float

    @classmethod
    def from_env(cls):
        return cls(
            endpoint=settings.CROSS_ENCODER_ENDPOINT,
            health_timeout=float(os.getenv("CROSS_ENCODER_HEALTH_TIMEOUT", "2")),
            ...
        )
```

5. **Implement Discovery Persona Configuration:**
```json
// data/config/discovery_personas.json
[
  {
    "name": "Technical Infrastructure Expert",
    "description": "Focuses on hardware, software, and technical dependencies",
    "expertise_areas": ["infrastructure", "technical", "it_systems"],
    "bias_towards": ["technical"],
    "discovery_weight": 1.0
  },
  {
    "name": "Financial Risk & Compliance Auditor",
    "description": "Identifies financial and regulatory hidden dependencies",
    "expertise_areas": ["finance", "compliance", "regulatory"],
    "bias_towards": ["financial"],
    "discovery_weight": 0.9
  },
  {
    "name": "Geopolitical & Regulatory Consultant",
    "description": "Uncovers political and cross-border dependencies",
    "expertise_areas": ["geopolitical", "regulatory", "international"],
    "bias_towards": ["political"],
    "discovery_weight": 0.85
  }
]
```

### Low Priority

6. **Token Cost Tracking:**
- Create `TokenUsageTracker` dataclass
- Log token usage by operation type
- Calculate real-time cost estimates

7. **Performance Profiling:**
- Add `ExecutionTrace` dataclass to track timing
- Identify bottlenecks in agent evaluation vs cross-encoder scoring

---

## Part 4: Migration Priority Matrix

| Component | Struct Impact | Config Impact | Priority | Effort |
|-----------|---------------|---------------|----------|--------|
| Cross-Encoder Client | HIGH | MEDIUM | 🔴 P0 | 2-3 hours |
| Graph Builder | HIGH | MEDIUM | 🔴 P0 | 3-4 hours |
| Orchestrator V2 | MEDIUM | HIGH | 🟡 P1 | 2-3 hours |
| Settings Migration | LOW | HIGH | 🟡 P1 | 1-2 hours |
| Pipeline | MEDIUM | MEDIUM | 🟢 P2 | 2-3 hours |
| Matrix Consolidation | LOW | LOW | 🟢 P2 | 1 hour |

---

## Appendix A: Risk Formula Inventory

These are **NOT tunable** as they define core algorithm behavior:

| Location | Formula | Purpose |
|----------|---------|---------|
| orchestrator_v2.py:139 | `risk = importance * (1.0 - influence)` | Derived risk calculation |
| cross_encoder_client.py:98 | `score = (cosine + 1.0) / 2.0` | Normalize cosine to [0,1] |
| pipeline.py:182 | `combined_risk = min(1.0, local + max_parent * local * 0.5)` | Risk propagation compound |
| graph_builder.py:127 | `edge_weight = similarity * (decay_factor ** distance)` | Distance-weighted similarity |

---

## Appendix B: Settings Class Enhancement

**Current:** 19 settings
**Recommended:** 55+ settings (36 new)

Suggest creating setting groups:
```python
class Settings:
    # Current settings...

    @property
    def cross_encoder(self) -> CrossEncoderConfig:
        return CrossEncoderConfig.from_env()

    @property
    def agent(self) -> AgentConfig:
        return AgentConfig.from_env()

    @property
    def matrix(self) -> MatrixConfig:
        return MatrixConfig.from_env()

    # etc.
```

This allows for cleaner access:
```python
# Instead of:
timeout = int(os.getenv("CROSS_ENCODER_REQUEST_TIMEOUT", "10"))

# Use:
timeout = settings.cross_encoder.request_timeout
```

---

**End of Audit**
