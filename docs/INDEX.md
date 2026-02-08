# Florent Documentation Index

**Project Florent** - Neuro-Symbolic Infrastructure Risk Analysis Engine

**Version**: 1.1.0
**Status**: [OK] Production Ready (264 tests, 100% passing)
**REST API**: [OK] Fully Tested & Operational
**Cross-Encoder**: [OK] BGE-M3 Integration Active
**Last Updated**: 2026-02-08

---

## Quick Links

### Getting Started
- **[README](../README.md)** - Project overview and quickstart
- **[API Documentation](API.md)** - REST API endpoints and usage (19 tests)
- **[Deployment Guide](#docker-deployment)** - How to deploy Florent

### Technical Documentation
- **[Technical Roadmap](ROADMAP.md)** - Mathematical foundations and architecture
- **[OpenAPI Specification](openapi.json)** - Auto-generated API specification

### Integration Guides
- **[MATLAB Setup Guide](../MATLAB/SETUP.md)** - MATLAB frontend integration and setup
- **[MATLAB Functions Reference](../MATLAB/README_FUNCTIONS.md)** - MATLAB API functions
- **[MATLAB App Designer](../MATLAB/Apps/APP_DESIGNER_SETUP.md)** - GUI application setup

---

## Documentation Overview

###  Core Documentation

#### [Technical Roadmap (ROADMAP.md)](ROADMAP.md)
**Status**: Reference document
- Mathematical foundations (3 pillars)
- Agentic architecture with DSPy
- Data structures (Stack, Heap, Linked List)
- Algorithm complexity analysis
- Risk propagation formulas

**When to read**: To understand the mathematical and algorithmic foundations

---

###  API Documentation

#### [API Reference (API.md)](API.md)
**Status**: Current and comprehensive (19 tests passing)
- REST API endpoints (GET /, POST /analyze)
- Request/response schemas
- Data models and validation
- Authentication (development mode)
- Error handling
- cURL examples
- Interactive documentation links (Swagger UI)
- Fully tested and production-ready

**When to read**: When integrating with the Florent API

#### [OpenAPI Specification (openapi.json)](openapi.json)
**Status**: Auto-generated (OpenAPI 3.1)
- Complete API specification
- Generated from Litestar app
- Compatible with Swagger UI
- Client SDK generation ready
- View at: `http://localhost:8000/schema/swagger`

**When to read**: When generating client SDKs or integrating with API tools

---

###  Integration Documentation

#### [MATLAB Integration Suite](../MATLAB/)
**Status**: Complete implementation guide
- **[SETUP.md](../MATLAB/SETUP.md)** - Installation and configuration
- **[README_FUNCTIONS.md](../MATLAB/README_FUNCTIONS.md)** - API function reference
- **[APP_DESIGNER_SETUP.md](../MATLAB/Apps/APP_DESIGNER_SETUP.md)** - GUI development guide
- REST API integration (recommended)
- Python engine integration
- Production deployment examples

**When to read**: When building MATLAB frontend integration

---

## Documentation by Use Case

### I want to...

#### **Deploy Florent**
2. Check [API Documentation](API.md) - Deployment section
3. Set environment variables
4. Run with Docker: `docker-compose up --build`

#### **Integrate with the API**
1. Read [API Reference](API.md)
2. View interactive docs: `http://localhost:8000/schema/swagger`
3. Download [OpenAPI spec](openapi.json)
4. Test with examples: `./test_api.sh`

#### **Generate Client SDKs**
1. Download [OpenAPI Specification](openapi.json)
2. Install OpenAPI Generator: `npm install -g @openapitools/openapi-generator-cli`
3. Generate for your language: `openapi-generator-cli generate -i docs/openapi.json -g python`
4. Available generators: python, typescript-fetch, java, go, rust, and more

#### **Build MATLAB Frontend**
1. Read [MATLAB Setup Guide](../MATLAB/SETUP.md)
2. Review [MATLAB Functions Reference](../MATLAB/README_FUNCTIONS.md)
3. Choose approach (REST API recommended)
4. Follow setup instructions
5. Test connection with provided examples

#### **Understand the Math**
1. Read [Technical Roadmap](ROADMAP.md) - Three Pillars section
2. Review formulas:
   - Influence Score: `I_n = sigmoid(CE) × α^(-d)`
   - Risk Propagation: `R_n = 1 - [(1 - P_local × μ) × ∏(1 - R_parent)]`
   - Priority: `Priority = Influence × Risk`

#### **Extend the System**
1. Review [Technical Roadmap](ROADMAP.md) - Mathematical foundations
2. Check test structure in `tests/` (264 tests as examples)
3. Follow TDD approach with pytest
4. See [Testing Guide](../tests/TESTING_GUIDE.md) for best practices

#### **Debug Issues**
1. Review structured logs (JSON format)
2. Run health check: `curl http://localhost:8000/health`
3. Run validation: `python scripts/validate_data.py`

---

## Architecture Quick Reference

### System Flow
```
Firm.json + Project.json
    ↓
Load & Validate (Pydantic)
    ↓
Build Infrastructure Graph (DAG)
    ↓
Initialize AgentOrchestrator
    ↓
Run Exploration (Priority-Based Traversal)
    ├→ DSPy Agent Evaluation
    ├→ Influence Score Calculation
    ├→ Local Risk Assessment
    └→ Priority Queue Management
    ↓
Propagate Risk (Topological Sort)
    ↓
Generate 2×2 Action Matrix
    ↓
Detect Critical Chains
    ↓
Return AnalysisOutput (JSON)
```

### Core Components
| Component | Location | Purpose |
|-----------|----------|---------|
| Models | `src/models/` | Data structures (Firm, Project, Graph) |
| Orchestrator | `src/services/agent/core/` | Agent coordination & traversal |
| DSPy Signatures | `src/services/agent/models/` | AI agent definitions |
| Math Service | `src/services/math/` | Risk & influence calculations |
| Analysis | `src/services/agent/analysis/` | Matrix classification & chains |
| Pipeline | `src/services/pipeline.py` | End-to-end workflow |
| API | `src/main.py` | Litestar REST endpoints |

---

## Quick Start Guide

### Installation
```bash
# Clone repository
git clone <repository-url>
cd florent

# Install dependencies
uv sync

# Set API key
export OPENAI_API_KEY="sk-your-key-here"

# Run server
uv run litestar run --reload
```

### Test the API
```bash
# Health check
curl http://localhost:8000/

# Run analysis
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "examples/firm.json",
    "project_path": "examples/project.json",
    "budget": 50
  }'
```

### View API Docs
```bash
# Interactive Swagger UI (when server is running)
open http://localhost:8000/schema/swagger

# Or generate and serve OpenAPI docs locally
uv run python scripts/generate_openapi.py -o docs/openapi.json
uv run python scripts/serve_openapi_docs.py --port 8080
open http://localhost:8080

# Download OpenAPI spec directly
curl http://localhost:8000/schema/openapi.json -o openapi.json
```

---

## Test Coverage

**Total Tests**: 264
**Pass Rate**: 100% [OK]

### By Module
- Base Models: 31 tests [OK]
- Entities: 21 tests [OK]
- Graph: 5 tests [OK]
- Traversal: 20 tests [OK]
- Orchestrator: 12 tests [OK]
- Matrix: 16 tests [OK]
- Propagation: 25 tests [OK]
- Chains: 20 tests [OK]
- Pipeline: 6 tests [OK]
- E2E: 16 tests [OK]
- Geo: 20 tests [OK]
- AI Client: 9 tests [OK]
- Settings: 10 tests [OK]
- Signatures: 14 tests [OK]
- Tensor Ops: 20 tests [OK]
- **REST API: 19 tests [OK]** (Health check, POST /analyze endpoint, validation, error handling)

### Run Tests
```bash
# All tests (264 total)
uv run pytest tests/ -v

# Specific module
uv run pytest tests/test_pipeline.py -v

# REST API tests only
uv run pytest tests/test_api.py -v

# With coverage
uv run pytest tests/ --cov=src --cov-report=html
```

---

## Performance Benchmarks

| Project Size | Target | Actual | Status |
|--------------|--------|--------|--------|
| Small (20 nodes) | <5s | <1s | [OK] |
| Medium (50 nodes) | <10s | <2s | [OK] |
| Test Suite | <5min | 2.8s | [OK] |
| Memory Usage | <2GB | <500MB | [OK] |

---

## API Endpoints

### `GET /`
Health check - Returns server status

### `POST /analyze`
Risk analysis - Accepts firm/project data, returns analysis

**Request**:
```json
{
  "firm_path": "examples/firm.json",
  "project_path": "examples/project.json",
  "budget": 100
}
```

**Response**:
```json
{
  "status": "success",
  "message": "Analysis complete",
  "analysis": {
    "summary": { ... },
    "matrix_classifications": { ... },
    "critical_chains": [ ... ],
    "recommendation": { ... }
  }
}
```

**Test Coverage**: 19 comprehensive tests covering all endpoints, request validation, error handling, and response schemas.

See [API.md](API.md) for complete reference.

---

## Development Scripts

### `update.sh` - Full Update
Runs complete maintenance workflow:
1. Export requirements from uv.lock
2. Build and test (264 tests including 19 REST API tests)
3. Lint with ruff
4. **Generate OpenAPI spec** (OpenAPI 3.1)
5. Rebuild Docker image

```bash
./update.sh
```

### `generate_openapi.py` - OpenAPI Generation
Extracts OpenAPI 3.1 spec from Litestar app:
```bash
uv run python scripts/generate_openapi.py -o docs/openapi.json
```

### `serve_openapi_docs.py` - Documentation Server
Serves interactive Swagger UI locally:
```bash
uv run python scripts/serve_openapi_docs.py --port 8080
# Open http://localhost:8080 in browser
```

### `test_api.sh` - API Testing
Tests all REST API endpoints (19 comprehensive tests):
```bash
./test_api.sh
```

### `validate_data.py` - Data Validation
Validates JSON data files:
```bash
python scripts/validate_data.py
```

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | Yes | OpenAI API key for DSPy agents |
| `LOG_LEVEL` | No | Logging level (default: INFO) |
| `HOST` | No | Server host (default: 0.0.0.0) |
| `PORT` | No | Server port (default: 8000) |

---

## Docker Deployment

### Docker Compose
```bash
# Build and start
docker-compose up --build

# Background
docker-compose up -d

# View logs
docker-compose logs -f florent

# Stop
docker-compose down
```

### Standalone Docker
```bash
# Build
docker build -t florent-engine .

# Run
docker run -p 8000:8000 \
  -e OPENAI_API_KEY=sk-your-key \
  florent-engine
```

---

## Troubleshooting

### Server won't start
```bash
# Check dependencies
uv sync

# Check environment
echo $OPENAI_API_KEY

# Check port availability
lsof -i :8000
```

### Tests failing
```bash
# Clean cache
pytest --cache-clear

# Reinstall dependencies
uv sync --reinstall
```

### OpenAPI not generating
```bash
# Run with verbose output
uv run python scripts/generate_openapi.py -o docs/openapi.json

# Check Litestar app
uv run python -c "from src.main import app; print(app)"
```

---

## Production Readiness

### System Status: [OK] Production Ready

**All MVP Features Complete**:
- [OK] 264/264 tests passing (100% coverage)
- [OK] REST API fully tested (19 API tests)
- [OK] OpenAPI 3.1 specification auto-generated
- [OK] Docker deployment configured
- [OK] Comprehensive documentation
- [OK] Error handling & validation
- [OK] Structured logging
- [OK] Performance benchmarks met

**Key Metrics**:
- Test Execution: <3s for full suite
- Memory Usage: <500MB
- API Response: <1s for small projects
- Code Coverage: Core logic 100%

**Deployment Options**:
- Docker Compose (recommended)
- Standalone Docker container
- Direct Python execution (development)

**Integration Ready**:
- REST API with Swagger UI
- MATLAB frontend support
- OpenAPI client generation
- Production logging


---

## Support & Resources

### External Resources
- [Litestar Documentation](https://docs.litestar.dev/)
- [DSPy Documentation](https://dspy-docs.vercel.app/)
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)
- [Pydantic Documentation](https://docs.pydantic.dev/)
---

## License

See [LICENSE](../LICENSE) for details.

---

## Document Index

| Document | Purpose | Status |
|----------|---------|--------|
| [INDEX.md](INDEX.md) | This file - navigation hub | [OK] Current |
| [ROADMAP.md](ROADMAP.md) | Mathematical foundations & algorithms | [OK] Reference |
| [API.md](API.md) | REST API reference (19 tests) | [OK] Production |
| [openapi.json](openapi.json) | OpenAPI 3.1 specification | [OK] Auto-generated |
| [../README.md](../README.md) | Project overview & quickstart | [OK] Current |
| [../MATLAB/SETUP.md](../MATLAB/SETUP.md) | MATLAB integration guide | [OK] Complete |
| [../tests/TESTING_GUIDE.md](../tests/TESTING_GUIDE.md) | Testing best practices | [OK] Reference |

---

**Last Updated**: 2026-02-08
**Production Status**: [OK] Ready (264 tests, 100% passing)
**Next Review**: Quarterly or after major feature additions

