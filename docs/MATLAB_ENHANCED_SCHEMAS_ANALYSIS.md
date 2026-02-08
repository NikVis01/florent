# MATLAB Enhanced Schemas Usage Analysis

**Generated:** 2026-02-08
**Purpose:** Identify which MATLAB functions should use enhanced schemas vs basic schemas

---

## Schema Types

### Basic Schemas (`load_florent_schemas`)
Located in: `docs/openapi_export/schemas/`
- `AnalysisRequest.json` - Request schema only

### Enhanced Schemas (`load_enhanced_schemas`)
Located in: `docs/openapi_export/schemas_enhanced/`
- `AnalysisOutput.json` - Full response schema (1958 lines)
- `GraphTopology.json` - Graph structure
- `RiskDistributions.json` - Risk data
- `MonteCarloParameters.json` - MC parameters
- `PropagationTrace.json` - Propagation data
- `DiscoveryMetadata.json` - Discovery metadata
- `EvaluationMetadata.json` - Evaluation metadata
- `ConfigurationSnapshot.json` - Config snapshot
- `GraphStatistics.json` - Graph statistics

---

## Current Usage Analysis

### ✅ CORRECT: Using Basic Schemas (for Requests)

| Function | Schema Used | Status | Notes |
|----------|------------|--------|-------|
| `buildAnalysisRequest.m` | `getSchemas()` → `AnalysisRequest` | ✅ Correct | Validates request structure |
| `validateRequest()` in `openapiHelpers.m` | `getSchemas()` → `AnalysisRequest` | ✅ Correct | Validates request structure |

### ❌ INCORRECT: Should Use Enhanced Schemas (for Responses)

| Function | Current Schema | Should Use | Issue |
|----------|---------------|------------|-------|
| `validateAnalysisResponse.m` | `getSchemas()` (basic) | `getEnhancedSchemas()` → `AnalysisOutput` | Only has basic schemas, missing AnalysisOutput validation |
| `openapiHelpers.m` (default) | `getSchemas()` (basic) | Should offer both | Most helpers work with responses, should validate against AnalysisOutput |

### ⚠️ PARTIAL: Using Enhanced Schemas (but not consistently)

| Function | Current Usage | Status | Notes |
|----------|--------------|--------|-------|
| `openapiHelpers('getEnhancedSchemas')` | `getEnhancedSchemas()` | ✅ Available | But not used by default |
| `monteCarloFramework.m` | References enhanced schemas | ⚠️ Partial | Uses data but doesn't validate against schemas |
| `plot2x2MatrixWithEllipses.m` | References enhanced schemas | ⚠️ Partial | Uses data but doesn't validate |
| `plot3DRiskLandscape.m` | References enhanced schemas | ⚠️ Partial | Uses data but doesn't validate |
| `plotStabilityNetwork.m` | References enhanced schemas | ⚠️ Partial | Uses data but doesn't validate |

---

## Issues Found

### 1. Response Validation Uses Wrong Schemas

**File:** `MATLAB/Functions/validateAnalysisResponse.m`

**Current Code:**
```matlab
schemas = openapiHelpers('getSchemas');  % ❌ Only gets basic schemas
```

**Problem:** 
- `getSchemas()` only loads `AnalysisRequest` schema
- Response validation should use `AnalysisOutput` from enhanced schemas
- Missing validation for enhanced sections (graph_topology, risk_distributions, etc.)

**Fix:**
```matlab
% Try to load enhanced schemas for response validation
try
    enhancedSchemas = openapiHelpers('getEnhancedSchemas');
    if ~isempty(enhancedSchemas) && isfield(enhancedSchemas, 'AnalysisOutput')
        % Use AnalysisOutput schema for validation
        outputSchema = enhancedSchemas.AnalysisOutput;
        % Validate against schema...
    end
catch
    % Fallback to basic validation
end
```

### 2. No Schema Validation for Enhanced Sections

**Files:** Multiple plotting and analysis functions

**Problem:**
- Functions access enhanced sections (graph_topology, risk_distributions, etc.)
- But don't validate structure against enhanced schemas
- Could fail silently if API returns unexpected structure

**Fix:**
- Add optional validation using enhanced schemas
- Validate before accessing enhanced sections

### 3. Inconsistent Schema Access

**File:** `MATLAB/Functions/openapiHelpers.m`

**Problem:**
- `getSchemas()` is the default (basic schemas)
- `getEnhancedSchemas()` exists but is rarely used
- No unified way to get both schemas

**Fix:**
- Consider making `getSchemas()` return both basic and enhanced schemas
- Or add `getAllSchemas()` that combines both

---

## Recommendations

### High Priority

1. **Update `validateAnalysisResponse.m`**
   - Use `getEnhancedSchemas()` to get `AnalysisOutput` schema
   - Validate response structure against `AnalysisOutput` schema
   - Validate enhanced sections against their respective schemas

2. **Add Enhanced Schema Validation**
   - Create helper function: `validateAgainstEnhancedSchema(data, sectionName)`
   - Use in functions that access enhanced sections

### Medium Priority

3. **Unify Schema Access**
   - Consider combining basic and enhanced schemas in one structure
   - Or make it clear when to use which

4. **Add Schema Validation to Enhanced Section Accessors**
   - Functions like `getGraphTopology()`, `getRiskDistributions()` should optionally validate
   - Use enhanced schemas for validation

### Low Priority

5. **Documentation**
   - Document when to use basic vs enhanced schemas
   - Add examples of schema validation

---

## Files That Need Updates

### Must Update (High Priority)

1. `MATLAB/Functions/validateAnalysisResponse.m`
   - Switch from `getSchemas()` to `getEnhancedSchemas()` for response validation
   - Add validation against `AnalysisOutput` schema

### Should Update (Medium Priority)

2. `MATLAB/Functions/openapiHelpers.m`
   - Add optional schema validation to enhanced section accessors
   - Consider unified schema access

3. Functions accessing enhanced sections:
   - `monteCarloFramework.m`
   - `plot2x2MatrixWithEllipses.m`
   - `plot3DRiskLandscape.m`
   - `plotStabilityNetwork.m`
   - `displayGlobe.m`

### Optional (Low Priority)

4. Documentation updates
   - Add schema usage examples
   - Document enhanced schema structure

---

## Summary

**Current State:**
- ✅ Request validation uses correct schemas (basic)
- ❌ Response validation uses wrong schemas (should use enhanced)
- ⚠️ Enhanced schemas available but underutilized
- ⚠️ No validation of enhanced sections against schemas

**Action Required:**
1. Update `validateAnalysisResponse.m` to use enhanced schemas
2. Add schema validation for enhanced sections
3. Consider unified schema access pattern

