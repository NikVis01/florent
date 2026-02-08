#!/usr/bin/env python3
"""
Export JSON schemas directly from Pydantic dataclasses.

Uses Pydantic's built-in schema generation to export structured JSON schemas
for all enhanced output sections.
"""

import json
import argparse
from pathlib import Path
from typing import Any, Dict
import sys

# Add src to path
sys.path.append(str(Path(__file__).parent.parent))


def export_pydantic_schemas(output_dir: Path):
    """Export JSON schemas from Pydantic models."""
    # Import all the enhanced models
    from src.models.graph_topology import GraphTopology
    from src.models.risk_distributions import RiskDistributions
    from src.models.propagation_trace import PropagationTrace
    from src.models.discovery_metadata import DiscoveryMetadata
    from src.models.evaluation_metadata import EvaluationMetadata
    from src.models.config_snapshot import ConfigurationSnapshot
    from src.models.monte_carlo import MonteCarloParameters, GraphStatistics
    from src.models.analysis import AnalysisOutput

    # Define models to export
    models = {
        "AnalysisOutput": AnalysisOutput,
        "GraphTopology": GraphTopology,
        "RiskDistributions": RiskDistributions,
        "PropagationTrace": PropagationTrace,
        "DiscoveryMetadata": DiscoveryMetadata,
        "EvaluationMetadata": EvaluationMetadata,
        "ConfigurationSnapshot": ConfigurationSnapshot,
        "MonteCarloParameters": MonteCarloParameters,
        "GraphStatistics": GraphStatistics,
    }

    schemas_dir = output_dir / "schemas_enhanced"
    schemas_dir.mkdir(parents=True, exist_ok=True)

    exported = {}

    for name, model in models.items():
        try:
            # Generate JSON schema from Pydantic model
            schema = model.model_json_schema()

            # Write to file
            schema_file = schemas_dir / f"{name}.json"
            with open(schema_file, "w") as f:
                json.dump(schema, f, indent=2)

            exported[name] = str(schema_file.relative_to(output_dir))
            print(f"[OK] Exported: {name}")

        except Exception as e:
            print(f"[ERROR] Failed to export {name}: {e}")

    # Create index file
    index = {
        "schemas": exported,
        "description": "JSON schemas generated from Pydantic dataclasses",
        "generator": "Pydantic model_json_schema()"
    }

    index_file = schemas_dir / "index.json"
    with open(index_file, "w") as f:
        json.dump(index, f, indent=2)

    print(f"\n[OK] Schema index: {index_file}")

    return exported


def generate_matlab_schema_loader(output_dir: Path, schemas: Dict[str, str]):
    """Generate MATLAB function to load JSON schemas."""
    matlab_dir = output_dir / "matlab"
    matlab_dir.mkdir(parents=True, exist_ok=True)

    matlab_code = """function schemas = load_enhanced_schemas()
    % LOAD_ENHANCED_SCHEMAS Load all enhanced output JSON schemas
    %
    % Returns:
    %   schemas - Struct containing all enhanced section schemas
    %
    % Example:
    %   schemas = load_enhanced_schemas();
    %   graph_schema = schemas.GraphTopology;

    % Get directory of this script
    script_dir = fileparts(mfilename('fullpath'));
    base_dir = fullfile(script_dir, '..', 'schemas_enhanced');

"""

    for name in schemas.keys():
        matlab_code += f"""
    try
        schemas.{name} = jsondecode(fileread(fullfile(base_dir, '{name}.json')));
    catch
        warning('Failed to load schema: {name}');
        schemas.{name} = struct();
    end
"""

    matlab_code += """

    fprintf('[OK] Loaded %d enhanced schemas\\n', length(fieldnames(schemas)));

end


function valid = validate_against_schema(data, schema)
    % VALIDATE_AGAINST_SCHEMA Validate data against JSON schema
    %
    % Args:
    %   data - Data structure to validate
    %   schema - JSON schema structure
    %
    % Returns:
    %   valid - Boolean indicating if data is valid

    % Basic validation (simplified)
    % For full validation, use external library like jsonschema

    valid = true;

    if ~isstruct(data) && ~isobject(data)
        valid = false;
        return;
    end

    % Check required fields
    if isfield(schema, 'required')
        required_fields = schema.required;
        for i = 1:length(required_fields)
            field = required_fields{i};
            if ~isfield(data, field)
                warning('Missing required field: %s', field);
                valid = false;
            end
        end
    end

end
"""

    matlab_file = matlab_dir / "load_enhanced_schemas.m"
    with open(matlab_file, "w") as f:
        f.write(matlab_code)

    print(f"[OK] Generated: {matlab_file}")

    # Create README
    readme = """# Enhanced Output Schemas for MATLAB

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
        fprintf('Graph topology is valid\\n');
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

    fprintf('%s: %s\\n', field_name, field_schema.type);

    if isfield(field_schema, 'description')
        fprintf('  Description: %s\\n', field_schema.description);
    end
end
```

## Available Schemas

"""

    for name in schemas.keys():
        readme += f"- `{name}.json` - {name} schema\n"

    readme += """

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
"""

    readme_file = output_dir / "schemas_enhanced" / "README.md"
    with open(readme_file, "w") as f:
        f.write(readme)

    print(f"[OK] Generated: {readme_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Export JSON schemas from Pydantic dataclasses"
    )
    parser.add_argument(
        "-o", "--output",
        default="docs/openapi_export",
        help="Output directory (default: docs/openapi_export)"
    )

    args = parser.parse_args()
    output_dir = Path(args.output)

    print(f"Output directory: {output_dir}")
    print()

    # Export schemas
    print("Exporting Pydantic schemas...")
    schemas = export_pydantic_schemas(output_dir)
    print()

    # Generate MATLAB helpers
    print("Generating MATLAB helpers...")
    generate_matlab_schema_loader(output_dir, schemas)
    print()

    print("="*60)
    print("[SUCCESS] Schema export complete!")
    print("="*60)
    print(f"\n Exported {len(schemas)} schemas")
    print(f"\n Output: {output_dir}/schemas_enhanced/")
    print(f"\n MATLAB Usage:")
    print(f"   >> addpath('{output_dir}/matlab')")
    print(f"   >> schemas = load_enhanced_schemas();")

    return 0


if __name__ == "__main__":
    sys.exit(main())
