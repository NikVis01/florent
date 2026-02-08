# Florent: Infrastructure Risk Analysis Engine

AI-powered risk analysis for infrastructure consulting firms. Determines bid viability by mapping firm capabilities against project dependency graphs using cross-encoder similarity and agent-driven discovery.

## What It Does

Analyzes whether a consulting firm should bid on an infrastructure project by:
1. Building a firm-specific dependency graph with cross-encoder weighted edges
2. Discovering missing nodes for capability gaps using AI agents
3. Evaluating each task for importance and firm influence
4. Classifying tasks into strategic quadrants (Mitigate/Automate/Contingency/Delegate)
5. Detecting critical failure chains
6. Providing Go/No-Go recommendation with confidence score

## Architecture

### Three-Layer System

**Layer 1: Cross-Encoder Foundation** (Fast)
- BGE-M3 reranker calculates firm-node similarity
- Generates firm-specific edge weights
- Detects capability gaps (low-weight edges)
- Formula: `weight = sigmoid(similarity) × 0.9^distance`

**Layer 2: Agent Discovery** (Creative)
- DSPy + OpenAI agents discover missing nodes for gaps
- Triggered when edge weight < 0.3
- Injects nodes to bridge capability gaps
- Iterates until convergence or max iterations

**Layer 3: Evaluation & Analysis** (Strategic)
- DSPy agents evaluate importance/influence per node
- Risk calculation: `risk = importance × (1 - influence)`
- Critical chain detection via graph traversal
- Matrix classification (TYPE_A/B/C/D quadrants)

### Data Flow

```
firm.json + project.json
    ↓
Build Initial Graph (nodes from project requirements)
    ↓
Cross-Encoder Scores Edges (firm-specific weights)
    ↓
Detect Gaps (edges < 0.3)
    ↓
Agent Discovers Missing Nodes (iterative)
    ↓
Re-score New Edges
    ↓
Evaluation Agents Traverse Graph (importance/influence scores)
    ↓
Risk Propagation + Critical Chains
    ↓
Matrix Classification + Recommendation
    ↓
AnalysisOutput JSON
```

## Setup

### Prerequisites

- Python 3.13+
- Docker (for cross-encoder inference)
- OpenAI API key
- uv package manager

### Installation

```bash
# Clone repo
git clone <repo-url>
cd florent

# Install dependencies
uv sync

# Set environment variables
cp .env.example .env
# Edit .env and add OPENAI_API_KEY
```

### Configuration

Florent uses a **centralized configuration system** with 41 tunable parameters:

```bash
# Core settings
OPENAI_API_KEY=your_key_here
LLM_MODEL=gpt-4o-mini

# Tune matrix classification
MATRIX_INFLUENCE_THRESHOLD=0.6
MATRIX_IMPORTANCE_THRESHOLD=0.6

# Tune risk propagation
PIPELINE_RISK_PROPAGATION_FACTOR=0.5
PIPELINE_DEFAULT_BUDGET=100

# See docs/CONFIGURATION.md for all 41 parameters
```

Access configuration in code:

```python
from src.settings import settings

# Type-safe config access
max_retries = settings.agent.max_retries
threshold = settings.matrix.influence_threshold

# Token cost tracking
orchestrator.token_tracker.get_breakdown()
# {"total_tokens": 4500, "total_cost_usd": 0.0068}
```

**[Full Configuration Guide](docs/CONFIGURATION.md)**

### Cross-Encoder Service

BGE-M3 model runs automatically when using `./run.sh`. The docker-compose setup in `docker/docker-compose-api.yaml` includes both the API server and BGE-M3 model.

## Usage

### Build & Run

```bash
# Build and test
./update.sh

# Start server
./run.sh
```

Server runs on `http://localhost:8000`

### API

**POST /analyze**

Request:
```json
{
  "firm_path": "path/to/firm.json",
  "project_path": "path/to/project.json",
  "budget": 100
}
```

Or inline data:
```json
{
  "firm_data": { "id": "...", "name": "...", ... },
  "project_data": { "id": "...", "name": "...", ... },
  "budget": 100
}
```

Response:
```json
{
  "status": "success",
  "analysis": {
    "firm": {...},
    "project": {...},
    "node_assessments": {
      "node_1": {
        "importance_score": 0.92,
        "influence_score": 0.23,
        "risk_level": 0.71,
        "reasoning": "...",
        "is_on_critical_path": true
      }
    },
    "all_chains": [
      {
        "node_ids": ["entry", "node_1", "node_2", "exit"],
        "cumulative_risk": 0.68,
        "length": 4
      }
    ],
    "matrix_classifications": {
      "TYPE_A": [...],  // High importance, high influence
      "TYPE_B": [...],  // Low importance, high influence
      "TYPE_C": [...],  // High importance, low influence (DANGER)
      "TYPE_D": [...]   // Low importance, low influence
    },
    "summary": {
      "aggregate_project_score": 0.32,
      "critical_failure_likelihood": 0.68,
      "critical_dependency_count": 7,
      "nodes_evaluated": 50,
      "total_nodes": 63
    },
    "recommendation": {
      "should_bid": false,
      "confidence": 0.91,
      "reasoning": "Primary path has 68% failure risk. 7 critical dependencies outside firm control.",
      "key_risks": ["Environmental Clearance (Risk: 0.71)", ...],
      "key_opportunities": ["Foundation Design (Influence: 0.89)", ...]
    }
  }
}
```

## Input Format

### firm.json

```json
{
  "id": "firm_001",
  "name": "ABC Engineering",
  "description": "Civil engineering consultancy",
  "countries_active": [
    {"name": "Kenya", "a2": "KE", "a3": "KEN", "numeric": "404"}
  ],
  "sectors": [
    {"name": "Transport", "description": "Roads, railways, airports"}
  ],
  "services": [
    {"name": "Engineering", "category": "Technical", "description": "Design and supervision"}
  ],
  "strategic_focuses": [
    {"name": "Sustainability", "description": "Green infrastructure"}
  ],
  "prefered_project_timeline": 24
}
```

### project.json

```json
{
  "id": "proj_001",
  "name": "Highway Construction",
  "description": "200km highway in Kenya",
  "country": {"name": "Kenya", "a2": "KE", "a3": "KEN", "numeric": "404"},
  "sector": "Transport",
  "service_requirements": ["Engineering", "Construction Management"],
  "timeline": 36,
  "ops_requirements": [
    {"name": "Design", "category": "Technical", "description": "Highway design"},
    {"name": "Construction", "category": "Execution", "description": "Build highway"}
  ],
  "entry_criteria": {
    "pre_requisites": ["Funding approval", "Land acquisition"],
    "mobilization_time": 3,
    "entry_node_id": "entry"
  },
  "success_criteria": {
    "success_metrics": ["Highway operational", "Safety standards met"],
    "mandate_end_date": "2027-12-31",
    "exit_node_id": "exit"
  }
}
```

## Output Interpretation

### Key Metrics

- **aggregate_project_score** (0-1): Overall viability. >0.75 = strong, <0.4 = risky
- **critical_failure_likelihood** (0-1): Probability main path fails. <0.2 = safe, >0.6 = dangerous
- **critical_dependency_count**: Number of TYPE_C nodes (high importance, low influence). >5 = red flag
- **importance_score** (0-1): How critical a task is to success
- **influence_score** (0-1): How much control firm has over task
- **risk_level** (0-1): `importance × (1 - influence)`. >0.7 = critical risk
- **cumulative_risk** (0-1): Chain failure probability. >0.6 = dangerous path

### Strategic Quadrants

- **TYPE_A** (High Importance + High Influence): Complex tasks you're good at → **MITIGATE** with senior staff
- **TYPE_B** (Low Importance + High Influence): Easy tasks you own → **AUTOMATE** with SOPs
- **TYPE_C** (High Importance + Low Influence): Critical tasks you can't control → **CONTINGENCY** or **DON'T BID**
- **TYPE_D** (Low Importance + Low Influence): Peripheral tasks → **DELEGATE** to subcontractors

### Decision Rules

- **0-2 TYPE_C nodes**: Acceptable risk, price in contingency
- **3-5 TYPE_C nodes**: High risk, require partnerships/insurance
- **6+ TYPE_C nodes**: Don't bid (too many uncontrolled critical dependencies)

## OpenAPI & MATLAB Integration

### Generate OpenAPI Spec

```bash
# Generate OpenAPI specification
uv run python scripts/generate_openapi.py -o docs/openapi.json
```

### Export Schemas for MATLAB

```bash
# Export individual JSON schemas for MATLAB
uv run python scripts/export_openapi_schemas.py

# Output: docs/openapi_export/
# - schemas/         - Individual schema definitions
# - endpoints/       - Request/response structures
# - matlab/          - MATLAB helper functions
```

**MATLAB Usage:**
```matlab
% Add to path
addpath('docs/openapi_export/matlab');

% Load schemas
schemas = load_florent_schemas();

% Create API request
json_str = create_analysis_request('data/firm.json', 'data/project.json', 100);

% Send to API
options = weboptions('RequestMethod', 'post', 'MediaType', 'application/json');
response = webwrite('http://localhost:8000/analyze', json_str, options);
```

**[MATLAB Integration Guide](docs/openapi_export/README.md)**

## Testing

```bash
# Run all tests
uv run pytest tests/ -v

# Specific module
uv run pytest tests/test_graph_builder.py -v

# With coverage
uv run pytest --cov=src --cov-report=html
```

**264 tests, 100% passing**

## Docker Deployment

```bash
# Build and run (includes API + BGE-M3 model)
./run.sh

# Or manually
docker compose -f docker/docker-compose-api.yaml up --build

# Just the BGE-M3 model
docker compose -f docker/docker-compose-model.yaml up
```

## Mathematical Framework

### Cross-Encoder Edge Weight

```
weight = sigmoid(similarity(firm_vector, node_vector)) × decay^distance
```

Where:
- `similarity`: BGE-M3 attention score (0-1)
- `decay`: 0.9 (distance attenuation factor)
- `distance`: Graph hops from entry node

### Risk Propagation

```
risk_node = importance × (1 - influence)

chain_risk = 1 - ∏(1 - risk_i) for all i in chain
```

### Influence Score (DSPy Agent)

Contextual evaluation of firm-node match:
- Firm sectors vs node requirements
- Service offerings vs operation type
- Country experience vs project location
- Strategic focus alignment

## Project Structure

```
florent/
├── src/
│   ├── main.py                          # REST API (Litestar)
│   ├── config/                          # Configuration system
│   │   ├── __init__.py                  # PROJECT_ROOT, env loading
│   │   └── schemas.py                   # 6 config dataclasses (41 params)
│   ├── models/
│   │   ├── base.py                      # Primitives (Country, Sector, etc)
│   │   ├── entities.py                  # Firm, Project
│   │   ├── graph.py                     # Node, Edge, Graph (DAG)
│   │   ├── analysis.py                  # AnalysisOutput, NodeAssessment
│   │   ├── scoring.py                   # FirmNodeScore, CrossEncoderScore
│   │   └── orchestration.py             # TokenUsageTracker, ExecutionTrace
│   ├── services/
│   │   ├── graph_builder.py             # Firm-contextual graph construction
│   │   ├── pipeline.py                  # End-to-end analysis pipeline
│   │   ├── clients/
│   │   │   ├── ai_client.py             # DSPy/OpenAI client
│   │   │   └── cross_encoder_client.py  # BGE-M3 reranker client
│   │   ├── agent/
│   │   │   ├── core/
│   │   │   │   ├── orchestrator.py      # Legacy orchestrator
│   │   │   │   ├── orchestrator_v2.py   # Main analysis orchestrator
│   │   │   │   └── traversal.py         # Priority heap
│   │   │   ├── models/
│   │   │   │   └── signatures.py        # DSPy agent signatures
│   │   │   └── analysis/
│   │   │       ├── critical_chain.py    # Chain detection
│   │   │       └── matrix_classifier.py # 2×2 quadrant mapping
│   │   ├── analysis/
│   │   │   ├── propagation.py           # Risk propagation
│   │   │   └── chains.py                # Chain analysis
│   │   └── math/
│   │       └── risk.py                  # Risk formulas
│   └── settings.py                      # Settings singleton
├── scripts/
│   ├── generate_openapi.py              # OpenAPI spec generator
│   └── export_openapi_schemas.py        # MATLAB schema exporter
├── tests/                               # 264 tests (100% passing)
├── docs/
│   ├── CONFIGURATION.md                 # Configuration guide (41 params)
│   ├── SYSTEM_OVERVIEW.md               # Complete system documentation
│   ├── API.md                           # REST API reference
│   ├── SETUP.md                         # Developer setup guide
│   ├── INDEX.md                         # Documentation index
│   ├── openapi.json                     # OpenAPI 3.1 specification
│   └── openapi_export/                  # MATLAB integration
│       ├── schemas/                     # Individual schema JSONs
│       ├── endpoints/                   # Endpoint structures
│       └── matlab/                      # MATLAB helper functions
├── docker/
│   ├── docker-compose-api.yaml          # API + BGE-M3
│   └── docker-compose-model.yaml        # BGE-M3 only
├── update.sh                            # Build & test script
└── run.sh                               # Start server
```

## Performance

- Small project (20 nodes): <1s
- Medium project (50 nodes): <2s
- Test suite (264 tests): 2.8s
- Memory usage: <500MB
- Cross-encoder inference: ~10ms per edge
- DSPy evaluation: ~500ms per node

## Limitations

- Requires external cross-encoder service (can disable with `USE_CROSS_ENCODER=false`)
- Discovery limited to 20 nodes per analysis (configurable)
- Sequential node evaluation (parallel execution planned)
- Budget constraint required to control costs

## Documentation

### Core Documentation
- **[CONFIGURATION.md](docs/CONFIGURATION.md)** - Complete configuration guide (41 parameters)
- **[SYSTEM_OVERVIEW.md](docs/SYSTEM_OVERVIEW.md)** - Architecture and system design
- **[API.md](docs/API.md)** - REST API reference with examples
- **[SETUP.md](docs/SETUP.md)** - Developer setup guide

### API Integration
- **[openapi.json](docs/openapi.json)** - OpenAPI 3.1 specification
- **[MATLAB Integration](docs/openapi_export/README.md)** - MATLAB schema export guide

### Reference
- **[INDEX.md](docs/INDEX.md)** - Documentation index
- **[CHANGELOG.md](docs/CHANGELOG.md)** - Version history
- **[ROADMAP.md](docs/ROADMAP.md)** - Mathematical foundations

## License

See LICENSE file.
