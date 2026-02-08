# Florent API Documentation

## Overview

Florent provides a REST API built with [Litestar](https://litestar.dev/) for performing AI-powered infrastructure project risk analysis. The API accepts firm and project data and returns comprehensive risk assessments including:

- **Firm-contextual dependency graphs** with BGE-M3 cross-encoder weighted edges
- **Node-level risk assessments** for each project operation
- **Strategic action matrix** (2x2 classification: Mitigate, Automate, Contingency, Delegate)
- **Critical dependency chains** that could derail the project
- **Overall project viability score** and detailed recommendations

The system uses:
- **BGE-M3 cross-encoder** for firm-specific edge weighting and gap detection
- **OpenAI GPT models** (via DSPy) for node evaluation and discovery
- **Graph algorithms** for risk propagation and critical chain detection

## Base URL

```
http://localhost:8000
```

## OpenAPI Specification

The complete OpenAPI 3.1.0 specification is automatically generated and available at:
- **JSON**: `docs/openapi.json`
- **Interactive Docs** (when server is running): `http://localhost:8000/schema`

To regenerate the OpenAPI spec:
```bash
python3 scripts/generate_openapi.py
# or
./update.sh
```

## Test Coverage

The system has **238 comprehensive tests** covering:
- REST API endpoints (health check, analysis)
- Cross-encoder client (embeddings, similarity scoring)
- Graph builder (firm-contextual weighting, gap detection, discovery)
- Node evaluation and risk propagation
- Matrix classification and critical chains
- Request validation and error handling
- Integration tests with cross-encoder enabled/disabled

Run tests with:
```bash
./update.sh
# or
uv run pytest tests/ -v
```

## Endpoints

### Health Check

**GET** `/`

Returns server status and confirms the API is operational.

**Response:**
- **Status Code:** `200 OK`
- **Content-Type:** `text/plain`
- **Body:** `"Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."`

**Example:**
```bash
curl http://localhost:8000/

# Response:
# "Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."
```

**Response Details:**
- Simple text string confirming server is running
- No authentication required
- Use this endpoint for health monitoring and uptime checks

---

### Analyze Project

**POST** `/analyze`

Performs comprehensive AI-powered risk analysis on an infrastructure project for a given firm.

**Status Code:** `201 Created`

**Request Body** (`AnalysisRequest`):

The endpoint accepts requests in two formats:

#### Option 1: File Paths (Recommended)

```json
{
  "firm_path": "src/data/poc/firm.json",
  "project_path": "src/data/poc/project.json",
  "budget": 100
}
```

#### Option 2: Inline JSON Data

```json
{
  "firm_data": {
    "id": "firm_001",
    "name": "Nexus Global Infrastructure",
    "description": "A premier infrastructure consultant specializing in renewable energy",
    "countries_active": [
      {
        "name": "Brazil",
        "a2": "BR",
        "a3": "BRA",
        "num": "076",
        "region": "Americas",
        "sub_region": "South America",
        "affiliations": ["BRICS", "G20", "MERCOSUR"]
      }
    ],
    "sectors": [
      {
        "name": "Energy",
        "description": "energy"
      }
    ],
    "services": [
      {
        "name": "Strategic Financing",
        "category": "financing",
        "description": "Provision of capital and credit guarantees"
      }
    ],
    "strategic_focuses": [
      {
        "name": "Green Energy Transition",
        "description": "sustainability"
      }
    ],
    "preferred_project_timeline": 48
  },
  "project_data": {
    "id": "proj_001",
    "name": "Amazonas Smart Grid Phase I",
    "description": "Development of a decentralized renewable energy grid",
    "country": {
      "name": "Brazil",
      "a2": "BR",
      "a3": "BRA",
      "num": "076",
      "region": "Americas",
      "sub_region": "South America",
      "affiliations": ["BRICS", "G20", "MERCOSUR"]
    },
    "sector": "energy",
    "service_requirements": [
      "Environmental Impact Assessment (EIA)",
      "Grid Integrity Verification"
    ],
    "timeline": 36,
    "ops_requirements": [
      {
        "name": "Capital Mobilization",
        "category": "financing",
        "description": "Securing upfront funding for grid hardware"
      },
      {
        "name": "Industrial Equipment Supply",
        "category": "equipment",
        "description": "Sourcing and deploying transformers"
      }
    ],
    "entry_criteria": {
      "pre_requisites": ["Environmental Permit Approved"],
      "mobilization_time": 6,
      "entry_node_id": "node_site_survey"
    },
    "success_criteria": {
      "success_metrics": ["Grid Uptime > 99%"],
      "mandate_end_date": "2029-12-31",
      "exit_node_id": "node_operations_handover"
    }
  },
  "budget": 100
}
```

**Request Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `firm_data` | Object | No* | - | Inline firm data (see Firm schema below) |
| `firm_path` | String | No* | - | Path to firm JSON file |
| `project_data` | Object | No* | - | Inline project data (see Project schema below) |
| `project_path` | String | No* | - | Path to project JSON file |
| `budget` | Integer | No | 100 | Number of AI evaluation calls (controls analysis depth) |

*Note: Must provide either `firm_data` OR `firm_path` (same for project)

**Success Response:**

```json
{
  "status": "success",
  "message": "Analysis complete for Amazonas Smart Grid Phase I",
  "analysis": {
    "node_assessments": {
      "node_site_survey": {
        "influence": 0.85,
        "risk": 0.35,
        "reasoning": "Critical entry point, moderate environmental assessment risks"
      },
      "node_financing_0": {
        "influence": 0.92,
        "risk": 0.45,
        "reasoning": "High influence on project viability, moderate financing risks"
      },
      "node_equipment_1": {
        "influence": 0.78,
        "risk": 0.52,
        "reasoning": "Supply chain vulnerabilities, critical equipment dependencies"
      },
      "node_operations_handover": {
        "influence": 0.70,
        "risk": 0.30,
        "reasoning": "Final milestone, lower risk due to completed dependencies"
      }
    },
    "action_matrix": {
      "mitigate": ["node_financing_0"],
      "automate": ["node_site_survey"],
      "contingency": [],
      "delegate": ["node_operations_handover"]
    },
    "critical_chains": [
      {
        "chain_id": "chain_node_site_survey_to_node_operations_handover",
        "nodes": [
          "node_site_survey",
          "node_financing_0",
          "node_equipment_1",
          "node_operations_handover"
        ],
        "aggregate_risk": 0.655,
        "impact_description": "Critical path from Site Survey to Operations Handover"
      }
    ],
    "summary": {
      "firm_id": "firm_001",
      "project_id": "proj_001",
      "nodes_analyzed": 4,
      "budget_used": 4,
      "overall_bankability": 0.625,
      "average_risk": 0.375,
      "maximum_risk": 0.520,
      "critical_chains_detected": 1,
      "high_risk_nodes": 1,
      "recommendations": [
        "Project is moderately bankable - implement risk controls",
        "Prioritize mitigation for 1 high-risk, high-influence nodes",
        "Monitor 1 critical dependency chain(s) closely - single points of failure"
      ]
    }
  }
}
```

**Error Response:**

```json
{
  "status": "error",
  "message": "File not found: /nonexistent/firm.json"
}
```

**Common Error Messages:**
- `"File not found: <path>"` - Specified file path does not exist
- `"Missing data or path"` - Neither data nor path provided for firm/project
- `"'<field>' KeyError"` - Required field missing in firm/project data
- Validation errors for malformed JSON structures

**Examples:**

```bash
# Using file paths (POC data)
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "src/data/poc/firm.json",
    "project_path": "src/data/poc/project.json",
    "budget": 100
  }'

# Using inline JSON data
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d @request_payload.json

# With custom budget
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "src/data/poc/firm.json",
    "project_path": "src/data/poc/project.json",
    "budget": 250
  }'

# Default budget (100) - budget parameter omitted
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "src/data/poc/firm.json",
    "project_path": "src/data/poc/project.json"
  }'
```

---

## Data Models

### Firm

Represents a construction/infrastructure firm with capabilities and strategic context.

**Fields:**
- `id` (string, required): Unique identifier (e.g., "firm_001")
- `name` (string, required): Firm name
- `description` (string, required): Brief description of the firm's focus
- `countries_active` (Country[], required): Countries where firm operates
  - `name` (string): Country name
  - `a2` (string): ISO 3166-1 alpha-2 code
  - `a3` (string): ISO 3166-1 alpha-3 code
  - `num` (string, optional): ISO numeric code
  - `region` (string, optional): Geographic region
  - `sub_region` (string, optional): Sub-region
  - `affiliations` (string[], optional): Trade blocs/organizations
- `sectors` (Sectors[], required): Industry sectors
  - `name` (string): Sector name
  - `description` (string): Sector identifier (e.g., "energy", "construction")
- `services` (OperationType[], required): Services offered by the firm
  - `name` (string): Service name
  - `category` (string): Category (e.g., "financing", "equipment", "assessment")
  - `description` (string): Service description
- `strategic_focuses` (StrategicFocus[], required): Strategic priorities
  - `name` (string): Focus area name
  - `description` (string): Focus identifier (e.g., "sustainability", "efficiency")
- `preferred_project_timeline` (integer, required): Preferred project duration in months

### Project

Represents an infrastructure project to analyze.

**Fields:**
- `id` (string, required): Unique identifier (e.g., "proj_001")
- `name` (string, required): Project name
- `description` (string, required): Project description
- `country` (Country, required): Project location (same structure as Firm.countries_active)
- `sector` (string, required): Industry sector (e.g., "energy", "construction")
- `service_requirements` (string[], required): Required services for the project
- `timeline` (integer, required): Expected duration in months
- `ops_requirements` (OperationType[], required): Operational requirements/phases
  - `name` (string): Operation name
  - `category` (string): Category (e.g., "financing", "equipment")
  - `description` (string): Operation description
- `entry_criteria` (ProjectEntry, required): Entry conditions
  - `pre_requisites` (string[]): Prerequisites for project entry
  - `mobilization_time` (integer): Time to mobilize in months
  - `entry_node_id` (string): ID of the entry node in the graph
- `success_criteria` (ProjectExit, required): Success metrics
  - `success_metrics` (string[]): Metrics defining project success
  - `mandate_end_date` (string): Expected completion date (ISO 8601)
  - `exit_node_id` (string): ID of the exit node in the graph

### AnalysisOutput

Complete risk analysis results returned by the `/analyze` endpoint.

**Top-Level Fields:**
- `status` (string): "success" or "error"
- `message` (string): Human-readable status message
- `analysis` (object): Analysis results (present on success)

**Analysis Object Fields:**

#### node_assessments
Map of node IDs to assessment data. Each assessment contains:
- `influence` (float, 0.0-1.0): Node's influence on project success
- `risk` (float, 0.0-1.0): Node's risk level
- `reasoning` (string): AI-generated explanation of the assessment

#### action_matrix
Strategic classification of nodes into four quadrants:
- `mitigate` (string[]): High risk, high influence - prioritize immediate action
- `automate` (string[]): Low risk, high influence - optimize and standardize
- `contingency` (string[]): High risk, low influence - prepare backup plans
- `delegate` (string[]): Low risk, low influence - routine operations

**Classification Rules:**
- **Mitigate**: risk > 0.7 AND influence > 0.7
- **Automate**: risk ≤ 0.7 AND influence > 0.7
- **Contingency**: risk > 0.7 AND influence ≤ 0.7
- **Delegate**: risk ≤ 0.7 AND influence ≤ 0.7

#### critical_chains
Array of high-risk dependency chains. Each chain contains:
- `chain_id` (string): Unique chain identifier
- `nodes` (string[]): Ordered list of node IDs in the chain
- `aggregate_risk` (float): Average risk across the chain
- `impact_description` (string): Description of the chain's significance

#### summary
Overall project metrics:
- `firm_id` (string): Firm identifier
- `project_id` (string): Project identifier
- `nodes_analyzed` (integer): Number of nodes evaluated
- `budget_used` (integer): Number of AI evaluations performed
- `overall_bankability` (float, 0.0-1.0): Overall project bankability (1.0 - avg_risk)
- `average_risk` (float, 0.0-1.0): Average propagated risk across all nodes
- `maximum_risk` (float, 0.0-1.0): Highest propagated risk in the project
- `critical_chains_detected` (integer): Number of critical chains found
- `high_risk_nodes` (integer): Count of nodes requiring mitigation or contingency
- `recommendations` (string[]): Strategic recommendations based on analysis

---

## Interactive Documentation

When the server is running, visit these URLs for interactive API documentation:

- **OpenAPI Schema**: `http://localhost:8000/schema` - Interactive schema explorer
- **Swagger UI**: `http://localhost:8000/schema/swagger` - Try API endpoints directly in browser
- **ReDoc**: `http://localhost:8000/schema/redoc` - Clean, responsive API documentation
- **OpenAPI JSON**: `http://localhost:8000/schema/openapi.json` - Raw OpenAPI 3.1.0 specification

### Using Swagger UI

1. Start the server: `./run.sh` or `uv run litestar run`
2. Open browser to `http://localhost:8000/schema/swagger`
3. Expand the `/analyze` endpoint
4. Click "Try it out"
5. Enter request body JSON
6. Click "Execute" to see live results

### Using ReDoc

ReDoc provides a clean, three-panel documentation interface:
- Left panel: Navigation and endpoint list
- Center panel: Detailed endpoint documentation
- Right panel: Example requests and responses

Access at `http://localhost:8000/schema/redoc`

---

## API Version & Compatibility

**Current Version:** 1.0.0

**Framework:** Litestar (OpenAPI 3.1.0 compliant)

### Breaking Changes Policy
- Major version changes (e.g., 1.x → 2.x) may include breaking changes
- Minor version changes (e.g., 1.0 → 1.1) are backward compatible
- Patch versions (e.g., 1.0.0 → 1.0.1) are for bug fixes only

### Deprecation Notice
Currently, no endpoints are deprecated. Future deprecations will be announced with:
- 3-month advance notice
- Deprecation headers in responses
- Migration guide in documentation

---

## Rate Limiting

**Current Status:** No rate limiting implemented

**Production Recommendations:**
```nginx
# Example nginx rate limiting
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
limit_req zone=api_limit burst=20 nodelay;
```

**Suggested Limits:**
- **Per IP**: 10 requests/second, burst of 20
- **Per API Key**: 100 requests/hour (after implementing authentication)
- **Budget Cap**: Maximum 500 per request (to control OpenAI costs)

**Implementation Options:**
1. **Application Level**: Use Litestar middleware or Python libraries (slowapi, flask-limiter)
2. **Reverse Proxy**: nginx, Traefik rate limiting
3. **API Gateway**: AWS API Gateway, Kong, Tyk
4. **Cloud Services**: Cloudflare rate limiting

---

## Authentication

[WARNING] **Development Mode**: No authentication currently required

**Security Warning:** The API is currently open and should only be deployed in trusted environments.

### Production Authentication Options

#### 1. API Key Authentication (Recommended for MVP)
```bash
# Request with API key
curl -X POST http://localhost:8000/analyze \
  -H "X-API-Key: your_api_key_here" \
  -H "Content-Type: application/json" \
  -d '{"firm_path": "...", "project_path": "..."}'
```

**Implementation:**
- Add Litestar middleware to validate `X-API-Key` header
- Store hashed API keys in database or environment
- Return 401 Unauthorized for missing/invalid keys

#### 2. JWT Tokens (For User-Based Access)
```bash
# Login to get token
curl -X POST http://localhost:8000/auth/login \
  -d '{"username": "user", "password": "pass"}'

# Use token for requests
curl -X POST http://localhost:8000/analyze \
  -H "Authorization: Bearer eyJhbGc..." \
  -d '{"firm_path": "...", "project_path": "..."}'
```

#### 3. OAuth 2.0 (For Enterprise)
- Integrate with identity providers (Okta, Auth0, Azure AD)
- Support organization-level access control
- Enable SSO for enterprise customers

### Implementing Authentication

Add to `src/main.py`:
```python
from litestar.middleware import DefineMiddleware

def verify_api_key(request):
    api_key = request.headers.get("X-API-Key")
    if api_key != os.getenv("VALID_API_KEY"):
        raise HTTPException(status_code=401, detail="Invalid API key")

app = Litestar(
    route_handlers=[health_check, analyze_project],
    middleware=[DefineMiddleware(verify_api_key)]
)
```

---

## Error Handling

### Error Response Format

All errors return JSON with the following structure:

```json
{
  "status": "error",
  "message": "Human-readable error message"
}
```

**Important:** The `/analyze` endpoint always returns HTTP status `201 Created`, even for errors. Check the `status` field in the response body to determine success or failure.

### Common HTTP Status Codes
- `200 OK`: Health check successful
- `201 Created`: Analysis request processed (check `status` field for actual result)
- `400 Bad Request`: Invalid request format (Litestar validation errors)
- `404 Not Found`: Endpoint does not exist
- `500 Internal Server Error`: Unexpected server error

### Common Error Scenarios

#### File Not Found
```json
{
  "status": "error",
  "message": "File not found: /path/to/nonexistent/file.json"
}
```
**Cause:** Specified `firm_path` or `project_path` does not exist on the server filesystem.

#### Missing Data
```json
{
  "status": "error",
  "message": "Missing data or path"
}
```
**Cause:** Neither inline data nor file path provided for firm or project.

#### Invalid JSON Structure
```json
{
  "status": "error",
  "message": "'countries_active' KeyError"
}
```
**Cause:** Required field missing from firm or project data.

#### Malformed Request
```json
{
  "status": "error",
  "message": "Project proj_001 has no ops_requirements"
}
```
**Cause:** Project data is missing required `ops_requirements` array.

#### AI Service Errors
```json
{
  "status": "error",
  "message": "OpenAI API error: Rate limit exceeded"
}
```
**Cause:** Issues communicating with OpenAI API (rate limits, authentication, etc.).

---

## Complete Working Examples

### Example 1: Using POC Data with File Paths

The repository includes proof-of-concept data files that you can use immediately:

```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "src/data/poc/firm.json",
    "project_path": "src/data/poc/project.json",
    "budget": 100
  }'
```

**Expected Response:**
```json
{
  "status": "success",
  "message": "Analysis complete for Amazonas Smart Grid Phase I",
  "analysis": {
    "node_assessments": {
      "node_site_survey": {
        "influence": 0.85,
        "risk": 0.35,
        "reasoning": "Critical entry point with moderate environmental risks"
      },
      "node_financing_0": {
        "influence": 0.92,
        "risk": 0.45,
        "reasoning": "High influence on viability, moderate financing risks"
      }
    },
    "action_matrix": {
      "mitigate": ["node_financing_0"],
      "automate": ["node_site_survey"],
      "contingency": [],
      "delegate": ["node_operations_handover"]
    },
    "critical_chains": [
      {
        "chain_id": "chain_node_site_survey_to_node_operations_handover",
        "nodes": ["node_site_survey", "node_financing_0", "node_equipment_1", "node_operations_handover"],
        "aggregate_risk": 0.655
      }
    ],
    "summary": {
      "overall_bankability": 0.625,
      "average_risk": 0.375,
      "nodes_analyzed": 4,
      "recommendations": [
        "Project is moderately bankable - implement risk controls",
        "Prioritize mitigation for 1 high-risk, high-influence nodes"
      ]
    }
  }
}
```

### Example 2: Using Python Requests

```python
import requests
import json

url = "http://localhost:8000/analyze"

# Request payload
payload = {
    "firm_path": "src/data/poc/firm.json",
    "project_path": "src/data/poc/project.json",
    "budget": 100
}

# Make request
response = requests.post(url, json=payload)

# Parse response
result = response.json()

if result["status"] == "success":
    analysis = result["analysis"]
    print(f"Bankability: {analysis['summary']['overall_bankability']}")
    print(f"Average Risk: {analysis['summary']['average_risk']}")
    print(f"Recommendations: {analysis['summary']['recommendations']}")
else:
    print(f"Error: {result['message']}")
```

### Example 3: Custom Budget

Adjust the `budget` parameter to control analysis depth:

```bash
# Lower budget (faster, less comprehensive)
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "src/data/poc/firm.json",
    "project_path": "src/data/poc/project.json",
    "budget": 50
  }'

# Higher budget (slower, more thorough)
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "src/data/poc/firm.json",
    "project_path": "src/data/poc/project.json",
    "budget": 200
  }'
```

### Example 4: Handling Errors

```bash
# Invalid file path
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "/nonexistent/firm.json",
    "project_path": "src/data/poc/project.json"
  }'

# Response:
# {
#   "status": "error",
#   "message": "File not found: /nonexistent/firm.json"
# }
```

---

## How the Analysis Works

The `/analyze` endpoint orchestrates a sophisticated multi-stage pipeline:

### Pipeline Stages

1. **Graph Construction**
   - Builds a directed acyclic graph (DAG) from project operations
   - Creates nodes for entry, operational phases, and exit criteria
   - Establishes dependency relationships between phases

2. **AI Evaluation**
   - Uses OpenAI GPT models via DSPy to assess each node
   - Evaluates influence score (impact on project success)
   - Evaluates risk level (likelihood of failure/issues)
   - Generates reasoning for each assessment

3. **Risk Propagation**
   - Propagates risk through dependency chains
   - Compounds upstream risks with local risks
   - Identifies how failures cascade through the project

4. **Matrix Classification**
   - Classifies nodes into 2x2 strategic matrix
   - **Mitigate** (high risk, high influence): Immediate action required
   - **Automate** (low risk, high influence): Optimize and standardize
   - **Contingency** (high risk, low influence): Prepare backup plans
   - **Delegate** (low risk, low influence): Routine operations

5. **Critical Chain Detection**
   - Identifies dependency chains with aggregate risk > 0.6
   - Highlights single points of failure
   - Provides path-level risk analysis

6. **Summary Generation**
   - Calculates overall bankability score
   - Generates strategic recommendations
   - Provides actionable insights

### Budget Parameter

The `budget` parameter controls the number of AI evaluation calls:
- **Lower budget (50-100)**: Faster analysis, uses fallback values for some nodes
- **Higher budget (200+)**: More comprehensive, evaluates more nodes with AI
- **Default (100)**: Balanced approach for most use cases

### Performance Considerations

- Analysis time scales with number of nodes and budget
- Typical analysis: 10-60 seconds depending on complexity
- AI calls are the primary performance bottleneck
- Consider caching for repeated analyses

---

## Development

### Running the Server

```bash
# Install dependencies
uv sync

# Run with uvicorn
uv run litestar run --host 0.0.0.0 --port 8000 --reload

# Or use the run script
./run.sh
```

### Testing the API

The project includes **19 comprehensive REST API tests** covering all endpoints and scenarios:

**Test Coverage:**
1. Health check endpoint (2 tests)
2. Analysis with file paths (5 tests)
3. Analysis with JSON data (2 tests)
4. Request validation (4 tests)
5. Response structure verification (2 tests)
6. Logging functionality (2 tests)
7. Integration testing (1 test)
8. Edge cases: zero/negative/large budgets (3 tests)

**Run All Tests:**
```bash
# Using test script
./test_api.sh

# Using pytest directly
uv run pytest tests/test_api.py -v

# Run specific test class
uv run pytest tests/test_api.py::TestHealthCheckEndpoint -v

# Run with coverage report
uv run pytest tests/test_api.py --cov=src/main --cov-report=term-missing
```

**Test Example Output:**
```
test_api.py::TestHealthCheckEndpoint::test_health_check_returns_200 PASSED
test_api.py::TestHealthCheckEndpoint::test_health_check_message PASSED
test_api.py::TestAnalyzeEndpointWithFilePaths::test_analyze_with_file_paths_success PASSED
test_api.py::TestAnalyzeEndpointWithFilePaths::test_analyze_with_invalid_firm_path PASSED
...
==================== 19 passed in 3.45s ====================
```

### Regenerating OpenAPI Spec

```bash
# Manual generation
python3 scripts/generate_openapi.py

# As part of update process
./update.sh
```

---

## Deployment

### Docker Deployment

Build and run using Docker:

```bash
# Build the image
docker build -t florent-engine .

# Run container with environment variables
docker run -p 8000:8000 \
  -e OPENAI_API_KEY=your_openai_api_key \
  -e OPENAI_MODEL=gpt-4 \
  florent-engine

# Run with custom port
docker run -p 3000:8000 \
  -e OPENAI_API_KEY=your_openai_api_key \
  florent-engine

# Run in detached mode
docker run -d -p 8000:8000 \
  --name florent-api \
  -e OPENAI_API_KEY=your_openai_api_key \
  florent-engine

# View logs
docker logs -f florent-api
```

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | Yes | - | OpenAI API key for GPT model access |
| `OPENAI_MODEL` | No | `gpt-4o-mini` | OpenAI model to use (e.g., gpt-4, gpt-4-turbo) |
| `LOG_LEVEL` | No | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `PORT` | No | `8000` | Port for the API server |

### Production Considerations

#### 1. Security
- **Authentication**: The API currently has no authentication. Implement API keys, JWT tokens, or OAuth 2.0 for production
- **HTTPS**: Always use TLS/SSL in production. Use a reverse proxy (nginx, Traefik) to handle certificates
- **Secrets Management**: Store `OPENAI_API_KEY` securely (AWS Secrets Manager, HashiCorp Vault, etc.)
- **CORS**: Configure CORS policies appropriately for your frontend

#### 2. Rate Limiting & Quotas
- Implement rate limiting per IP or API key
- Set budget limits to control OpenAI API costs
- Consider request queuing for high-traffic scenarios
- Monitor OpenAI API quota and costs

#### 3. Monitoring & Observability
- **Structured Logging**: The API uses structured JSON logging (see logs)
- **Metrics**: Consider adding Prometheus metrics for request rates, latencies, error rates
- **Health Checks**: Use `GET /` endpoint for uptime monitoring
- **APM**: Integrate with Application Performance Monitoring tools (DataDog, New Relic, etc.)

#### 4. Scalability
- **Horizontal Scaling**: API is stateless and can be horizontally scaled
- **Load Balancing**: Use nginx, AWS ELB, or similar for load distribution
- **Caching**: Consider caching analysis results for identical requests
- **Database**: For production, add persistent storage for analysis history

#### 5. Performance Optimization
- **AI Model Selection**: Use `gpt-4o-mini` for faster/cheaper analysis, `gpt-4` for higher quality
- **Budget Tuning**: Adjust default budget based on your performance/accuracy needs
- **Async Processing**: Consider background job queues for long-running analyses
- **Connection Pooling**: Optimize OpenAI API connection pooling

#### 6. Reliability
- **Error Handling**: Comprehensive error handling is implemented
- **Retry Logic**: Add retry logic for transient OpenAI API failures
- **Circuit Breakers**: Implement circuit breakers for external service calls
- **Graceful Degradation**: Handle API failures gracefully (fallback values, cached results)

### Example Production Setup (nginx + Docker)

```nginx
# nginx.conf
upstream florent_api {
    server localhost:8000;
    server localhost:8001;
    server localhost:8002;
}

server {
    listen 443 ssl http2;
    server_name api.florent.example.com;

    ssl_certificate /etc/ssl/certs/florent.crt;
    ssl_certificate_key /etc/ssl/private/florent.key;

    location / {
        proxy_pass http://florent_api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Rate limiting
        limit_req zone=api_limit burst=10 nodelay;
    }

    location /health {
        proxy_pass http://florent_api/;
        access_log off;
    }
}

# Rate limit zone
limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
```

### Cloud Deployment Examples

**AWS (ECS/Fargate):**
```bash
# Push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account>.dkr.ecr.us-east-1.amazonaws.com
docker tag florent-engine:latest <account>.dkr.ecr.us-east-1.amazonaws.com/florent-engine:latest
docker push <account>.dkr.ecr.us-east-1.amazonaws.com/florent-engine:latest

# Deploy to ECS (use AWS Console or Terraform)
```

**Google Cloud (Cloud Run):**
```bash
# Build and deploy
gcloud builds submit --tag gcr.io/PROJECT_ID/florent-engine
gcloud run deploy florent-api \
  --image gcr.io/PROJECT_ID/florent-engine \
  --platform managed \
  --set-env-vars OPENAI_API_KEY=your_key
```

**DigitalOcean (App Platform):**
- Connect your repository
- Configure environment variables in the dashboard
- Deploy with automatic HTTPS and load balancing

---

## Interpreting Analysis Results

### Bankability Score

The `overall_bankability` score (0.0 to 1.0) indicates project viability:

| Score Range | Interpretation | Recommendation |
|-------------|---------------|----------------|
| 0.8 - 1.0 | **Highly Bankable** | Strong project - proceed with confidence |
| 0.6 - 0.79 | **Moderately Bankable** | Viable with risk controls - implement recommendations |
| 0.4 - 0.59 | **Marginal** | Significant concerns - restructure or enhance mitigation |
| 0.0 - 0.39 | **High Risk** | Consider declining or major project redesign |

### Action Matrix Interpretation

**Mitigate Quadrant** (High Risk, High Influence)
- These nodes pose the greatest threat to project success
- Require immediate attention and active risk mitigation
- Example: Critical financing dependencies, key regulatory approvals
- Action: Develop detailed risk mitigation plans, allocate senior resources

**Automate Quadrant** (Low Risk, High Influence)
- High-impact operations that are well-understood and stable
- Opportunities for optimization and efficiency gains
- Example: Standard site surveys, routine equipment procurement
- Action: Standardize processes, implement automation, create templates

**Contingency Quadrant** (High Risk, Low Influence)
- Risky but lower-impact operations
- Need backup plans but don't warrant primary focus
- Example: Secondary supplier relationships, optional approvals
- Action: Develop contingency plans, identify alternatives

**Delegate Quadrant** (Low Risk, Low Influence)
- Routine, low-stakes operations
- Can be delegated to junior teams or standard procedures
- Example: Administrative tasks, routine handovers
- Action: Delegate to appropriate teams, use standard procedures

### Critical Chains

A critical chain represents a sequential dependency path with high aggregate risk (>0.6):

- **Single Point of Failure**: If any node in the chain fails, the entire project is jeopardized
- **Risk Compounding**: Risks accumulate along the chain
- **Monitor Closely**: These chains require continuous monitoring and proactive management

**Example Interpretation:**
```json
{
  "chain_id": "chain_node_site_survey_to_node_operations_handover",
  "nodes": ["node_site_survey", "node_financing_0", "node_equipment_1", "node_operations_handover"],
  "aggregate_risk": 0.655
}
```
This indicates a critical path from project start to finish with elevated risk (65.5%). Each node depends on the previous one, creating a vulnerability chain.

### Recommendations

The `recommendations` array provides actionable insights:

```json
"recommendations": [
  "Project is moderately bankable - implement risk controls",
  "Prioritize mitigation for 1 high-risk, high-influence nodes",
  "Monitor 1 critical dependency chain(s) closely - single points of failure"
]
```

Act on these in priority order:
1. Address high-risk nodes first
2. Monitor critical chains continuously
3. Implement suggested risk controls
4. Optimize automation opportunities

---

## Best Practices

### 1. Budget Selection
- **Initial Assessment (50-100)**: Quick evaluation for go/no-go decisions
- **Detailed Analysis (100-200)**: Comprehensive evaluation for bid preparation
- **Full Evaluation (200+)**: Deep analysis for major projects or due diligence

### 2. Iterative Analysis
- Run multiple analyses as project details evolve
- Compare bankability scores across project iterations
- Track how changes affect critical chains and risk distribution

### 3. Data Quality
- Ensure complete and accurate firm/project data
- Include all relevant `ops_requirements` for comprehensive graph
- Provide detailed descriptions to improve AI assessment quality

### 4. Complementary Use
- Combine with traditional risk assessment methods
- Use as a decision support tool, not sole decision maker
- Validate AI reasoning with domain expertise

### 5. Cost Management
- Monitor OpenAI API usage (logged as `budget_used`)
- Use appropriate budget values for analysis depth needed
- Consider caching results for repeated analyses

### 6. Security
- Never commit API keys to version control
- Use environment variables for sensitive configuration
- Implement authentication for production deployments
- Rotate API keys regularly

### 7. Error Handling
- Always check `status` field before processing `analysis`
- Implement retry logic for transient failures
- Log errors for debugging and monitoring
- Provide meaningful error messages to users

---

## Troubleshooting

### Common Issues

**Problem: "File not found" error**
```
Solution: Ensure file paths are absolute or relative to the server's working directory.
The server runs from the project root, so use: "src/data/poc/firm.json" not "./firm.json"
```

**Problem: OpenAI API errors**
```
Solution:
1. Verify OPENAI_API_KEY environment variable is set
2. Check OpenAI API status and quota limits
3. Ensure API key has sufficient credits
4. Try reducing budget to use fewer API calls
```

**Problem: Analysis taking too long**
```
Solution:
1. Reduce budget parameter (try 50 instead of 200)
2. Use faster OpenAI model (gpt-4o-mini instead of gpt-4)
3. Simplify project structure (fewer ops_requirements)
4. Check network latency to OpenAI API
```

**Problem: Unexpected bankability scores**
```
Solution:
1. Review node assessments and reasoning fields
2. Verify project data accuracy and completeness
3. Check that ops_requirements match project complexity
4. Consider running multiple analyses and averaging results
```

**Problem: Empty or missing analysis data**
```
Solution:
1. Ensure project has ops_requirements array with at least one item
2. Verify entry_criteria and success_criteria are present
3. Check server logs for detailed error messages
4. Validate JSON structure matches schema
```

### Debug Mode

Enable detailed logging:
```bash
# Set log level to DEBUG
export LOG_LEVEL=DEBUG
uv run litestar run --reload

# Or in Docker
docker run -p 8000:8000 \
  -e OPENAI_API_KEY=your_key \
  -e LOG_LEVEL=DEBUG \
  florent-engine
```

### Getting Help

1. Check server logs for detailed error messages
2. Review test cases in `tests/test_api.py` for usage examples
3. Examine POC data in `src/data/poc/` for reference format
4. Review [PIPELINE_IMPLEMENTATION.md](PIPELINE_IMPLEMENTATION.md) for technical details

---

## API Changelog

### Version 1.0.0 (Current)
**Released:** 2025-01-XX

**Features:**
- Initial REST API release with Litestar framework
- Two endpoints: `GET /` (health check) and `POST /analyze` (risk analysis)
- Support for both file paths and inline JSON data
- Configurable budget parameter for AI evaluation depth
- Comprehensive error handling and structured logging
- OpenAPI 3.1.0 specification with Swagger/ReDoc documentation
- 19 automated test cases with full coverage

**Technical Stack:**
- Framework: Litestar (FastAPI-like with OpenAPI support)
- AI Engine: OpenAI GPT models via DSPy
- Graph Engine: Custom DAG implementation
- Logging: Structured JSON logging

---

## Support

### Documentation Resources
- **Main README**: [README.md](../README.md) - Project overview and setup
- **Pipeline Details**: [PIPELINE_IMPLEMENTATION.md](PIPELINE_IMPLEMENTATION.md) - Technical architecture
- **Data Models**: Check `src/models/entities.py` for complete schemas
- **Test Examples**: Review `tests/test_api.py` for usage patterns

### Getting Help

**For API Issues:**
1. Check this documentation for endpoint details
2. Review error messages in response `message` field
3. Enable DEBUG logging to see detailed execution flow
4. Run test suite to verify installation: `./test_api.sh`

**For Analysis Questions:**
1. Review "Interpreting Analysis Results" section above
2. Examine POC data examples in `src/data/poc/`
3. Check node assessment `reasoning` fields for AI explanations

**For Development:**
1. Review test cases for examples: `tests/test_api.py`
2. Check OpenAPI spec: `docs/openapi.json`
3. Use interactive docs: `http://localhost:8000/schema/swagger`

**For Bugs or Feature Requests:**
- Open an issue on the project repository
- Include API request/response examples
- Provide server logs if applicable
- Specify environment (Docker, local, cloud)

### Community & Contributing

This is an open-source project. Contributions are welcome:
- Report bugs and request features via issues
- Submit pull requests for improvements
- Share feedback on API design and usability
- Contribute test cases and documentation

---

## Quick Reference Card

### Endpoints Summary
| Method | Endpoint | Purpose | Auth Required |
|--------|----------|---------|---------------|
| GET | `/` | Health check | No |
| POST | `/analyze` | Risk analysis | No (dev mode) |

### Key Response Fields
| Field | Type | Description |
|-------|------|-------------|
| `status` | string | "success" or "error" |
| `analysis.summary.overall_bankability` | float | 0.0-1.0, higher is better |
| `analysis.action_matrix.mitigate` | array | High-priority risk nodes |
| `analysis.critical_chains` | array | Vulnerable dependency paths |
| `analysis.summary.recommendations` | array | Actionable insights |

### Common Request Patterns
```bash
# Basic analysis
POST /analyze {"firm_path": "...", "project_path": "...", "budget": 100}

# Quick assessment
POST /analyze {"firm_path": "...", "project_path": "...", "budget": 50}

# Detailed analysis
POST /analyze {"firm_path": "...", "project_path": "...", "budget": 200}
```

### HTTP Status Codes
- `200` - Health check success
- `201` - Analysis request processed (check `status` field)
- `400` - Invalid request format
- `404` - Endpoint not found
- `500` - Server error

---

## License

See [LICENSE](../LICENSE) for details.

**License Summary:** Go F*ck Yourself License (GFYL) - Non-commercial use only.

---

*Last Updated: 2026-02-07*
*API Version: 1.0.0*
*Documentation Version: 1.0.0*
