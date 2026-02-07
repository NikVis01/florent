#!/bin/bash
set -e

echo "--- 1. Updating requirements.txt from uv.lock ---"
if command -v uv &> /dev/null; then
    uv export --format requirements-txt --output-file requirements.txt --no-hashes --no-editable
else
    echo "Warning: 'uv' not found. Skipping requirements export."
fi

echo "--- 2. Building and Testing (C++ Core & Python Unit Tests) ---"
make build
uv run pytest tests/

echo "--- 3. Linting with ruff ---"
uv run ruff check src/

echo "--- 4. Generating OpenAPI Specification ---"
if [ -f "scripts/generate_openapi.py" ]; then
    uv run python scripts/generate_openapi.py -o docs/openapi.json
else
    echo "Warning: generate_openapi.py not found. Skipping OpenAPI generation."
fi

echo "--- 5. Rebuilding Docker Image ---"
docker build -t florent-engine .

echo "--- Maintenance Complete ---"
