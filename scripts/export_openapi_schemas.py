#!/usr/bin/env python3
"""
Export OpenAPI schemas to individual JSON files for MATLAB integration.

Extracts all schemas, request/response structures from OpenAPI spec and
generates individual JSON files with examples for each dataclass.
"""

import json
import argparse
from pathlib import Path
from typing import Any, Dict, List
import sys

# Add src to path
sys.path.append(str(Path(__file__).parent.parent))


def generate_example_from_schema(schema: Dict[str, Any], depth: int = 0) -> Any:
    """
    Generate example data from a JSON schema.

    Args:
        schema: JSON schema object
        depth: Current recursion depth (prevent infinite recursion)

    Returns:
        Example value matching the schema
    """
    if depth > 10:  # Prevent infinite recursion
        return None

    schema_type = schema.get("type")

    # Handle oneOf/anyOf
    if "oneOf" in schema:
        # Pick first non-null option
        for option in schema["oneOf"]:
            if option.get("type") != "null":
                return generate_example_from_schema(option, depth + 1)
        return None

    if "anyOf" in schema:
        for option in schema["anyOf"]:
            if option.get("type") != "null":
                return generate_example_from_schema(option, depth + 1)
        return None

    # Handle references
    if "$ref" in schema:
        return f"<ref: {schema['$ref']}>"

    # Handle by type
    if schema_type == "string":
        enum = schema.get("enum")
        if enum:
            return enum[0]
        return schema.get("default", "example_string")

    elif schema_type == "integer":
        return schema.get("default", 100)

    elif schema_type == "number":
        return schema.get("default", 0.5)

    elif schema_type == "boolean":
        return schema.get("default", True)

    elif schema_type == "array":
        items_schema = schema.get("items", {})
        return [generate_example_from_schema(items_schema, depth + 1)]

    elif schema_type == "object":
        properties = schema.get("properties", {})
        required = schema.get("required", [])

        obj = {}
        for prop_name, prop_schema in properties.items():
            # Only include required fields or if has default
            if prop_name in required or "default" in prop_schema:
                obj[prop_name] = generate_example_from_schema(prop_schema, depth + 1)

        return obj

    elif isinstance(schema_type, list):
        # Multiple types allowed - pick first non-null
        for t in schema_type:
            if t != "null":
                return generate_example_from_schema({"type": t}, depth + 1)
        return None

    return None


def export_component_schemas(openapi_spec: Dict[str, Any], output_dir: Path) -> Dict[str, Path]:
    """
    Export all component schemas to individual JSON files.

    Args:
        openapi_spec: OpenAPI specification dictionary
        output_dir: Directory to save schema files

    Returns:
        Dictionary mapping schema name to file path
    """
    schemas_dir = output_dir / "schemas"
    schemas_dir.mkdir(parents=True, exist_ok=True)

    components = openapi_spec.get("components", {})
    schemas = components.get("schemas", {})

    exported = {}

    for schema_name, schema_def in schemas.items():
        # Generate schema file
        schema_file = schemas_dir / f"{schema_name}.json"

        output = {
            "name": schema_name,
            "schema": schema_def,
            "example": generate_example_from_schema(schema_def)
        }

        with open(schema_file, "w") as f:
            json.dump(output, f, indent=2)

        exported[schema_name] = schema_file
        print(f"[OK] Exported schema: {schema_name}")

    return exported


def export_endpoint_structures(openapi_spec: Dict[str, Any], output_dir: Path) -> List[Path]:
    """
    Export request/response structures for each endpoint.

    Args:
        openapi_spec: OpenAPI specification dictionary
        output_dir: Directory to save endpoint files

    Returns:
        List of exported file paths
    """
    endpoints_dir = output_dir / "endpoints"
    endpoints_dir.mkdir(parents=True, exist_ok=True)

    paths = openapi_spec.get("paths", {})
    exported = []

    for path, path_item in paths.items():
        for method, operation in path_item.items():
            if method.upper() not in ["GET", "POST", "PUT", "PATCH", "DELETE"]:
                continue

            operation_id = operation.get("operationId", f"{method}_{path.replace('/', '_')}")

            endpoint_data = {
                "path": path,
                "method": method.upper(),
                "operationId": operation_id,
                "summary": operation.get("summary", ""),
                "request": None,
                "responses": {}
            }

            # Extract request body schema
            request_body = operation.get("requestBody", {})
            if request_body:
                content = request_body.get("content", {})
                for content_type, content_schema in content.items():
                    schema = content_schema.get("schema", {})
                    endpoint_data["request"] = {
                        "content_type": content_type,
                        "schema": schema,
                        "example": generate_example_from_schema(schema),
                        "required": request_body.get("required", False)
                    }
                    break  # Take first content type

            # Extract response schemas
            responses = operation.get("responses", {})
            for status_code, response_def in responses.items():
                content = response_def.get("content", {})
                response_data = {
                    "description": response_def.get("description", ""),
                    "schemas": {}
                }

                for content_type, content_schema in content.items():
                    schema = content_schema.get("schema", {})
                    response_data["schemas"][content_type] = {
                        "schema": schema,
                        "example": generate_example_from_schema(schema)
                    }

                endpoint_data["responses"][status_code] = response_data

            # Save endpoint file
            endpoint_file = endpoints_dir / f"{operation_id}.json"
            with open(endpoint_file, "w") as f:
                json.dump(endpoint_data, f, indent=2)

            exported.append(endpoint_file)
            print(f"[OK] Exported endpoint: {method.upper()} {path}")

    return exported


def generate_matlab_loader(output_dir: Path, schema_files: Dict[str, Path], endpoint_files: List[Path]):
    """
    Generate MATLAB helper script to load JSON schemas.

    Args:
        output_dir: Output directory
        schema_files: Dictionary of schema name to file path
        endpoint_files: List of endpoint file paths
    """
    matlab_dir = output_dir / "matlab"
    matlab_dir.mkdir(parents=True, exist_ok=True)

    matlab_script = """function schemas = load_florent_schemas()
    % LOAD_FLORENT_SCHEMAS Load all Florent API schemas
    %
    % Returns:
    %   schemas - Struct containing all API schemas and endpoints
    %
    % Example:
    %   schemas = load_florent_schemas();
    %   request_schema = schemas.schemas.AnalysisRequest.schema;
    %   analyze_endpoint = schemas.endpoints.AnalyzeAnalyzeProject;

    % Get directory of this script
    script_dir = fileparts(mfilename('fullpath'));
    base_dir = fullfile(script_dir, '..');

    % Load component schemas
    schemas.schemas = struct();
"""

    for schema_name in schema_files.keys():
        matlab_script += f"""
    try
        schemas.schemas.{schema_name} = jsondecode(fileread(fullfile(base_dir, 'schemas', '{schema_name}.json')));
    catch
        warning('Failed to load schema: {schema_name}');
    end
"""

    matlab_script += """

    % Load endpoint structures
    schemas.endpoints = struct();
"""

    for endpoint_file in endpoint_files:
        endpoint_name = endpoint_file.stem
        matlab_script += f"""
    try
        schemas.endpoints.{endpoint_name} = jsondecode(fileread(fullfile(base_dir, 'endpoints', '{endpoint_name}.json')));
    catch
        warning('Failed to load endpoint: {endpoint_name}');
    end
"""

    matlab_script += """

    fprintf('[OK] Loaded %d schemas and %d endpoints\\n', ...
        length(fieldnames(schemas.schemas)), ...
        length(fieldnames(schemas.endpoints)));

end


function example_json = create_analysis_request(firm_path, project_path, budget)
    % CREATE_ANALYSIS_REQUEST Create analysis request JSON
    %
    % Args:
    %   firm_path - Path to firm.json
    %   project_path - Path to project.json
    %   budget - Evaluation budget (default: 100)
    %
    % Returns:
    %   example_json - JSON string ready to send to API

    if nargin < 3
        budget = 100;
    end

    request = struct();
    request.firm_path = firm_path;
    request.project_path = project_path;
    request.budget = budget;

    example_json = jsonencode(request);
end
"""

    matlab_file = matlab_dir / "load_florent_schemas.m"
    with open(matlab_file, "w") as f:
        f.write(matlab_script)

    print(f"[OK] Generated MATLAB loader: {matlab_file}")

    # Create README for MATLAB
    readme = """# Florent API Schemas for MATLAB

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
   fprintf('Endpoint: %s %s\\n', analyze.method, analyze.path);
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

"""

    readme += "### Schemas\n"
    for schema_name in schema_files.keys():
        readme += f"- `schemas/{schema_name}.json` - {schema_name} schema\n"

    readme += "\n### Endpoints\n"
    for endpoint_file in endpoint_files:
        readme += f"- `endpoints/{endpoint_file.name}` - {endpoint_file.stem} endpoint\n"

    readme_file = output_dir / "README.md"
    with open(readme_file, "w") as f:
        f.write(readme)

    print(f"[OK] Generated README: {readme_file}")


def export_summary(output_dir: Path, schema_files: Dict[str, Path], endpoint_files: List[Path]):
    """Generate summary of exported files."""
    summary = {
        "total_schemas": len(schema_files),
        "total_endpoints": len(endpoint_files),
        "schemas": {name: str(path.relative_to(output_dir)) for name, path in schema_files.items()},
        "endpoints": [str(path.relative_to(output_dir)) for path in endpoint_files],
        "output_directory": str(output_dir)
    }

    summary_file = output_dir / "export_summary.json"
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)

    print(f"\n[OK] Export summary: {summary_file}")


def main():
    parser = argparse.ArgumentParser(
        description="Export OpenAPI schemas to individual JSON files for MATLAB"
    )
    parser.add_argument(
        "-i", "--input",
        default="docs/openapi.json",
        help="Input OpenAPI spec file (default: docs/openapi.json)"
    )
    parser.add_argument(
        "-o", "--output",
        default="docs/openapi_export",
        help="Output directory (default: docs/openapi_export)"
    )

    args = parser.parse_args()

    # Load OpenAPI spec
    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[ERROR] Error: OpenAPI spec not found: {input_path}")
        return 1

    with open(input_path, "r") as f:
        openapi_spec = json.load(f)

    output_dir = Path(args.output)

    print(f" Reading OpenAPI spec: {input_path}")
    print(f" Output directory: {output_dir}")
    print()

    # Export component schemas
    print("Exporting component schemas...")
    schema_files = export_component_schemas(openapi_spec, output_dir)
    print()

    # Export endpoint structures
    print("Exporting endpoint structures...")
    endpoint_files = export_endpoint_structures(openapi_spec, output_dir)
    print()

    # Generate MATLAB helpers
    print("Generating MATLAB helpers...")
    generate_matlab_loader(output_dir, schema_files, endpoint_files)
    print()

    # Generate summary
    export_summary(output_dir, schema_files, endpoint_files)

    print("\n" + "="*60)
    print("[SUCCESS] Export complete!")
    print("="*60)
    print(f"\n Exported:")
    print(f"   - {len(schema_files)} schemas")
    print(f"   - {len(endpoint_files)} endpoints")
    print(f"\n Output: {output_dir}/")
    print(f"\n MATLAB Usage:")
    print(f"   >> addpath('{output_dir}/matlab')")
    print(f"   >> schemas = load_florent_schemas();")

    return 0


if __name__ == "__main__":
    sys.exit(main())
