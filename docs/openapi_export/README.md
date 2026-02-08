# Florent API Schemas for MATLAB

## Usage

1. Add this directory to your MATLAB path:
   ```matlab
   addpath('path/to/openapi_export/matlab');
   ```

2. Load all schemas:
   ```matlab
   schemas = load_florent_schemas();
   ```

3. Access specific schemas:
   ```matlab
   % Get AnalysisRequest schema
   request_schema = schemas.schemas.AnalysisRequest.schema;
   request_example = schemas.schemas.AnalysisRequest.example;

   % Get analyze endpoint structure
   analyze = schemas.endpoints.AnalyzeAnalyzeProject;
   fprintf('Endpoint: %s %s\n', analyze.method, analyze.path);
   ```

4. Create API request:
   ```matlab
   % Create request JSON
   json_str = create_analysis_request('data/firm.json', 'data/project.json', 100);

   % Send to API
   options = weboptions('RequestMethod', 'post', 'MediaType', 'application/json');
   response = webwrite('http://localhost:8000/analyze', json_str, options);
   ```

## Directory Structure

- `schemas/` - Individual schema definitions with examples
- `endpoints/` - Endpoint request/response structures
- `matlab/` - MATLAB helper functions

## Files

### Schemas
- `schemas/AnalysisRequest.json` - AnalysisRequest schema

### Endpoints
- `endpoints/HealthCheck.json` - HealthCheck endpoint
- `endpoints/AnalyzeAnalyzeProject.json` - AnalyzeAnalyzeProject endpoint
