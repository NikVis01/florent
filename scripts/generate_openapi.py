#!/usr/bin/env python3
"""
Generate OpenAPI JSON specification from Litestar app

This script extracts the OpenAPI schema from the Litestar application
and saves it to docs/openapi.json
"""

import json
import sys
from pathlib import Path

# Add src to path to import the app
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.main import app


def generate_openapi_spec(output_path: str = "docs/openapi.json"):
    """
    Generate OpenAPI specification from Litestar app

    Args:
        output_path: Path to save the OpenAPI JSON file
    """
    try:
        # Get OpenAPI schema from Litestar app
        # Litestar automatically generates OpenAPI schema via app.openapi_schema
        openapi_schema = app.openapi_schema

        # Ensure output directory exists
        output_file = Path(output_path)
        output_file.parent.mkdir(parents=True, exist_ok=True)

        # Write to file with pretty formatting
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(openapi_schema.to_schema(), f, indent=2, ensure_ascii=False)

        print(f"✅ OpenAPI specification generated successfully!")
        print(f"📄 Saved to: {output_file.absolute()}")
        print(f"📊 Endpoints: {len(openapi_schema.paths)}")
        print(f"🔖 Version: {openapi_schema.info.version}")

        # Print endpoint summary
        print("\n📍 Available endpoints:")
        for path, path_item in openapi_schema.paths.items():
            methods = []
            if path_item.get:
                methods.append("GET")
            if path_item.post:
                methods.append("POST")
            if path_item.put:
                methods.append("PUT")
            if path_item.delete:
                methods.append("DELETE")
            if path_item.patch:
                methods.append("PATCH")

            methods_str = ", ".join(methods)
            print(f"  {methods_str:20s} {path}")

        return True

    except Exception as e:
        print(f"❌ Error generating OpenAPI spec: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return False


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate OpenAPI JSON from Litestar app"
    )
    parser.add_argument(
        "-o", "--output",
        default="docs/openapi.json",
        help="Output path for OpenAPI JSON (default: docs/openapi.json)"
    )

    args = parser.parse_args()

    success = generate_openapi_spec(args.output)
    sys.exit(0 if success else 1)
