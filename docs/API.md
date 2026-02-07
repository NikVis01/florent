# Florent API Documentation

## Overview

Florent provides a REST API built with [Litestar](https://litestar.dev/) for performing infrastructure project risk analysis. The API accepts firm and project data and returns comprehensive risk assessments.

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

## Endpoints

### Health Check

**GET** `/`

Returns server status.

**Response:**
```
"Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."
```

**Example:**
```bash
curl http://localhost:8000/
```

---

### Analyze Project

**POST** `/analyze`

Performs comprehensive risk analysis on a project for a given firm.

**Request Body** (`AnalysisRequest`):

```json
{
  "firm_data": {
    "id": "firm_123",
    "name": "Example Infrastructure Corp",
    "description": "Leading infrastructure development firm",
    "countries_active": [
      {
        "name": "Germany",
        "a2": "DE",
        "a3": "DEU"
      }
    ],
    "sectors": [
      {
        "name": "Energy",
        "description": "Renewable energy projects"
      }
    ],
    "services": [
      {
        "name": "EPC",
        "description": "Engineering, Procurement, Construction"
      }
    ],
    "strategic_focuses": [
      {
        "name": "Sustainability",
        "description": "Focus on green infrastructure"
      }
    ],
    "preferred_project_timeline": "24-36 months"
  },
  "project_data": {
    "id": "proj_456",
    "name": "Solar Farm Alpha",
    "description": "500MW solar installation",
    "country": {
      "name": "Germany",
      "a2": "DE",
      "a3": "DEU"
    },
    "sector": "Renewable Energy",
    "service_requirements": ["EPC", "O&M"],
    "timeline": "30 months",
    "ops_requirements": [
      {
        "name": "Grid Connection",
        "description": "High-voltage grid integration"
      }
    ],
    "entry_criteria": {
      "min_timeline": "24 months",
      "max_budget": 500000000
    },
    "success_criteria": {
      "target_irr": 0.12,
      "operational_uptime": 0.95
    }
  },
  "budget": 100
}
```

**Alternative: File Paths**

Instead of inline JSON, you can provide file paths:

```json
{
  "firm_path": "examples/firm.json",
  "project_path": "examples/project.json",
  "budget": 100
}
```

**Response** (`AnalysisResponse`):

```json
{
  "status": "success",
  "message": "Analysis complete for Solar Farm Alpha",
  "analysis": {
    "summary": {
      "overall_bankability": 0.78,
      "aggregate_project_score": 0.82,
      "critical_failure_likelihood": 0.15,
      "cooked_zone_percentage": 0.12,
      "nodes_evaluated": 45,
      "total_nodes": 50,
      "total_token_cost": 12500
    },
    "matrix_classifications": {
      "SAFE_WINS": [...],
      "MANAGED_RISKS": [...],
      "BASELINE_UTILITY": [...],
      "COOKED_ZONE": [...]
    },
    "critical_chains": [...],
    "recommendation": {
      "should_bid": true,
      "confidence": 0.85,
      "reasoning": "...",
      "key_risks": [...],
      "key_opportunities": [...]
    }
  }
}
```

**Error Response:**

```json
{
  "status": "error",
  "message": "Error description"
}
```

**Examples:**

```bash
# Using inline JSON data
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d @examples/analysis_request.json

# Using file paths
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "examples/firm.json",
    "project_path": "examples/project.json",
    "budget": 50
  }'
```

---

## Data Models

### Firm

Represents a construction/infrastructure firm.

**Fields:**
- `id` (string): Unique identifier
- `name` (string): Firm name
- `description` (string): Brief description
- `countries_active` (Country[]): Countries where firm operates
- `sectors` (Sectors[]): Industry sectors
- `services` (OperationType[]): Types of services offered
- `strategic_focuses` (StrategicFocus[]): Strategic priorities
- `preferred_project_timeline` (string): Preferred project duration

### Project

Represents an infrastructure project to analyze.

**Fields:**
- `id` (string): Unique identifier
- `name` (string): Project name
- `description` (string): Project description
- `country` (Country): Project location
- `sector` (string): Industry sector
- `service_requirements` (string[]): Required services
- `timeline` (string): Expected duration
- `ops_requirements` (OperationType[]): Operational requirements
- `entry_criteria` (ProjectEntry): Entry conditions
- `success_criteria` (ProjectExit): Success metrics

### AnalysisOutput

Complete risk analysis results.

**Fields:**
- `summary` (SummaryMetrics): Overall metrics
- `matrix_classifications` (dict): Risk quadrant classifications
- `critical_chains` (CriticalChain[]): High-risk paths
- `recommendation` (BidRecommendation): Final recommendation

---

## Interactive Documentation

When the server is running, visit these URLs for interactive API documentation:

- **Swagger UI**: `http://localhost:8000/schema/swagger`
- **ReDoc**: `http://localhost:8000/schema/redoc`
- **OpenAPI JSON**: `http://localhost:8000/schema/openapi.json`

---

## Rate Limiting

Currently, there are no rate limits. For production deployment, consider implementing:
- Request rate limiting per IP
- API key authentication
- Token-based quota management

---

## Authentication

⚠️ **Development Mode**: No authentication is currently required.

For production, implement:
- API key authentication
- JWT tokens
- OAuth 2.0

---

## Error Handling

All errors return JSON with the following structure:

```json
{
  "status": "error",
  "message": "Human-readable error message"
}
```

Common HTTP status codes:
- `200`: Success
- `400`: Bad request (invalid input)
- `404`: Endpoint not found
- `500`: Internal server error

---

## Examples

See the `examples/` directory for sample firm and project JSON files:

```bash
# Test with example data
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "examples/firm.json",
    "project_path": "examples/project.json",
    "budget": 50
  }'
```

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

```bash
# Run API tests
./test_api.sh

# Or with pytest
uv run pytest tests/test_api.py -v
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

### Docker

```bash
# Build image
docker build -t florent-engine .

# Run container
docker run -p 8000:8000 \
  -e OPENAI_API_KEY=your_key_here \
  florent-engine
```

### Production Considerations

1. **Environment Variables**: Set `OPENAI_API_KEY` and other secrets
2. **Reverse Proxy**: Use nginx/traefik in front of the API
3. **HTTPS**: Always use TLS in production
4. **Monitoring**: Add logging, metrics, and health checks
5. **Authentication**: Implement API key or OAuth
6. **Rate Limiting**: Protect against abuse

---

## Support

For issues or questions:
- Check the main [README.md](../README.md)
- Review [PIPELINE_IMPLEMENTATION.md](../PIPELINE_IMPLEMENTATION.md)
- Open an issue on the project repository

---

## License

See [LICENSE](../LICENSE) for details.
