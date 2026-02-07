#!/bin/bash
set -e

echo "--- 1. Updating requirements.txt from uv.lock ---"
if command -v uv &> /dev/null; then
    uv export --format requirements-txt --output-file requirements.txt --no-hashes --no-editable
else
    echo "Warning: 'uv' not found. Skipping requirements export."
fi

echo "--- 2. Building C++ Core ---"
g++ -fPIC -O3 -shared -o libtensor_ops.so src/services/agent/ops/tensor_ops.cpp

echo "--- 3. Running Python Tests ---"
uv run pytest tests/ -v

echo "--- 4. Linting with ruff ---"
uv run ruff check src/

echo "--- 5. Generating OpenAPI Specification ---"
if [ -f "scripts/generate_openapi.py" ]; then
    uv run python scripts/generate_openapi.py -o docs/openapi.json
else
    echo "Warning: generate_openapi.py not found. Skipping OpenAPI generation."
fi

echo "--- 6. Docker Image ---"
echo "Note: Run 'docker build -t florent-engine .' manually if needed (takes ~5 min)"

echo "--- Maintenance Complete ---"
