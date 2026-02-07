#!/bin/bash
set -e

echo "--- 1. Updating requirements.txt from uv.lock ---"
if command -v uv &> /dev/null; then
    uv export --format requirements-txt --output-file requirements.txt
else
    echo "Warning: 'uv' not found. Skipping requirements export."
fi

echo "--- 2. Building and Testing (C++ Core & Python) ---"
make all

echo "--- 4. Linting with ruff ---"
if command -v ruff &> /dev/null; then
    ruff check src/
else
    # Fallback to python -m ruff if installed in venv
    python3 -m ruff check src/ || echo "Warning: ruff not found. Skipping linting."
fi

echo "--- Maintenance Complete ---"
