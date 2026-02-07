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

echo "--- 3. Linting with ruff ---"
uv run ruff check src/

echo "--- Maintenance Complete ---"
