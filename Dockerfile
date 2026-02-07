# --- Stage 1: Build C++ Core ---
FROM ubuntu:22.04 AS cpp-builder

# Install build tools
RUN apt-get update && apt-get install -y \
    g++ \
    make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy build files
COPY Makefile ./
COPY src/services/agent/ops/tensor_ops.cpp src/services/agent/ops/tensor_ops.cpp

# Compile shared library
RUN make build

# --- Stage 2: Python Runtime ---
FROM python:3.11-slim

WORKDIR /app

# Copy compiled C++ library from builder
COPY --from=cpp-builder /build/libtensor_ops.so .

# Install system dependencies for runtime (if any)
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt pyproject.toml ./
RUN pip install --no-cache-dir -r requirements.txt litestar uvicorn

# Copy source code
COPY src/ ./src/

# Expose Litestar port
EXPOSE 8000

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV LIB_TENSOR_OPS_PATH=/app/libtensor_ops.so

# Start Litestar server
# We use uvicorn to serve the Litestar app
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
