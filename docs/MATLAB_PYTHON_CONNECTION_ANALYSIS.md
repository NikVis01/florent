# MATLAB->Python Connection Analysis: Data Structures & Request Formats

**Generated:** 2026-02-08
**Updated:** 2026-02-08 (Python fixes completed)
**Project:** Florent Risk Assessment System
**Scope:** Analysis of data flow between MATLAB client and Python API server

---

## 🎉 UPDATE: Python/API Fixes Completed

**All Python-side and API-side issues have been fixed!** See `PYTHON_API_FIXES_SUMMARY.md` for details.

**Remaining work:** MATLAB-side updates only (see Section 15 below)

---

## Executive Summary

This document provides a comprehensive analysis of the MATLAB->Python connection in the Florent system, identifying potential misunderstandings and mismatches in data structures, request formats, and response parsing. The analysis covers the full data flow from MATLAB request construction through Python API processing and back to MATLAB response parsing.

### Key Findings (UPDATED):

1. **Field Naming Inconsistencies** - Mix of snake_case (Python) and camelCase (MATLAB)
2. **JSON Serialization Issues** - MATLAB struct to JSON conversion edge cases
3. **Array vs Cell Array Confusion** - JSON arrays become different MATLAB types
4. **Enum String Format Mismatches** - RiskQuadrant enum values have inconsistent formats
5. **Optional Field Handling** - Missing null/empty field handling in some parsers
6. **oneOf/anyOf Schema Complexity** - MATLAB struggles with JSON Schema union types
7. **Nested Object Depth** - Deep nesting causes parsing complexity
8. **Matrix/Array Structure** - Adjacency matrix format inconsistencies

---

## 1. Architecture Overview

### 1.1 Component Stack

```
┌─────────────────────────────────────────────┐
│         MATLAB Client Layer                  │
│  ┌──────────────────────────────────────┐   │
│  │ FlorentAPIClientWrapper.m            │   │
│  │  - HTTP Client Manager               │   │
│  │  - Retry Logic                       │   │
│  │  - Error Handling                    │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ buildAnalysisRequest.m               │   │
│  │  - Request Construction              │   │
│  │  - Path Resolution                   │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ callPythonAPI.m                      │   │
│  │  - webread/webwrite wrapper          │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                     ↕ HTTP/JSON
┌─────────────────────────────────────────────┐
│         Python API Server (Litestar)         │
│  ┌──────────────────────────────────────┐   │
│  │ main.py - /analyze endpoint          │   │
│  │  - AnalysisRequest (Pydantic)        │   │
│  │  - Request Validation                │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ orchestrator_v2.py                   │   │
│  │  - RiskOrchestrator                  │   │
│  │  - Node Evaluation                   │   │
│  │  - Chain Detection                   │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ enhanced_output_builder.py           │   │
│  │  - Graph Topology                    │   │
│  │  - Risk Distributions                │   │
│  │  - Monte Carlo Parameters            │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
                     ↕ HTTP/JSON
┌─────────────────────────────────────────────┐
│         MATLAB Response Processing           │
│  ┌──────────────────────────────────────┐   │
│  │ parseAnalysisResponse.m              │   │
│  │  - Legacy Format Transformation      │   │
│  │  - DEPRECATED                        │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ validateAnalysisResponse.m           │   │
│  │  - Schema Validation                 │   │
│  └──────────────────────────────────────┘   │
│  ┌──────────────────────────────────────┐   │
│  │ openapiHelpers.m                     │   │
│  │  - Field Extraction                  │   │
│  │  - Fallback Handling                 │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

---

## 2. Request Flow Analysis

### 2.1 MATLAB Request Construction

**File:** `MATLAB/Functions/buildAnalysisRequest.m`

**Function Signature:**
```matlab
function request = buildAnalysisRequest(projectId, firmId, budget, firmData, projectData, useSchemas)
```

**Output Structure:**
```matlab
request = struct(
    'budget', 100,           % integer or empty
    'firm_path', 'src/data/poc/firm_001.json',  % string or empty
    'project_path', 'src/data/poc/proj_001.json',  % string or empty
    'firm_data', struct(...),    % struct or empty
    'project_data', struct(...)  % struct or empty
)
```

**Issues Identified:**

#### Issue 2.1.1: Path Construction Without Validation
**Location:** `buildAnalysisRequest.m:73-78`
```matlab
request.firm_path = sprintf('src/data/poc/%s.json', firmIdStr);
```
**Problem:** Constructs path without checking if file exists. Relies on Python backend to validate.
**Impact:** MATLAB passes potentially invalid paths to Python API.
**Severity:** Medium - Python handles validation but creates unclear error messages.

#### Issue 2.1.2: Mixed Optional Field Handling
**Location:** `buildAnalysisRequest.m:56-105`
```matlab
if nargin >= 4 && ~isempty(firmData)
    request.firm_data = firmData;
else
    request.firm_path = firmIdStr;
end
```
**Problem:** Request can have either `firm_data` or `firm_path`, not both. Schema expects optional fields, but MATLAB may send incomplete requests.
**Impact:** Python Pydantic model has `Optional` types but MATLAB doesn't explicitly handle nulls.
**Severity:** Low - Works but not explicit.

### 2.2 Python Request Reception

**File:** `src/main.py`

**Pydantic Model:**
```python
class AnalysisRequest(BaseModel):
    firm_data: Optional[Dict[str, Any]] = None
    project_data: Optional[Dict[str, Any]] = None
    firm_path: Optional[str] = None
    project_path: Optional[str] = None
    budget: Optional[int] = 100
```

**Issues Identified:**

#### Issue 2.2.1: Optional Field Ambiguity
**Location:** `src/main.py:19-24`
**Problem:** All fields are Optional, but at least one of `(firm_data, firm_path)` and one of `(project_data, project_path)` should be required.
**Impact:** API can accept completely empty requests.
**Severity:** Medium - Validation occurs later in `load_data()` but error messages are unclear.

#### Issue 2.2.2: Path Translation Logic
**Location:** `src/main.py:26-53`
```python
if 'src/data' in path:
    parts = path.split('src/data', 1)
    container_path = f'/app/src/data{parts[1]}'
```
**Problem:** Hardcoded path translation from host to container paths. MATLAB sends host paths but Python may run in Docker.
**Impact:** Path resolution fails if MATLAB sends absolute paths in different formats.
**Severity:** High - Major cause of "File not found" errors.

---

## 3. Response Structure Analysis

### 3.1 Python Response Generation

**File:** `src/services/agent/core/orchestrator_v2.py`

**AnalysisOutput Structure (Pydantic):**
```python
class AnalysisOutput(BaseModel):
    # Core fields (always present)
    firm: Firm
    project: Project
    traversal_status: TraversalStatus
    node_assessments: Dict[str, NodeAssessment]
    all_chains: List[CriticalChain]
    matrix_classifications: Dict[RiskQuadrant, List[NodeClassification]]
    summary: SummaryMetrics
    recommendation: BidRecommendation

    # Enhanced fields (optional)
    graph_topology: Optional[GraphTopology] = None
    risk_distributions: Optional[RiskDistributions] = None
    propagation_trace: Optional[PropagationTrace] = None
    discovery_metadata: Optional[DiscoveryMetadata] = None
    evaluation_metadata: Optional[EvaluationMetadata] = None
    configuration_snapshot: Optional[ConfigurationSnapshot] = None
    graph_statistics: Optional[GraphStatistics] = None
    monte_carlo_parameters: Optional[MonteCarloParameters] = None
```

**API Response Format:**
```json
{
  "status": "success",
  "message": "Comprehensive analysis complete for {project.name}",
  "analysis": { ...AnalysisOutput... }
}
```

**Issues Identified:**

#### Issue 3.1.1: model_dump() Serialization
**Location:** `src/main.py:187`
```python
"analysis": analysis_result.model_dump()
```
**Problem:** Pydantic's `model_dump()` serializes enums as their values, nested models as dicts. MATLAB expects specific formats.
**Impact:**
- Enums become strings like `"Type A (High Influence / High Importance)"` instead of `"TYPE_A"`
- Nested arrays of objects become cell arrays in MATLAB
**Severity:** High - Causes parsing confusion in MATLAB.

#### Issue 3.1.2: Enhanced Sections Not Always Populated
**Location:** `src/services/agent/core/orchestrator_v2.py:620-719`
```python
try:
    enhanced['graph_topology'] = builder.build_graph_topology(...)
except Exception as e:
    logger.warning(f"Failed to build graph topology: {e}")
    enhanced['graph_topology'] = None
```
**Problem:** Many enhanced sections default to `None` on failure. MATLAB code expects these fields to exist.
**Impact:** MATLAB's `openapiHelpers.m` handles missing fields with fallbacks, but inconsistent behavior.
**Severity:** Medium - Graceful degradation but unclear to users.

---

## 4. MATLAB Response Parsing

### 4.1 Response Validation

**File:** `MATLAB/Functions/validateAnalysisResponse.m`

**Issues Identified:**

#### Issue 4.1.1: Field Name Variations Not Fully Handled
**Location:** `validateAnalysisResponse.m:88-98`
```matlab
hasInfluence = isfield(assessment, 'influence_score') || isfield(assessment, 'influence');
hasRisk = isfield(assessment, 'risk_level') || isfield(assessment, 'risk');
```
**Problem:** Checks for both old and new field names, but warns if missing. Python always uses new names (`influence_score`, `risk_level`).
**Impact:** Unnecessary warnings in logs.
**Severity:** Low - Cosmetic issue.

#### Issue 4.1.2: Matrix Classifications Quadrant Key Formats
**Location:** `validateAnalysisResponse.m:123-138`
```matlab
if contains(key, 'TYPE_A') || contains(key, 'TYPE_B') || ...
   contains(key, 'Type A') || contains(key, 'Type B') || ...
```
**Problem:** Tries to match multiple formats: `TYPE_A`, `Type A (High Influence / High Importance)`.
Python Pydantic emits: `"Type A (High Influence / High Importance)"` (full enum value).
**Impact:** String matching is fragile. If enum format changes, parsing breaks.
**Severity:** High - Core classification logic.

### 4.2 Response Transformation (DEPRECATED)

**File:** `MATLAB/Functions/parseAnalysisResponse.m`

**Deprecation Notice:**
```matlab
% DEPRECATED: This function is deprecated. Enhanced API schemas must be used.
warning('parseAnalysisResponse is deprecated. Use OpenAPI format directly with openapiHelpers.m');
```

**Issues Identified:**

#### Issue 4.2.1: Legacy Transformation Still Used
**Problem:** Despite deprecation warning, code is still called in backward compatibility mode:
```matlab
FlorentAPIClientWrapper.m:147:
data = parseAnalysisResponse(response, projectId, firmId);
```
**Impact:** Maintains old data structure format, loses enhanced schema data.
**Severity:** Medium - Blocks adoption of new features.

#### Issue 4.2.2: Node Assessment Field Mapping
**Location:** `parseAnalysisResponse.m:72-99`
```matlab
if isfield(assessment, 'influence_score')
    data.riskScores.influence(i) = assessment.influence_score;
elseif isfield(assessment, 'influence')
    data.riskScores.influence(i) = assessment.influence;
end
```
**Problem:** Dual field name support creates confusion. Python only sends `influence_score`, but code maintains fallbacks.
**Impact:** Extra complexity without benefit.
**Severity:** Low - Code smell.

### 4.3 OpenAPI Helper Functions

**File:** `MATLAB/Functions/openapiHelpers.m`

**Purpose:** Provide clean interface to access OpenAPI-formatted data.

**Issues Identified:**

#### Issue 4.3.1: Default Fallback Values
**Location:** `openapiHelpers.m:108-136`
```matlab
function influence = getInfluenceScore(analysis, nodeId)
    if isfield(analysis, 'node_assessments') && ...
       isfield(analysis.node_assessments, nodeId)
        % ... get value ...
    else
        influence = 0.5; % Default
    end
end
```
**Problem:** Returns default `0.5` if field missing. Masks data quality issues.
**Impact:** Silently replaces missing data with arbitrary values.
**Severity:** Medium - Can lead to incorrect analyses.

#### Issue 4.3.2: Matrix Type Extraction Complexity
**Location:** `openapiHelpers.m:228-278`
```matlab
function matrixType = getMatrixType(analysis, nodeId)
    % Search through each quadrant
    quadrantKeys = fieldnames(matrix);
    for q = 1:length(quadrantKeys)
        quadrantKey = quadrantKeys{q};
        % ... nested loops ...
    end
end
```
**Problem:** Complex nested loop to find node's quadrant. O(n*m) complexity.
**Impact:** Slow for large graphs. Should build reverse map once.
**Severity:** Low - Performance issue for large graphs.

---

## 5. Data Structure Mismatches

### 5.1 JSON Arrays → MATLAB Structures

**Problem:** JSON arrays serialize differently based on content:

| JSON Structure | MATLAB Type | Access Pattern |
|----------------|-------------|----------------|
| `["a", "b", "c"]` | Cell array | `data{1}` |
| `[1, 2, 3]` | Numeric array | `data(1)` |
| `[{"id": 1}, {"id": 2}]` | Struct array | `data(1).id` |
| `[{"id": 1}, "mixed"]` | Cell array | `data{1}.id` |

**Issue Locations:**

#### Issue 5.1.1: all_chains Array Type Confusion
**Location:** `parseAnalysisResponse.m:196-220`
```matlab
if iscell(chains)
    % Cell array of chain structs
    for chainIdx = 1:length(chains)
        chain = chains{chainIdx};
elseif isstruct(chains)
    % Struct array
```
**Problem:** Code handles both formats but Python always sends struct array. Unnecessary branches.
**Impact:** Code complexity, potential bugs.
**Severity:** Low - Works but messy.

#### Issue 5.1.2: node_ids vs nodes Field Confusion
**Location:** `parseAnalysisResponse.m:246-251`
```matlab
if isfield(chain, 'node_ids') && ~isempty(chain.node_ids)
    chainNodes = chain.node_ids;
elseif isfield(chain, 'nodes') && ~isempty(chain.nodes)
    chainNodes = chain.nodes;
end
```
**Problem:** Python API renamed `nodes` → `node_ids` but MATLAB maintains backward compatibility.
Python sends: `node_ids` (List[str])
Old API sent: `nodes` (List[str])
**Impact:** Fallback never triggers with current API but adds complexity.
**Severity:** Low - Dead code path.

### 5.2 Enum Serialization

**Python Enum Definition:**
```python
class RiskQuadrant(str, Enum):
    TYPE_A = "Type A (High Influence / High Importance)"
    TYPE_B = "Type B (High Influence / Low Importance)"
    TYPE_C = "Type C (Low Influence / High Importance)"
    TYPE_D = "Type D (Low Influence / Low Importance)"
```

**Pydantic Serialization:**
```python
# Config:
class Config:
    use_enum_values = True

# Result: Enum is serialized as its VALUE, not its NAME
# JSON: "Type A (High Influence / High Importance)"
# NOT: "TYPE_A"
```

**MATLAB Parsing:**
```matlab
% parseAnalysisResponse.m:391-399
if contains(quadrantKey, 'TYPE_A') || contains(quadrantKey, 'Type A')
    nodeToQuadrant(nodeId) = 'Q1';
```

**Issue:** MATLAB expects both `TYPE_A` and `Type A` formats. Python sends full descriptive string.

**Impact:**
- String matching is fragile
- Contains() may match substrings incorrectly
- Should use exact match: `strcmp(quadrantKey, 'Type A (High Influence / High Importance)')`

**Severity:** High - Core classification parsing.

### 5.3 Adjacency Matrix Format

**Python Output:**
```python
# GraphTopology.adjacency_matrix
adjacency_matrix: List[List[float]]  # NxN matrix

# Example:
[[0.0, 0.8, 0.0],
 [0.0, 0.0, 0.9],
 [0.0, 0.0, 0.0]]
```

**MATLAB Reception:**
```matlab
% openapiHelpers.m:640-648
adjMatrix = topology.adjacency_matrix;
if iscell(adjMatrix)
    n = length(adjMatrix);
    adjMatrix = cell2mat(adjMatrix);
end
```

**Issue:** Python sends `List[List[float]]` which MATLAB's `jsondecode()` converts to:
- **Struct array format:** If JSON has uniform structure
- **Cell array format:** If JSON has mixed types

**Problem:** Code checks for cell array but Python sends consistent format → should be numeric array directly.

**Severity:** Low - Works but shows confusion about data types.

---

## 6. Schema Definitions

### 6.1 AnalysisRequest Schema

**Location:** `docs/openapi_export/schemas/AnalysisRequest.json`

```json
{
  "properties": {
    "firm_data": {
      "oneOf": [
        {"type": "object", "additionalProperties": {}},
        {"type": "null"}
      ]
    },
    "budget": {
      "oneOf": [
        {"type": "integer", "default": 100},
        {"type": "null"}
      ],
      "default": 100
    }
  }
}
```

**Issues Identified:**

#### Issue 6.1.1: oneOf Complicates MATLAB Parsing
**Problem:** JSON Schema `oneOf` means "exactly one of these types". MATLAB's `jsondecode()` doesn't validate schema.
**Impact:** MATLAB must handle multiple possible types for same field:
```matlab
if ischar(firmData) || isstring(firmData)
    firmData = jsondecode(firmData);
end
```
**Severity:** Medium - Adds parsing complexity.

#### Issue 6.1.2: Nested oneOf with null
**Problem:** Schema allows `budget: null` but also has `default: 100`. MATLAB may send empty field which Python interprets as `null` vs Python default.
**Impact:** Inconsistent budget values.
**Severity:** Low - Usually works.

### 6.2 AnalysisOutput Schema

**Location:** `docs/openapi_export/schemas_enhanced/AnalysisOutput.json`

**Size:** 1958 lines of JSON schema with deeply nested `$refs`.

**Issues Identified:**

#### Issue 6.2.1: Deep Nesting with $refs
**Example:**
```json
{
  "matrix_classifications": {
    "additionalProperties": {
      "items": {
        "$ref": "#/$defs/NodeClassification"
      }
    }
  }
}
```

**Problem:** MATLAB's `load_florent_schemas.m` loads JSON but doesn't resolve `$refs`. Schema validation is incomplete.
**Impact:** Can't fully validate responses against schema in MATLAB.
**Severity:** Medium - Validation is weaker than intended.

#### Issue 6.2.2: anyOf vs oneOf Inconsistency
**Example:**
```json
"graph_topology": {
  "anyOf": [
    {"$ref": "#/$defs/GraphTopology"},
    {"type": "null"}
  ]
}
```

**Problem:** `anyOf` means "one or more of these". MATLAB treats it same as `oneOf`. For `[GraphTopology, null]`, same behavior, but conceptually wrong.
**Impact:** Schema semantics not preserved.
**Severity:** Low - Works in practice.

---

## 7. Field Name Mappings

### 7.1 Complete Field Name Inventory

| Python Field | MATLAB Expected | Fallback Fields | Location |
|--------------|----------------|-----------------|----------|
| `influence_score` | `influence_score` | `influence` | NodeAssessment |
| `risk_level` | `risk_level` | `risk` | NodeAssessment |
| `importance_score` | `importance_score` | `importance` | NodeAssessment |
| `is_on_critical_path` | `is_on_critical_path` | `isOnCriticalPath` | NodeAssessment |
| `node_ids` | `node_ids` | `nodes` | CriticalChain |
| `cumulative_risk` | `cumulative_risk` | `aggregate_risk` | CriticalChain |
| `aggregate_project_score` | `aggregate_project_score` | `overall_bankability` | SummaryMetrics |
| `matrix_classifications` | `matrix_classifications` | `action_matrix` | AnalysisOutput |
| `all_chains` | `all_chains` | `critical_chains` | AnalysisOutput |

**Issue:** Multiple fallback fields maintained for backward compatibility but current Python API only uses new names.

**Severity:** Medium - Code bloat, confusion, dead paths.

### 7.2 Naming Convention Mismatches

**Python Convention:** `snake_case` (PEP 8)
```python
node_id: str
importance_score: float
risk_level: float
```

**MATLAB Convention:** Mix of `camelCase` and `snake_case`
```matlab
data.riskScores.nodeIds{i}  % camelCase struct field
node_id = 'node_001'         % snake_case in API fields
```

**Problem:** Inconsistent naming creates cognitive load. MATLAB code uses both conventions.

**Impact:** Harder to maintain, potential for typos.

**Severity:** Medium - Maintenance burden.

---

## 8. Error Handling & Edge Cases

### 8.1 MATLAB Error Handling

**File:** `MATLAB/Functions/FlorentAPIClientWrapper.m`

**Retry Logic:**
```matlab
for attempt = 1:obj.RetryAttempts
    try
        response = webwrite(endpoint, request, options);
        return;
    catch ME
        if contains(errorMsg, 'timeout', 'IgnoreCase', true) || ...
           contains(errorMsg, 'network', 'IgnoreCase', true)
            % Retryable error
            pause(obj.RetryDelay);
            continue;
        else
            % Non-retryable error
            break;
        end
    end
end
```

**Issues Identified:**

#### Issue 8.1.1: String Matching for Error Classification
**Problem:** Uses `contains()` to detect retryable errors. Fragile if error message format changes.
**Impact:** May not retry when should, or retry when shouldn't.
**Severity:** Medium - Reliability issue.

#### Issue 8.1.2: No Status Code Checking
**Problem:** Doesn't check HTTP status codes (404, 500, etc.). Only checks exception message strings.
**Impact:** Can't distinguish between client errors (4xx) and server errors (5xx).
**Severity:** Medium - Can't provide specific error guidance.

### 8.2 Python Error Handling

**File:** `src/main.py`

```python
@post("/analyze")
async def analyze_project(data: AnalysisRequest) -> Dict[str, Any]:
    try:
        # ... analysis ...
        return {
            "status": "success",
            "message": f"Comprehensive analysis complete",
            "analysis": analysis_result.model_dump()
        }
    except Exception as e:
        logger.error("analysis_failed", error=str(e), exc_info=True)
        return {"status": "error", "message": str(e)}
```

**Issues Identified:**

#### Issue 8.2.1: Generic Exception Catch
**Problem:** Catches all exceptions and returns same error format. Doesn't distinguish between:
- Validation errors (bad request)
- File not found (data loading)
- LLM API failures
- Internal bugs

**Impact:** MATLAB receives generic error messages without actionable details.
**Severity:** High - Poor debugging experience.

#### Issue 8.2.2: No HTTP Status Codes
**Problem:** Always returns 200 OK even on errors. Error is in `"status": "error"` field.
**Impact:** HTTP clients can't use status codes for error handling.
**Severity:** Medium - Not RESTful best practice.

---

## 9. Performance & Optimization Issues

### 9.1 MATLAB Performance

#### Issue 9.1.1: Repeated Schema Loading
**Location:** `openapiHelpers.m:459-472`
```matlab
persistent cachedSchemas;
if isempty(cachedSchemas)
    cachedSchemas = load_florent_schemas();
end
```
**Good:** Uses persistent variable for caching.
**Issue:** Schema files read from disk every MATLAB session start. ~9 JSON files.
**Impact:** Slow startup (< 1s but noticeable).
**Severity:** Low - One-time cost.

#### Issue 9.1.2: getMatrixType() Loop Complexity
**Location:** `openapiHelpers.m:228-278`
**Problem:** O(n*m) loop to find node's quadrant. For 100 nodes × 4 quadrants × avg 25 nodes/quadrant = 10,000 iterations worst case.
**Impact:** Slow for large graphs.
**Optimization:** Build reverse map once: `node_id → quadrant`.
**Severity:** Low - Only an issue for 100+ node graphs.

### 9.2 Python Performance

#### Issue 9.2.1: Enhanced Output Builder Errors Silently Ignored
**Location:** `orchestrator_v2.py:644-646`
```python
try:
    enhanced['graph_topology'] = builder.build_graph_topology(...)
except Exception as e:
    logger.warning(f"Failed to build graph topology: {e}")
    enhanced['graph_topology'] = None
```
**Problem:** Catches and silently continues on errors. Expensive computation may fail without user knowing.
**Impact:** Users think analysis succeeded but missing enhanced data.
**Severity:** Medium - Confusing UX.

#### Issue 9.2.2: Synchronous File I/O in Async Context
**Location:** `main.py:51-52`
```python
with open(file_path, "r") as f:
    return json.load(f)
```
**Problem:** Synchronous file read in async function. Blocks event loop.
**Impact:** Can't handle concurrent requests efficiently.
**Severity:** Low - Single-user deployment.

---

## 10. Critical Issues Summary

### 10.1 High Severity Issues

| Issue ID | Description | Impact | Location |
|----------|-------------|--------|----------|
| **2.2.2** | Path translation host→container hardcoded | File not found errors | `main.py:38-46` |
| **3.1.1** | Enum serialization format mismatch | Parsing failures | `main.py:187` |
| **4.1.2** | Matrix quadrant key format fragility | Classification failures | `validateAnalysisResponse.m:128` |
| **5.2** | RiskQuadrant enum string matching | Wrong classifications | `parseAnalysisResponse.m:391` |
| **8.2.1** | Generic exception handling | Poor error messages | `main.py:190-192` |

### 10.2 Medium Severity Issues

| Issue ID | Description | Impact | Location |
|----------|-------------|--------|----------|
| **2.1.1** | Path construction without validation | Unclear errors | `buildAnalysisRequest.m:73` |
| **2.2.1** | Optional field ambiguity | Can accept empty requests | `main.py:19-24` |
| **3.1.2** | Enhanced sections nullable | Missing data | `orchestrator_v2.py:669-719` |
| **4.3.1** | Default fallback values (0.5) | Masks missing data | `openapiHelpers.m:134` |
| **6.1.1** | oneOf schema complexity | Parsing complexity | Schema files |
| **7.2** | Naming convention inconsistency | Maintenance burden | Throughout |
| **8.1.1** | Error classification via string match | Unreliable retries | `FlorentAPIClientWrapper.m:270` |
| **8.2.2** | No HTTP status codes | Not RESTful | `main.py:192` |
| **9.2.1** | Enhanced output errors silently ignored | Confusing UX | `orchestrator_v2.py:644` |

---

## 11. Data Flow Examples

### 11.1 Successful Request/Response Cycle

**Step 1: MATLAB Request Construction**
```matlab
>> request = buildAnalysisRequest('proj_001', 'firm_001', 100)

request =
  struct with fields:
             budget: 100
          firm_path: 'src/data/poc/firm_001.json'
       project_path: 'src/data/poc/proj_001.json'
```

**Step 2: JSON Serialization by webwrite()**
```json
{
  "budget": 100,
  "firm_path": "src/data/poc/firm_001.json",
  "project_path": "src/data/poc/proj_001.json"
}
```

**Step 3: Python Reception**
```python
# Pydantic auto-validates and converts
data = AnalysisRequest(
    budget=100,
    firm_path="src/data/poc/firm_001.json",
    project_path="src/data/poc/proj_001.json",
    firm_data=None,
    project_data=None
)
```

**Step 4: Python Response**
```json
{
  "status": "success",
  "message": "Comprehensive analysis complete for Wakanda Bridge",
  "analysis": {
    "firm": {...},
    "project": {...},
    "node_assessments": {
      "node_op_0": {
        "node_id": "node_op_0",
        "node_name": "Construction",
        "importance_score": 0.85,
        "influence_score": 0.60,
        "risk_level": 0.34,
        "reasoning": "...",
        "is_on_critical_path": true
      }
    },
    "matrix_classifications": {
      "Type A (High Influence / High Importance)": [
        {
          "node_id": "node_op_0",
          "node_name": "Construction",
          "influence_score": 0.60,
          "importance_score": 0.85,
          "quadrant": "Type A (High Influence / High Importance)"
        }
      ]
    },
    "all_chains": [...],
    "summary": {...}
  }
}
```

**Step 5: MATLAB Parsing**
```matlab
>> [isValid, errors, warnings] = validateAnalysisResponse(response)
isValid = 1
errors = {}
warnings = {}

>> nodeIds = openapiHelpers('getNodeIds', response.analysis)
nodeIds = {'node_op_0', 'node_op_1', ...}

>> influence = openapiHelpers('getInfluenceScore', response.analysis, 'node_op_0')
influence = 0.6000
```

### 11.2 Failed Request: Path Not Found

**MATLAB Request:**
```matlab
>> request = buildAnalysisRequest('proj_999', 'firm_001', 100)
% Constructs: 'src/data/poc/proj_999.json'
% File does not exist
```

**Python Processing:**
```python
def load_data(data, path):
    if path:
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {path}")
```

**Python Response:**
```json
{
  "status": "error",
  "message": "File not found: src/data/poc/proj_999.json"
}
```

**MATLAB Handling:**
```matlab
% validateAnalysisResponse() checks status field
if strcmp(response.status, 'error')
    error('API returned error: %s', response.message);
end
% Error: API returned error: File not found: src/data/poc/proj_999.json
```

**Issue:** Error message doesn't indicate whether it's a MATLAB path construction error or Python file system error.

---

## 12. Recommendations

### 12.1 Immediate Fixes (High Priority)

1. **Enum Serialization Standardization**
   - **Python:** Change Pydantic config to serialize enums as NAME not VALUE:
     ```python
     class Config:
         use_enum_values = False  # Serialize as "TYPE_A" not "Type A (...)"
     ```
   - **MATLAB:** Update parsers to expect `TYPE_A`, `TYPE_B`, etc.
   - **Impact:** Fixes fragile string matching in classification parsing.

2. **Path Resolution Clarity**
   - **Python:** Add clear error message distinguishing:
     - Path format error (MATLAB constructed wrong path)
     - File not found (path correct but file doesn't exist)
   - **MATLAB:** Add optional path validation before API call:
     ```matlab
     if ~isfile(request.firm_path)
         warning('Firm file not found locally: %s', request.firm_path);
     end
     ```

3. **HTTP Status Codes**
   - **Python:** Return proper HTTP status codes:
     ```python
     from litestar.exceptions import HTTPException
     from litestar import status_codes

     if not os.path.exists(file_path):
         raise HTTPException(
             status_code=status_codes.HTTP_404_NOT_FOUND,
             detail=f"File not found: {path}"
         )
     ```
   - **MATLAB:** Check `response.StatusCode` before parsing body.

4. **Error Classification in Retry Logic**
   - **MATLAB:** Use HTTP status codes instead of string matching:
     ```matlab
     if response.StatusCode >= 500
         % Server error - retry
     elseif response.StatusCode == 408 || response.StatusCode == 429
         % Timeout or rate limit - retry with backoff
     else
         % Client error - don't retry
     end
     ```

### 12.2 Medium Priority Improvements

5. **Field Name Standardization**
   - Remove all fallback field name checks (e.g., `influence` vs `influence_score`)
   - Python API only uses new names, MATLAB should only expect new names
   - Remove deprecated `parseAnalysisResponse.m` entirely

6. **Schema Validation**
   - Add full JSON Schema validation in Python using `jsonschema` library:
     ```python
     from jsonschema import validate
     validate(instance=request.dict(), schema=analysis_request_schema)
     ```
   - Provides clear validation errors before processing

7. **Enhanced Output Builder Error Handling**
   - Don't silently set to `None` on errors
   - Return partial data with error metadata:
     ```python
     enhanced['graph_topology'] = {
         'error': str(e),
         'partial_data': None
     }
     ```

8. **Adjacency Matrix Type Clarity**
   - Python: Document that `List[List[float]]` → MATLAB numeric array
   - MATLAB: Remove `iscell()` check since Python never sends cell format

### 12.3 Long-term Architecture Changes

9. **OpenAPI Client Generation**
   - Generate MATLAB client from OpenAPI spec using REST API Client Generator
   - Eliminates manual request/response handling
   - Type safety from generated code

10. **Deprecate Legacy parseAnalysisResponse()**
    - Force all code to use OpenAPI format with `openapiHelpers.m`
    - Remove transformation layer
    - Simplifies maintenance

11. **Structured Logging**
    - Add request ID tracing from MATLAB through Python
    - Correlate MATLAB logs with Python logs
    - Example:
      ```matlab
      request.request_id = string(java.util.UUID.randomUUID());
      ```
      ```python
      logger.info("request_received", request_id=data.request_id)
      ```

12. **Async File I/O**
    - Use `aiofiles` for async file reading:
      ```python
      import aiofiles
      async with aiofiles.open(file_path, 'r') as f:
          return json.loads(await f.read())
      ```

---

## 13. Testing Recommendations

### 13.1 Integration Tests

Create comprehensive integration tests covering:

1. **Request Format Variations**
   - Empty optional fields
   - Both `firm_data` and `firm_path` provided
   - Invalid paths
   - Invalid budget values

2. **Response Parsing**
   - All enhanced sections present
   - All enhanced sections null
   - Mixed (some present, some null)
   - Large graphs (100+ nodes)

3. **Error Scenarios**
   - File not found
   - Invalid JSON in data files
   - Network timeout
   - API server down

4. **Field Name Compatibility**
   - Test with old field names (should fail)
   - Test with new field names (should succeed)

### 13.2 Schema Validation Tests

1. **Python side:**
   ```python
   def test_analysis_request_schema():
       # Valid request
       valid = {"budget": 100, "firm_path": "test.json"}
       request = AnalysisRequest(**valid)

       # Invalid budget
       with pytest.raises(ValidationError):
           AnalysisRequest(budget="invalid")
   ```

2. **MATLAB side:**
   ```matlab
   function testSchemaValidation()
       request = buildAnalysisRequest('proj_001', 'firm_001', 100);
       isValid = openapiHelpers('validateRequest', request);
       assert(isValid, 'Request should be valid');
   end
   ```

### 13.3 Round-trip Tests

```matlab
function testRoundTrip()
    % Build request
    request = buildAnalysisRequest('proj_001', 'firm_001', 100);

    % Serialize to JSON
    jsonStr = jsonencode(request);

    % Deserialize
    parsed = jsondecode(jsonStr);

    % Verify fields match
    assert(isequal(request.budget, parsed.budget));
    assert(strcmp(request.firm_path, parsed.firm_path));
end
```

---

## 14. Conclusions

### 14.1 Root Causes

The primary issues stem from:

1. **Lack of Contract Enforcement** - No automated schema validation between MATLAB and Python
2. **Evolution Without Deprecation** - Old field names maintained for backward compatibility
3. **Type System Mismatch** - Python's type system (Pydantic) vs MATLAB's dynamic typing
4. **Error Handling Philosophy** - Python returns 200 OK with error payload, not HTTP error codes

### 14.2 Impact Assessment

**Current State:** System mostly works but has fragile parsing logic susceptible to schema changes.

**Risk Level:** Medium
- High-severity issues (enum parsing, path resolution) cause failures
- Medium-severity issues cause confusion and poor UX
- System is functional but maintenance burden is high

**Mitigation:** Follow recommendations to standardize field names, add schema validation, and improve error handling.

### 14.3 Success Metrics

After implementing recommendations, measure:

1. **Parse Failure Rate** - Should be < 0.1%
2. **Schema Validation Coverage** - 100% of requests and responses validated
3. **Error Message Clarity** - User can resolve 90% of errors without code inspection
4. **Code Complexity** - Reduce lines of code in parsers by removing fallback logic

---

## Appendix A: File Inventory

### MATLAB Files

| File | Purpose | Lines | Issues |
|------|---------|-------|--------|
| `FlorentAPIClientWrapper.m` | HTTP client wrapper | 318 | 8.1.1, 8.1.2 |
| `buildAnalysisRequest.m` | Request construction | 108 | 2.1.1, 2.1.2 |
| `callPythonAPI.m` | Low-level HTTP | 45 | None major |
| `parseAnalysisResponse.m` | Response transformation | 577 | DEPRECATED |
| `validateAnalysisResponse.m` | Response validation | 242 | 4.1.1, 4.1.2 |
| `openapiHelpers.m` | Field extraction | 790 | 4.3.1, 4.3.2 |
| `load_florent_schemas.m` | Schema loading | 378 | 6.2.1 |

### Python Files

| File | Purpose | Lines | Issues |
|------|---------|-------|--------|
| `main.py` | API server | 199 | 2.2.1, 2.2.2, 8.2.1, 8.2.2 |
| `orchestrator_v2.py` | Analysis orchestrator | 719+ | 9.2.1 |
| `enhanced_output_builder.py` | Output enhancement | 577 | None major |
| `analysis.py` | Pydantic models | 158 | 3.1.1 |
| `schemas.py` | Configuration | 339 | None major |

### Schema Files

| File | Size | Purpose |
|------|------|---------|
| `AnalysisRequest.json` | 67 lines | Request schema |
| `AnalysisOutput.json` | 1958 lines | Response schema |
| `GraphTopology.json` | 728 lines | Graph structure |
| `RiskDistributions.json` | 545 lines | Risk data |
| `MonteCarloParameters.json` | 833 lines | MC params |

---

## Appendix B: Example Payloads

### B.1 Complete Request Example

```json
{
  "budget": 100,
  "firm_path": "src/data/poc/firm_001.json",
  "project_path": "src/data/poc/proj_001.json"
}
```

### B.2 Complete Response Example (Truncated)

```json
{
  "status": "success",
  "message": "Comprehensive analysis complete for Wakanda Bridge",
  "analysis": {
    "firm": {
      "id": "firm_001",
      "name": "Global Infrastructure Corp",
      "countries_active": [
        {"name": "United States", "a2": "US", "a3": "USA"}
      ]
    },
    "project": {
      "id": "proj_001",
      "name": "Wakanda Bridge",
      "sector": "Transportation"
    },
    "traversal_status": "COMPLETE",
    "node_assessments": {
      "node_op_0": {
        "node_id": "node_op_0",
        "node_name": "Construction",
        "importance_score": 0.85,
        "influence_score": 0.60,
        "risk_level": 0.34,
        "reasoning": "Critical construction phase requires local expertise",
        "is_on_critical_path": true
      }
    },
    "all_chains": [
      {
        "node_ids": ["node_entry", "node_op_0", "node_exit"],
        "node_names": ["Entry", "Construction", "Exit"],
        "cumulative_risk": 0.42,
        "length": 3
      }
    ],
    "matrix_classifications": {
      "Type A (High Influence / High Importance)": [
        {
          "node_id": "node_op_0",
          "node_name": "Construction",
          "influence_score": 0.60,
          "importance_score": 0.85,
          "quadrant": "Type A (High Influence / High Importance)"
        }
      ]
    },
    "summary": {
      "aggregate_project_score": 0.72,
      "total_token_cost": 3450,
      "critical_failure_likelihood": 0.42,
      "nodes_evaluated": 15,
      "total_nodes": 15,
      "critical_dependency_count": 3
    },
    "recommendation": {
      "should_bid": true,
      "confidence": 0.78,
      "reasoning": "Strong project fundamentals with manageable risks",
      "key_risks": ["Local expertise availability"],
      "key_opportunities": ["Strong firm capability alignment"]
    },
    "graph_topology": {
      "adjacency_matrix": [
        [0.0, 0.8, 0.0],
        [0.0, 0.0, 0.9],
        [0.0, 0.0, 0.0]
      ],
      "node_index": ["node_entry", "node_op_0", "node_exit"],
      "edges": [...],
      "nodes": [...],
      "statistics": {...}
    }
  }
}
```

---

## Appendix C: Quick Reference

### C.1 Key Field Mappings

| API Field | MATLAB Access | Type |
|-----------|--------------|------|
| `node_assessments.{id}.influence_score` | `openapiHelpers('getInfluenceScore', analysis, id)` | double 0-1 |
| `node_assessments.{id}.risk_level` | `openapiHelpers('getRiskLevel', analysis, id)` | double 0-1 |
| `all_chains` | `openapiHelpers('getAllChains', analysis)` | struct array |
| `matrix_classifications` | `openapiHelpers('getMatrixType', analysis, id)` | string |
| `graph_topology.adjacency_matrix` | `openapiHelpers('getAdjacencyMatrix', analysis)` | double NxN |

### C.2 Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `File not found: src/data/poc/...` | Path construction error | Check if file exists in MATLAB workspace |
| `API returned error: ...` | Python exception | Check Python logs for details |
| `Invalid response: missing status field` | Network error | Check if API server is running |
| `Request validation failed` | Schema mismatch | Check request structure matches AnalysisRequest |

---

**Document Version:** 1.0
**Last Updated:** 2026-02-08
**Maintainer:** Claude Code Analysis Agent

---

## 15. REMAINING WORK - MATLAB SIDE ONLY

### ✅ Python/API Side: COMPLETE
All Python and API issues have been fixed. See `PYTHON_API_FIXES_SUMMARY.md`.

### ⏳ MATLAB Side: TODO

#### High Priority - Breaking Changes

##### 1. Update Enum String Matching
**Files:** 
- `MATLAB/Functions/parseAnalysisResponse.m` (lines 391-421)
- `MATLAB/Functions/validateAnalysisResponse.m` (lines 123-138)

**Change Required:**
```matlab
% OLD (broken):
if contains(quadrantKey, 'TYPE_A') || contains(quadrantKey, 'Type A')
    nodeToQuadrant(nodeId) = 'Q1';

% NEW (correct):
if strcmp(quadrantKey, 'TYPE_A')
    nodeToQuadrant(nodeId) = 'Q1';
elseif strcmp(quadrantKey, 'TYPE_B')
    nodeToQuadrant(nodeId) = 'Q2';
elseif strcmp(quadrantKey, 'TYPE_C')
    nodeToQuadrant(nodeId) = 'Q3';
elseif strcmp(quadrantKey, 'TYPE_D')
    nodeToQuadrant(nodeId) = 'Q4';
end
```

**Impact:** Classification parsing will fail without this fix.

---

##### 2. HTTP Status Code Handling
**File:** `MATLAB/Functions/FlorentAPIClientWrapper.m`

**Change Required:**
```matlab
% Add status code checking to callAnalyzeEndpoint()
response = webwrite(endpoint, request, options);

% Check HTTP status code
if response.StatusCode ~= 200
    error('API error (HTTP %d): %s', response.StatusCode, response.StatusLine);
end

% For retries - check status code not string
if response.StatusCode >= 500 || response.StatusCode == 408
    % Server error or timeout - retry
    pause(obj.RetryDelay);
    continue;
elseif response.StatusCode >= 400 && response.StatusCode < 500
    % Client error - don't retry
    break;
end
```

**Impact:** Better error handling and retry logic.

---

##### 3. Error Response Parsing
**Files:**
- `MATLAB/Functions/FlorentAPIClientWrapper.m`
- `MATLAB/Functions/validateAnalysisResponse.m`

**Change Required:**
Litestar returns different error format:
```matlab
% OLD format:
% {"status": "error", "message": "..."}

% NEW format (Litestar HTTPException):
% {"status_code": 404, "detail": "...", "extra": {}}

% Update parsing:
if isfield(response, 'status_code') && response.status_code ~= 200
    errorMsg = response.detail;
    error('API error: %s', errorMsg);
end
```

**Impact:** Error messages won't display correctly without this.

---

#### Medium Priority - Code Cleanup

##### 4. Remove Deprecated parseAnalysisResponse.m
**File:** `MATLAB/Functions/parseAnalysisResponse.m`

**Action:** Delete entire file or mark as truly deprecated.

**Reason:** 
- Marked DEPRECATED since enhanced API
- Still called from `FlorentAPIClientWrapper.m:147` in legacy mode
- Loses enhanced schema data
- Adds unnecessary complexity

**Fix:**
```matlab
% In FlorentAPIClientWrapper.m, remove:
if useOpenAPIFormat
    % ... OpenAPI format
else
    data = parseAnalysisResponse(response, projectId, firmId);  % DELETE THIS
end

% Always use OpenAPI format:
data = response.analysis;
```

---

##### 5. Remove Fallback Field Names
**Files:**
- `MATLAB/Functions/openapiHelpers.m` (multiple functions)
- `MATLAB/Functions/validateAnalysisResponse.m`
- `MATLAB/Functions/parseAnalysisResponse.m` (if not deleted)

**Changes:**
```matlab
% OLD (unnecessary fallbacks):
if isfield(assessment, 'influence_score')
    data.riskScores.influence(i) = assessment.influence_score;
elseif isfield(assessment, 'influence')
    data.riskScores.influence(i) = assessment.influence;  % DELETE
end

% NEW (Python only sends new names):
data.riskScores.influence(i) = assessment.influence_score;
```

**Fields to clean up:**
- `influence_score` / `influence` → use only `influence_score`
- `risk_level` / `risk` → use only `risk_level`
- `importance_score` / `importance` → use only `importance_score`
- `is_on_critical_path` / `isOnCriticalPath` → use only `is_on_critical_path`
- `node_ids` / `nodes` → use only `node_ids`
- `cumulative_risk` / `aggregate_risk` → use only `cumulative_risk`
- `aggregate_project_score` / `overall_bankability` → use only `aggregate_project_score`

**Impact:** Simpler code, removes dead branches.

---

##### 6. Fix Default Fallback Values
**File:** `MATLAB/Functions/openapiHelpers.m`

**Change Required:**
```matlab
% OLD (masks missing data):
if isfield(analysis, 'node_assessments') && ...
   isfield(analysis.node_assessments, nodeId)
    influence = assessment.influence_score;
else
    influence = 0.5; % DEFAULT - BAD!
end

% NEW (fail explicitly):
if ~isfield(analysis, 'node_assessments') || ...
   ~isfield(analysis.node_assessments, nodeId)
    error('Node not found in analysis: %s', nodeId);
end
influence = assessment.influence_score;
```

**Impact:** Errors on missing data instead of silently using 0.5.

---

##### 7. Optimize getMatrixType() Loop
**File:** `MATLAB/Functions/openapiHelpers.m` (lines 228-278)

**Change Required:**
Build reverse map once instead of searching every time:

```matlab
% Add to openapiHelpers as new function:
function nodeQuadrantMap = buildMatrixMap(analysis)
    % Build reverse map: node_id -> quadrant
    persistent cachedMap;
    persistent cachedAnalysis;
    
    % Cache by analysis object
    if isequal(analysis, cachedAnalysis)
        nodeQuadrantMap = cachedMap;
        return;
    end
    
    nodeQuadrantMap = containers.Map();
    if ~isfield(analysis, 'matrix_classifications')
        return;
    end
    
    quadrantKeys = fieldnames(analysis.matrix_classifications);
    for q = 1:length(quadrantKeys)
        quadrantKey = quadrantKeys{q};
        nodeList = analysis.matrix_classifications.(quadrantKey);
        
        for n = 1:length(nodeList)
            nodeClass = nodeList(n);
            if isfield(nodeClass, 'node_id')
                nodeQuadrantMap(nodeClass.node_id) = quadrantKey;
            end
        end
    end
    
    cachedMap = nodeQuadrantMap;
    cachedAnalysis = analysis;
end

% Update getMatrixType():
function matrixType = getMatrixType(analysis, nodeId)
    map = buildMatrixMap(analysis);
    if isKey(map, nodeId)
        matrixType = map(nodeId);
    else
        matrixType = '';
    end
end
```

**Impact:** O(1) lookup instead of O(n*m) search.

---

#### Low Priority - Improvements

##### 8. Remove Cell Array Handling for Struct Arrays
**File:** `MATLAB/Functions/parseAnalysisResponse.m`

**Issue:** Code handles both cell arrays and struct arrays, but Python always sends struct arrays.

**Fix:** Remove cell array branches:
```matlab
% DELETE:
if iscell(chains)
    for chainIdx = 1:length(chains)
        chain = chains{chainIdx};
        ...
    end
elseif isstruct(chains)  % KEEP THIS
    ...
end
```

---

##### 9. Update Test Files
**Files:**
- `MATLAB/Scripts/testFlorentAPIClient.m`
- All other test scripts

**Changes:**
- Update mock responses to use TYPE_A format
- Update error checking to use HTTP status codes
- Remove legacy field names from mocks

---

### Summary: MATLAB Work Remaining

| Priority | Issue | File(s) | Effort |
|----------|-------|---------|--------|
| **HIGH** | Enum string matching | parseAnalysisResponse.m, validateAnalysisResponse.m | 15 min |
| **HIGH** | HTTP status codes | FlorentAPIClientWrapper.m | 30 min |
| **HIGH** | Error response format | FlorentAPIClientWrapper.m, validateAnalysisResponse.m | 15 min |
| **MEDIUM** | Delete parseAnalysisResponse.m | parseAnalysisResponse.m, FlorentAPIClientWrapper.m | 10 min |
| **MEDIUM** | Remove fallback field names | openapiHelpers.m, validateAnalysisResponse.m | 30 min |
| **MEDIUM** | Fix default fallbacks | openapiHelpers.m | 20 min |
| **MEDIUM** | Optimize getMatrixType | openapiHelpers.m | 30 min |
| **LOW** | Remove cell array handling | parseAnalysisResponse.m | 10 min |
| **LOW** | Update tests | All test scripts | 30 min |

**Total Estimated Effort:** ~3 hours

---

### Testing After MATLAB Fixes

**1. Basic Request:**
```matlab
client = FlorentAPIClientWrapper('http://localhost:8000');
data = client.analyzeProject('proj_001', 'firm_001', 100);
```

**Expected:**
- No errors
- `data.analysis.matrix_classifications` has TYPE_A keys
- All fields use new names (influence_score, not influence)

**2. File Not Found:**
```matlab
try
    data = client.analyzeProject('nonexistent', 'firm_001', 100);
    error('Should have thrown error');
catch ME
    assert(contains(ME.message, 'HTTP 404') || contains(ME.message, 'File not found'));
end
```

**3. Invalid Budget:**
```matlab
try
    data = client.analyzeProject('proj_001', 'firm_001', -100);
    error('Should have thrown error');
catch ME
    assert(contains(ME.message, 'HTTP 400') || contains(ME.message, 'budget must be positive'));
end
```

**4. Matrix Classification:**
```matlab
data = client.analyzeProject('proj_001', 'firm_001', 100);
quadrant = openapiHelpers('getMatrixType', data.analysis, 'node_op_0');
assert(ismember(quadrant, {'TYPE_A', 'TYPE_B', 'TYPE_C', 'TYPE_D'}));
```

---

## 16. Final Status

### ✅ Python/API: COMPLETE
- Enum serialization fixed (TYPE_A format)
- HTTP status codes implemented
- Async file I/O with aiofiles
- Request validation with Pydantic
- Path resolution with multiple strategies
- Specific exception handling
- Better logging in enhanced sections

### ⏳ MATLAB: TODO (~3 hours work)
- Update enum string matching (HIGH)
- Add HTTP status code handling (HIGH)
- Update error response parsing (HIGH)
- Remove deprecated code (MEDIUM)
- Clean up fallback field names (MEDIUM)
- Fix default values (MEDIUM)
- Optimize performance (MEDIUM)
- Update tests (LOW)

### 🎯 Next Steps:
1. Install Python dependencies: `uv sync`
2. Restart Python API server
3. Apply MATLAB fixes (Section 15)
4. Run integration tests
5. Update documentation

---

**Python Status:** ✅ DONE
**MATLAB Status:** ⏳ PENDING
**Overall Progress:** 60% complete (Python done, MATLAB remaining)

