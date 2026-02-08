# Florent Configuration Guide

Complete guide to configuring Florent's risk assessment system.

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Configuration Modules](#configuration-modules)
4. [Environment Variables](#environment-variables)
5. [Advanced Usage](#advanced-usage)
6. [Discovery Personas](#discovery-personas)

---

## Overview

Florent uses a **type-safe, centralized configuration system** with 41 tunable parameters organized into 6 modules:

- **CrossEncoderConfig** - BGE-M3 inference settings
- **AgentConfig** - DSPy orchestrator settings
- **MatrixConfig** - Classification thresholds
- **BiddingConfig** - Bid decision logic
- **GraphBuilderConfig** - Graph construction
- **PipelineConfig** - Risk propagation

All parameters load from `.env` with sensible defaults and validation.

---

## Quick Start

### 1. Copy Example Config

```bash
cp .env.example .env
```

### 2. Set Required Variables

```bash
# .env
OPENAI_API_KEY=your_key_here
LLM_MODEL=gpt-4o-mini
```

### 3. Access Configuration in Code

```python
from src.settings import settings

# Access structured configs
timeout = settings.cross_encoder.request_timeout
max_retries = settings.agent.max_retries
threshold = settings.matrix.influence_threshold

# Or get all configs
configs = settings.get_all_configs()
```

---

## Configuration Modules

### CrossEncoderConfig

**Purpose:** Configure BGE-M3 cross-encoder inference service

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `endpoint` | str | `http://localhost:8080` | Cross-encoder service URL |
| `enabled` | bool | `true` | Enable/disable cross-encoder |
| `health_timeout` | float | `2.0` | Health check timeout (seconds) |
| `request_timeout` | float | `10.0` | Request timeout (seconds) |
| `fallback_score` | float | `0.5` | Score when service fails |

**Example:**
```python
# .env
CROSS_ENCODER_ENDPOINT=http://localhost:8080
CROSS_ENCODER_HEALTH_TIMEOUT=3.0
CROSS_ENCODER_REQUEST_TIMEOUT=15.0
CROSS_ENCODER_FALLBACK_SCORE=0.5

# Code
config = settings.cross_encoder
print(f"Endpoint: {config.endpoint}")
print(f"Timeout: {config.request_timeout}s")
```

---

### AgentConfig

**Purpose:** Configure DSPy agent orchestrator behavior

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `max_retries` | int | `3` | Max retry attempts for failed DSPy calls |
| `backoff_base` | int | `2` | Exponential backoff base (wait = base^attempt) |
| `cache_enabled` | bool | `true` | Enable disk-based caching |
| `cache_dir` | Path | `~/.cache/florent/dspy_cache` | Cache directory |
| `default_importance` | float | `0.5` | Default importance score on failure |
| `default_influence` | float | `0.5` | Default influence score on failure |
| `tokens_per_eval` | int | `300` | Estimated tokens per node evaluation |
| `tokens_per_discovery` | int | `500` | Estimated tokens per discovery operation |

**Example:**
```python
# .env
AGENT_MAX_RETRIES=5
AGENT_BACKOFF_BASE=2
AGENT_CACHE_ENABLED=true
DSPY_CACHE_DIR=~/.cache/florent/dspy_cache

# Code
config = settings.agent
orchestrator = RiskOrchestrator(
    firm, project, graph,
    max_retries=config.max_retries
)
```

**Token Cost Tracking:**
```python
# Automatic token tracking
print(orchestrator.token_tracker.get_breakdown())
# {
#   "node_evaluation": 3000,
#   "discovery": 1500,
#   "total_tokens": 4500,
#   "total_cost_usd": 0.0068
# }
```

---

### MatrixConfig

**Purpose:** Configure importance/influence matrix classification

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `influence_threshold` | float | `0.6` | Threshold for "high influence" (0-1) |
| `importance_threshold` | float | `0.6` | Threshold for "high importance" (0-1) |

**Matrix Quadrants:**
- **Type A** (High Influence, High Importance) - Strategic Wins
- **Type B** (High Influence, Low Importance) - Quick Wins
- **Type C** (Low Influence, High Importance) - Critical Dependencies ⚠️
- **Type D** (Low Influence, Low Importance) - Monitor

**Example:**
```python
# .env
MATRIX_INFLUENCE_THRESHOLD=0.65
MATRIX_IMPORTANCE_THRESHOLD=0.65

# Code
config = settings.matrix
classifications = classify_all_nodes(
    assessments, node_names,
    influence_threshold=config.influence_threshold,
    importance_threshold=config.importance_threshold
)
```

---

### BiddingConfig

**Purpose:** Configure bid decision logic

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `critical_dep_max_ratio` | float | `0.5` | Max ratio of Type C nodes on critical path |
| `min_bankability_threshold` | float | `0.7` | Min bankability to recommend bidding |
| `high_confidence` | float | `0.9` | High confidence threshold |
| `low_confidence` | float | `0.6` | Low confidence threshold |
| `bankability_high` | float | `0.8` | "Strong bankability" threshold |
| `bankability_medium` | float | `0.6` | "Moderate bankability" threshold |

**Decision Logic:**
```python
# Don't bid if > 50% of critical path is Type C (unmanaged dependencies)
if critical_dep_ratio > config.critical_dep_max_ratio:
    recommendation = "DO NOT BID"

# Bid if bankability >= 0.7
if bankability >= config.min_bankability_threshold:
    recommendation = "PROCEED"
```

**Example:**
```python
# .env
BID_CRITICAL_DEP_MAX_RATIO=0.4  # More conservative
BID_MIN_BANKABILITY_THRESHOLD=0.75

# Code
config = settings.bidding
should_bid = should_bid_decision(classifications, critical_chain)
```

---

### GraphBuilderConfig

**Purpose:** Configure graph construction and node discovery

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `gap_threshold` | float | `0.3` | Similarity floor for triggering discovery |
| `max_iterations` | int | `10` | Max gap-filling iterations |
| `max_discovered_nodes` | int | `50` | Global limit on discovered nodes |
| `max_nodes_per_gap` | int | `3` | Max nodes to inject per gap |
| `max_gaps_per_iteration` | int | `5` | Max gaps to process per iteration |
| `default_edge_weight` | float | `0.8` | Default weight for new edges |
| `distance_decay_factor` | float | `0.9` | Distance decay (weight = sim * decay^dist) |
| `discovered_min_weight` | float | `0.4` | Minimum weight for discovered edges |
| `discovered_default_weight` | float | `0.6` | Default weight for discovered nodes |
| `discovered_edge_weight` | float | `0.8` | Weight for discovery edges |
| `infrastructure_weight` | float | `0.5` | Weight for sustainment edges |
| `bridge_gap_weight` | float | `0.7` | Weight for gap-bridging edges |
| `bridge_gap_min_weight` | float | `0.5` | Min weight for gap bridges |

**Example:**
```python
# .env
GRAPH_GAP_THRESHOLD=0.25  # More aggressive discovery
GRAPH_MAX_DISCOVERED_NODES=100  # Allow more discoveries
GRAPH_DISTANCE_DECAY_FACTOR=0.85  # Faster decay

# Code
config = settings.graph_builder
builder = FirmContextualGraphBuilder(
    firm, project,
    gap_threshold=config.gap_threshold,
    max_discovered_nodes=config.max_discovered_nodes
)
```

---

### PipelineConfig

**Purpose:** Configure risk propagation and analysis pipeline

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `min_edge_weight` | float | `0.6` | Minimum edge weight in graph |
| `edge_weight_decay` | float | `0.05` | Weight decay per edge |
| `initial_edge_weight` | float | `0.9` | Initial edge weight |
| `risk_propagation_factor` | float | `0.5` | Risk compound multiplier |
| `critical_chain_threshold` | float | `0.1` | Min risk for critical chains |
| `default_budget` | int | `100` | Default node evaluation budget |
| `default_failure_likelihood` | float | `0.5` | Default risk for missing nodes |

**Risk Propagation Formula:**
```python
# Combined risk at node
risk = local_risk + (max_parent_risk * local_risk * propagation_factor)
```

**Example:**
```python
# .env
PIPELINE_RISK_PROPAGATION_FACTOR=0.6  # More aggressive propagation
PIPELINE_CRITICAL_CHAIN_THRESHOLD=0.15  # Higher threshold
PIPELINE_DEFAULT_BUDGET=150  # More thorough analysis

# Code
config = settings.pipeline
result = run_analysis(firm, project, budget=config.default_budget)
```

---

## Environment Variables

### Complete .env Reference

```bash
# ==============================================================================
# LLM Configuration
# ==============================================================================
OPENAI_API_KEY=your_key_here
LLM_MODEL=gpt-4o-mini

# ==============================================================================
# Cross-Encoder
# ==============================================================================
CROSS_ENCODER_ENDPOINT=http://localhost:8080
USE_CROSS_ENCODER=true
CROSS_ENCODER_HEALTH_TIMEOUT=2
CROSS_ENCODER_REQUEST_TIMEOUT=10
CROSS_ENCODER_FALLBACK_SCORE=0.5

# ==============================================================================
# Agent Orchestrator
# ==============================================================================
AGENT_MAX_RETRIES=3
AGENT_BACKOFF_BASE=2
AGENT_CACHE_ENABLED=true
DSPY_CACHE_DIR=~/.cache/florent/dspy_cache
AGENT_DEFAULT_IMPORTANCE=0.5
AGENT_DEFAULT_INFLUENCE=0.5
AGENT_TOKENS_PER_EVAL=300
AGENT_TOKENS_PER_DISCOVERY=500

# ==============================================================================
# Matrix Classification
# ==============================================================================
MATRIX_INFLUENCE_THRESHOLD=0.6
MATRIX_IMPORTANCE_THRESHOLD=0.6

# ==============================================================================
# Bidding Logic
# ==============================================================================
BID_CRITICAL_DEP_MAX_RATIO=0.5
BID_MIN_BANKABILITY_THRESHOLD=0.7
RECOMMENDATION_HIGH_CONFIDENCE=0.9
RECOMMENDATION_LOW_CONFIDENCE=0.6
RECOMMENDATION_BANKABILITY_HIGH=0.8
RECOMMENDATION_BANKABILITY_MEDIUM=0.6

# ==============================================================================
# Graph Builder
# ==============================================================================
GRAPH_GAP_THRESHOLD=0.3
GRAPH_MAX_ITERATIONS=10
GRAPH_MAX_DISCOVERED_NODES=50
GRAPH_MAX_NODES_PER_GAP=3
GRAPH_MAX_GAPS_PER_ITERATION=5
GRAPH_DEFAULT_EDGE_WEIGHT=0.8
GRAPH_DISTANCE_DECAY_FACTOR=0.9
GRAPH_DISCOVERED_MIN_WEIGHT=0.4
GRAPH_DISCOVERED_DEFAULT_WEIGHT=0.6
GRAPH_DISCOVERED_EDGE_WEIGHT=0.8
GRAPH_INFRASTRUCTURE_WEIGHT=0.5
GRAPH_BRIDGE_GAP_WEIGHT=0.7
GRAPH_BRIDGE_GAP_MIN_WEIGHT=0.5

# ==============================================================================
# Pipeline
# ==============================================================================
PIPELINE_MIN_EDGE_WEIGHT=0.6
PIPELINE_EDGE_WEIGHT_DECAY=0.05
PIPELINE_INITIAL_EDGE_WEIGHT=0.9
PIPELINE_RISK_PROPAGATION_FACTOR=0.5
PIPELINE_CRITICAL_CHAIN_THRESHOLD=0.1
PIPELINE_DEFAULT_BUDGET=100
METRICS_DEFAULT_FAILURE_LIKELIHOOD=0.5
```

---

## Advanced Usage

### Configuration Override (Experiments)

```python
from src.config.schemas import override_config

# Load baseline
configs = settings.get_all_configs()

# Create experiment variant
experiment = override_config(configs, {
    "matrix.influence_threshold": 0.7,
    "agent.max_retries": 5,
    "bidding.critical_dep_max_ratio": 0.4
})

# Use experiment config
# (Pass to components manually or set env vars)
```

### Export Config for Logging

```python
# Get serializable config dict
config_dict = settings.export_config_dict()

import json
with open("config_snapshot.json", "w") as f:
    json.dump(config_dict, indent=2, default=str)
```

### Validation

All configs validate on load:

```python
# Invalid config raises error
MATRIX_INFLUENCE_THRESHOLD=1.5  # > 1.0, will raise AssertionError

# Validation messages
try:
    config = MatrixConfig.from_env()
    config.validate()
except AssertionError as e:
    print(f"Invalid config: {e}")
```

---

## Discovery Personas

### Default Personas

Florent uses 4 discovery personas to identify hidden dependencies:

1. **Technical Infrastructure Expert** (weight: 1.0)
   - Focuses on: hardware, software, engineering, construction
   - Bias: technical dependencies

2. **Financial Risk & Compliance Auditor** (weight: 0.9)
   - Focuses on: finance, compliance, regulatory, auditing
   - Bias: financial dependencies

3. **Geopolitical & Regulatory Consultant** (weight: 0.85)
   - Focuses on: geopolitical, international policy, law
   - Bias: political dependencies

4. **Supply Chain & Logistics Expert** (weight: 0.95)
   - Focuses on: supply chain, logistics, transportation
   - Bias: supply chain dependencies

### Custom Personas

Edit `data/config/discovery_personas.json`:

```json
[
  {
    "name": "Environmental Impact Specialist",
    "description": "Identifies environmental and sustainability dependencies",
    "expertise_areas": ["environmental", "sustainability", "climate"],
    "bias_towards": ["environmental"],
    "discovery_weight": 0.9
  }
]
```

Load custom personas:

```python
from src.models.orchestration import load_personas_from_config

personas = load_personas_from_config("data/config/discovery_personas.json")
orchestrator.personas = personas
```

---

## Tuning Guide

### Conservative Configuration

```bash
# For high-stakes projects, be conservative
BID_CRITICAL_DEP_MAX_RATIO=0.3  # Lower tolerance for Type C
BID_MIN_BANKABILITY_THRESHOLD=0.8  # Higher bar for bidding
MATRIX_INFLUENCE_THRESHOLD=0.7  # Stricter classification
GRAPH_GAP_THRESHOLD=0.2  # More aggressive gap detection
```

### Aggressive Configuration

```bash
# For exploratory analysis, be aggressive
BID_CRITICAL_DEP_MAX_RATIO=0.6  # Higher tolerance
BID_MIN_BANKABILITY_THRESHOLD=0.6  # Lower bar
GRAPH_MAX_DISCOVERED_NODES=100  # More discoveries
PIPELINE_DEFAULT_BUDGET=200  # Thorough analysis
```

### Fast Configuration

```bash
# For quick analysis
AGENT_MAX_RETRIES=1  # Fewer retries
GRAPH_MAX_ITERATIONS=5  # Fewer iterations
GRAPH_MAX_DISCOVERED_NODES=25  # Limit discoveries
PIPELINE_DEFAULT_BUDGET=50  # Smaller budget
```

---

## Troubleshooting

### Config Not Loading

```python
# Check if .env is loaded
import os
print(os.getenv("MATRIX_INFLUENCE_THRESHOLD"))

# Force reload
from dotenv import load_dotenv
load_dotenv(override=True)
```

### Validation Errors

```python
# See which config is invalid
for name, config in settings.get_all_configs().items():
    try:
        config.validate()
        print(f"✓ {name} valid")
    except AssertionError as e:
        print(f"✗ {name} invalid: {e}")
```

### Performance Issues

```bash
# Reduce computational load
GRAPH_MAX_DISCOVERED_NODES=25
PIPELINE_DEFAULT_BUDGET=50
AGENT_CACHE_ENABLED=true  # Enable caching
```

---

## See Also

- [System Overview](SYSTEM_OVERVIEW.md)
- [API Documentation](API.md)
- [Changelog](CHANGELOG.md)
