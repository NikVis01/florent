# Dataclass & Configuration Refactor - Progress Report

**Date:** 2026-02-08
**Status:** Phase 1 Complete (Foundation)

---

## ✅ Completed (6/18 tasks)

### 1. `.env.example` - All Tunable Parameters Added
**File:** `.env.example`

Added **36 new environment variables** organized by category:
- **Cross-Encoder** (5 params): timeouts, fallback scores
- **Agent Orchestrator** (9 params): retries, defaults, token estimates
- **Matrix Classification** (4 params): influence/importance thresholds
- **Bidding Logic** (4 params): confidence, bankability thresholds
- **Graph Builder** (12 params): edge weights, gaps, discovery limits
- **Pipeline** (7 params): risk propagation, chain detection

All parameters now have:
- Clear descriptions
- Sensible defaults
- Grouped by functional area

---

### 2. Configuration Schemas Module
**Files:** `src/config/schemas.py`, `src/config/__init__.py`

Created typed configuration dataclasses:
```python
@dataclass
class CrossEncoderConfig:
    endpoint: str
    enabled: bool
    health_timeout: float
    request_timeout: float
    fallback_score: float

    @classmethod
    def from_env(cls) -> "CrossEncoderConfig"
    def validate(self)
```

**Modules created:**
- `CrossEncoderConfig` - BGE-M3 inference settings
- `AgentConfig` - DSPy orchestrator settings
- `MatrixConfig` - Classification thresholds
- `BiddingConfig` - Bid decision logic
- `GraphBuilderConfig` - Graph construction & discovery
- `PipelineConfig` - Risk propagation & execution

**Features:**
- Type-safe configuration objects
- `.from_env()` class methods for loading
- `.validate()` methods for constraints
- `get_all_configs()` for bulk loading
- `override_config()` for hyperparameter tuning experiments

---

### 3. Scoring Dataclasses
**File:** `src/models/scoring.py`

Structured types for cross-encoder outputs:

```python
@dataclass
class CrossEncoderScore:
    query_text: str
    passage_text: str
    similarity_score: float  # 0-1
    raw_cosine: float  # -1 to 1
    timestamp: datetime
    metadata: Dict[str, Any]

@dataclass
class FirmNodeScore:
    firm: Firm
    node: Node
    cross_encoder_score: float
    firm_text: str
    node_text: str
    timestamp: datetime

@dataclass
class BatchScoringResult:
    firm: Firm
    nodes: List[Node]
    scores: List[FirmNodeScore]
    total_time_ms: float
    endpoint: str

    def get_top_k(k: int) -> List[FirmNodeScore]
    def to_legacy_format() -> List[Tuple[Node, float]]
```

**Benefits:**
- Type safety for cross-encoder outputs
- Timing and provenance tracking
- Helper methods for common operations
- Backward compatibility with legacy tuple format

---

### 4. Orchestration Dataclasses
**File:** `src/models/orchestration.py`

Agent execution tracking structures:

```python
@dataclass
class TokenUsageTracker:
    node_evaluation: int
    discovery: int
    total_operations: int
    model: str
    cost_per_1k_tokens: float

    def add_node_eval(tokens: int)
    def add_discovery(tokens: int)
    @property total_cost_usd -> float
    def get_breakdown() -> Dict

@dataclass
class DiscoveryPersona:
    name: str
    description: str
    expertise_areas: List[str]
    bias_towards: List[str]
    discovery_weight: float

@dataclass
class ExecutionTrace:
    firm_id: str
    project_id: str
    current_phase: ExecutionPhase
    budget_allocated: int
    budget_used: int
    token_tracker: TokenUsageTracker

    def start_phase(phase: ExecutionPhase)
    def complete_phase(phase: ExecutionPhase)
    def get_summary() -> Dict
```

**Features:**
- Token cost tracking by operation type
- 4 default discovery personas (Technical, Financial, Geopolitical, Supply Chain)
- Execution phase tracking for debugging
- Budget management

---

### 5. Settings.py Integration
**File:** `src/settings.py`

Extended existing `Settings` class with structured config properties:

```python
class Settings:
    # Legacy flat attributes (unchanged)
    OPENAI_API_KEY: str
    LLM_MODEL: str
    GRAPH_GAP_THRESHOLD: float
    # ...

    # New structured config objects
    @cached_property
    def cross_encoder(self) -> CrossEncoderConfig:
        return CrossEncoderConfig.from_env()

    @cached_property
    def agent(self) -> AgentConfig:
        return AgentConfig.from_env()

    # ... etc.

    def get_all_configs() -> Dict[str, Any]
    def export_config_dict() -> Dict[str, Dict[str, Any]]
```

**Migration Path:**
```python
# Old way (still works)
timeout = settings.CROSS_ENCODER_REQUEST_TIMEOUT

# New way (preferred)
timeout = settings.cross_encoder.request_timeout
```

**Benefits:**
- Backward compatible
- Type hints for IDE autocomplete
- Grouped configuration access
- Validation on load

---

### 6. Matrix Implementation Consolidation
**Changes:**
- ✅ Removed `src/services/analysis/matrix.py` (legacy risk-based classification)
- ✅ Updated `src/services/pipeline.py` to use `matrix_classifier`
- ✅ Rewrote `tests/test_matrix.py` with importance/influence semantics
- ✅ All imports now point to `src/services/agent/analysis/matrix_classifier.py`

**Semantic Shift:**
```python
# Old matrix (DELETED):
classify_node(influence=0.8, risk=0.9)  # Wrong: risk is derived

# New matrix (CANONICAL):
classify_node(influence=0.8, importance=0.9)  # Correct: raw agent scores
```

**Result:** Single source of truth for matrix classification using correct importance/influence semantics.

---

## 🚧 In Progress (12/18 tasks)

### High Priority (Next Steps)

**Task #9:** Refactor CrossEncoderClient
- Use `CrossEncoderConfig` from settings
- Return `FirmNodeScore` instead of raw floats
- Return `BatchScoringResult` for batch ops
- Add timing metrics

**Task #11:** Refactor Orchestrator
- Use `AgentConfig` from settings
- Implement `TokenUsageTracker`
- Load personas from config
- Add `ExecutionTrace`

**Task #14:** Create Personas JSON Config
- Path: `data/config/discovery_personas.json`
- 4 default personas with configurable weights

**Task #15:** Create main.py Parameter Interface
- CLI args for all tunable parameters
- `--show-config` flag
- `--validate-config` flag
- Override .env with CLI args

### Medium Priority

**Task #10:** Refactor GraphBuilder *(skip gap dataclasses)*
- Use `GraphBuilderConfig` from settings
- Focus on edge weight parameters

**Task #12:** Refactor Pipeline
- Use `PipelineConfig` from settings
- Structured AnalysisOutput (already exists)

**Task #16:** Hyperparameter Tuning Infrastructure
- `src/tuning/grid_search.py`
- Grid search over config parameters
- Experiment tracking
- Results visualization

### Low Priority

**Task #17:** Update Tests
- Test new config loading
- Test dataclass validation
- Integration tests

**Task #18:** Update Documentation
- Configuration guide
- Hyperparameter tuning guide
- API docs

---

## 📊 Parameter Coverage

| Category | Parameters | In .env | Loaded | Used |
|----------|-----------|---------|--------|------|
| Cross-Encoder | 5 | ✅ | ✅ | 🚧 |
| Agent | 9 | ✅ | ✅ | 🚧 |
| Matrix | 4 | ✅ | ✅ | ✅ |
| Bidding | 4 | ✅ | ✅ | 🚧 |
| Graph Builder | 12 | ✅ | ✅ | 🚧 |
| Pipeline | 7 | ✅ | ✅ | 🚧 |
| **TOTAL** | **41** | **41/41** | **41/41** | **4/41** |

**Next:** Wire up config objects to actual component usage

---

## 🎯 Key Benefits Achieved

### Type Safety
```python
# Before: Magic numbers scattered everywhere
edge_weight = 0.8  # Where did this come from?
threshold = 0.6    # What does this control?

# After: Typed, validated, documented
edge_weight = settings.graph_builder.default_edge_weight
threshold = settings.matrix.influence_threshold
```

### Centralized Configuration
```python
# Before: Parameters in 6 different files

# After: Single source of truth
configs = settings.get_all_configs()
for module, config in configs.items():
    print(f"{module}: {config}")
```

### Hyperparameter Tuning Ready
```python
# Override for experiments
from src.config.schemas import override_config

configs = settings.get_all_configs()
configs = override_config(configs, {
    "matrix.influence_threshold": 0.7,
    "agent.max_retries": 5
})
```

### Better Debugging
```python
# Export full config for logging
config_snapshot = settings.export_config_dict()
logger.info("analysis_started", config=config_snapshot)
```

---

## 📝 Notes

### Skipped Tasks (Per User Request)
- ❌ Task #4: Gap analysis dataclasses (not needed for core assessment)
- ❌ Task #5: Caching dataclasses (premature optimization)
- ❌ Task #7: Recommendation dataclasses (keep simple for now)

### Focus Areas
✅ **Importance Assessment** - How critical a node is to project success
✅ **Influence Assessment** - How much control the firm has over the node
✅ **Risk Calculation** - `risk = importance × (1 - influence)`
✅ **Matrix Classification** - Based on importance/influence
✅ **Configuration** - All tunable parameters centralized

---

## 🚀 Next Session Goals

1. **Refactor Components** (Tasks #9, #10, #11, #12)
   - Update CrossEncoderClient, GraphBuilder, Orchestrator, Pipeline
   - Use new config objects and dataclasses
   - Add timing/cost tracking

2. **Main.py Interface** (Task #15)
   - CLI parameter interface
   - Config validation and display
   - Override mechanism

3. **Hyperparameter Tuning** (Task #16)
   - Grid search implementation
   - Experiment tracking
   - Best config identification

---

**Estimated Completion:** 4-6 hours of focused work
