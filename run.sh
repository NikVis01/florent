#!/bin/bash
set -e

echo "Starting Florent API with BGE-M3 model..."
docker compose -f docker/docker-compose-api.yaml up --build