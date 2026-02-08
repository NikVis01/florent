# Changelog

## [1.1.0] - 2026-02-08

### Added
- **Cross-Encoder Integration**: BGE-M3 reranker for firm-contextual graph generation
- **FirmContextualGraphBuilder**: Automatic graph construction with firm-specific edge weights
- **Gap Detection**: Identifies capability gaps (edge weight < 0.3) and triggers agent discovery
- **Iterative Refinement**: Re-scores edges after node injection until convergence
- **CrossEncoderClient**: REST client for BGE-M3 embeddings service

### Changed
- Graph construction now uses cross-encoder similarity instead of hardcoded weights (0.8)
- Edge weights are firm-specific based on capability-requirement match
- Discovery agents now trigger based on low edge weights (gaps) not just importance scores
- Updated main.py to use `build_firm_contextual_graph()` for all analyses
- Settings updated with `CROSS_ENCODER_ENDPOINT` and `USE_CROSS_ENCODER` flags

### Technical Details
- Edge weight formula: `weight = sigmoid(cross_encoder_similarity) × 0.9^distance`
- Gap threshold: 0.3 (edges below this trigger discovery)
- Max discovered nodes per analysis: 20
- Max refinement iterations: 3
- BGE-M3 endpoint: `http://localhost:8080` (from docker/docker-compose-api.yaml)

### Architecture
```
Firm + Project
    ↓
Initial Graph (from project.ops_requirements)
    ↓
Cross-Encoder Scores All Edges (firm-specific weights)
    ↓
Detect Gaps (weight < 0.3)
    ↓
DSPy Agent Discovers Missing Nodes
    ↓
Inject Nodes + Re-score Edges
    ↓
Iterate Until Convergence
    ↓
Firm-Contextual Weighted Graph
    ↓
Orchestrator Analysis (importance/influence/risk)
```

### Documentation
- Updated README.md with cross-encoder architecture
- Added SYSTEM_OVERVIEW.md section on cross-encoder foundation
- Updated docker setup to use existing docker/docker-compose-api.yaml
- Added test_cross_encoder.py for quick testing

### Tests
- 238 tests passing (100%)
- All ruff linting checks pass
- OpenAPI spec generation works

### Breaking Changes
- Graph edge weights are no longer static (0.8) - they're firm-specific
- Discovery now happens during graph construction (not just during traversal)
- Requires BGE-M3 service running (can disable with `USE_CROSS_ENCODER=false`)

---

## [1.0.0] - 2026-02-07

### Initial Release
- DSPy agent-based risk analysis
- 2×2 risk matrix classification
- Critical chain detection
- REST API with Litestar
- 264 tests (later consolidated to 238)
