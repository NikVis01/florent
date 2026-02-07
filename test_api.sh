#!/bin/bash
# test_api.sh
# Usage: ./test_api.sh src/data/poc/firm.json src/data/poc/project.json

FIRM_FILE=${1:-src/data/poc/firm.json}
PROJECT_FILE=${2:-src/data/poc/project.json}

if [ ! -f "$FIRM_FILE" ]; then
    echo "Error: Firm file not found at $FIRM_FILE"
    exit 1
fi

if [ ! -f "$PROJECT_FILE" ]; then
    echo "Error: Project file not found at $PROJECT_FILE"
    exit 1
fi

echo "--- Sending Analysis Request ---"
echo "Firm: $FIRM_FILE"
echo "Project: $PROJECT_FILE"

# Construct JSON payload with file contents
PAYLOAD=$(jq -n \
    --slurpfile firm "$FIRM_FILE" \
    --slurpfile project "$PROJECT_FILE" \
    '{firm_data: $firm[0], project_data: $project[0], budget: 100}')

curl -X POST http://localhost:8000/analyze \
     -H "Content-Type: application/json" \
     -d "$PAYLOAD" | jq .
