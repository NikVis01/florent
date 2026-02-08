# Enhanced Output Schemas for MATLAB

## Overview

JSON schemas automatically generated from Pydantic dataclasses for all enhanced output sections.

## Usage

### Load All Schemas

```matlab
% Add to path
addpath('docs/openapi_export/matlab');

% Load all enhanced schemas
schemas = load_enhanced_schemas();

% Access specific schema
graph_schema = schemas.GraphTopology;
```

### Validate Data

```matlab
% Load analysis result
analysis = jsondecode(fileread('analysis_result.json'));

% Load schema
schemas = load_enhanced_schemas();

% Validate graph topology
if isfield(analysis, 'graph_topology')
    valid = validate_against_schema(analysis.graph_topology, ...
                                     schemas.GraphTopology);
    if valid
        fprintf('Graph topology is valid\n');
    end
end
```

### Extract Type Information

```matlab
% Get property types for GraphTopology
props = schemas.GraphTopology.properties;
fields = fieldnames(props);

for i = 1:length(fields)
    field_name = fields{i};
    field_schema = props.(field_name);

    fprintf('%s: %s\n', field_name, field_schema.type);

    if isfield(field_schema, 'description')
        fprintf('  Description: %s\n', field_schema.description);
    end
end
```

## Available Schemas

- `AnalysisOutput.json` - AnalysisOutput schema
- `GraphTopology.json` - GraphTopology schema
- `RiskDistributions.json` - RiskDistributions schema
- `PropagationTrace.json` - PropagationTrace schema
- `DiscoveryMetadata.json` - DiscoveryMetadata schema
- `EvaluationMetadata.json` - EvaluationMetadata schema
- `ConfigurationSnapshot.json` - ConfigurationSnapshot schema
- `MonteCarloParameters.json` - MonteCarloParameters schema
- `GraphStatistics.json` - GraphStatistics schema


## Schema Structure

All schemas follow JSON Schema Draft 2020-12 specification with:

- **Type definitions** - Data types for each field
- **Descriptions** - Documentation for each property
- **Constraints** - Minimum/maximum values, required fields
- **Nested definitions** - Referenced sub-schemas

## Integration with Analysis Output

The enhanced output from `/analyze` endpoint matches these schemas:

```json
{
  "analysis": {
    "graph_topology": <GraphTopology>,
    "risk_distributions": <RiskDistributions>,
    "propagation_trace": <PropagationTrace>,
    "discovery_metadata": <DiscoveryMetadata>,
    "evaluation_metadata": <EvaluationMetadata>,
    "configuration_snapshot": <ConfigurationSnapshot>,
    "graph_statistics": <GraphStatistics>,
    "monte_carlo_parameters": <MonteCarloParameters>
  }
}
```

## See Also

- [Enhanced Output Guide](../../ENHANCED_OUTPUT.md)
- [MATLAB Integration Guide](../README.md)
