# Florent Setup Guide

**Complete installation and configuration guide for Project Florent**

**Version**: 1.0.0
**Last Updated**: 2026-02-07
**Estimated Setup Time**: 15-30 minutes

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Detailed Installation](#detailed-installation)
4. [Configuration](#configuration)
5. [Running the Application](#running-the-application)
6. [Testing](#testing)
7. [Development Setup](#development-setup)
8. [Production Deployment](#production-deployment)
9. [Troubleshooting](#troubleshooting)
10. [Next Steps](#next-steps)

---

## ⚡ Quick Start (5 Minutes)

**For experienced developers who want to get running immediately:**

```bash
# Clone repository
git clone <repository-url>
cd florent

# Install dependencies with uv
curl -LsSf https://astral.sh/uv/install.sh | sh  # Install uv if needed
uv sync

# Set environment variables
export OPENAI_API_KEY="sk-your-key-here"

# Run tests to verify installation
uv run pytest tests/ -v

# Start server
uv run litestar run --host 0.0.0.0 --port 8000 --reload

# Test API (in another terminal)
curl http://localhost:8000/
```

**Access**:
- API: http://localhost:8000
- Swagger UI: http://localhost:8000/schema/swagger
- Health Check: http://localhost:8000/

**Done!** Skip to [Testing](#testing) or [Next Steps](#next-steps).

---

## 📦 Prerequisites

### Required Software

#### 1. **Python 3.11+**
```bash
# Check Python version
python --version  # Should be 3.11 or higher

# If not installed:
# Ubuntu/Debian
sudo apt update && sudo apt install python3.11 python3.11-venv

# macOS (with Homebrew)
brew install python@3.11

# Windows
# Download from https://www.python.org/downloads/
```

#### 2. **uv** (Package Manager)
```bash
# Install uv (recommended)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Verify installation
uv --version

# Alternative: Use pip if you prefer
# pip install uv
```

#### 3. **Git**
```bash
# Check if installed
git --version

# If not installed:
# Ubuntu/Debian
sudo apt install git

# macOS
brew install git

# Windows
# Download from https://git-scm.com/downloads
```

#### 4. **OpenAI API Key** (Required for AI features)
- Sign up at https://platform.openai.com/
- Generate API key at https://platform.openai.com/api-keys
- **Pricing**: Pay-as-you-go (~$0.01-0.10 per analysis)
- **Alternative**: Use mock mode for development (see Configuration)

### Optional Software

#### 5. **Docker & Docker Compose** (For containerized deployment)
```bash
# Check if installed
docker --version
docker-compose --version

# Install Docker:
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# macOS
brew install --cask docker

# Windows
# Download Docker Desktop from https://www.docker.com/products/docker-desktop
```

#### 6. **Make** (For build automation)
```bash
# Check if installed
make --version

# Ubuntu/Debian
sudo apt install build-essential

# macOS (usually pre-installed)
xcode-select --install

# Windows
# Install via MSYS2 or use WSL
```

### System Requirements

**Minimum**:
- CPU: 2 cores
- RAM: 4 GB
- Disk: 2 GB free space
- OS: Linux, macOS, Windows (with WSL recommended)

**Recommended**:
- CPU: 4+ cores
- RAM: 8 GB+
- Disk: 5 GB+ free space
- OS: Linux or macOS

---

## 🚀 Detailed Installation

### Step 1: Clone Repository

```bash
# Clone the repository
git clone <repository-url>
cd florent

# Verify you're in the right directory
ls -la
# Should see: src/, tests/, docs/, README.md, etc.
```

### Step 2: Install Dependencies

#### Option A: Using `uv` (Recommended)

```bash
# Install all dependencies
uv sync

# This creates a virtual environment at .venv/
# and installs all packages from uv.lock

# Verify installation
uv run python --version
uv run python -c "import litestar; print(litestar.__version__)"
```

#### Option B: Using `pip` + `venv`

```bash
# Create virtual environment
python -m venv .venv

# Activate virtual environment
# Linux/macOS:
source .venv/bin/activate
# Windows:
.venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Verify installation
python --version
python -c "import litestar; print(litestar.__version__)"
```

### Step 3: Verify Installation

```bash
# Check installed packages
uv pip list

# Should see key packages:
# - litestar
# - dspy-ai
# - pydantic
# - structlog
# - pytest
# - numpy
```

### Step 4: Set Up Environment Variables

#### Option A: Create `.env` file (Recommended)

```bash
# Copy example environment file
cp .env.example .env

# Edit .env file
nano .env  # or use your preferred editor
```

**Add to `.env`**:
```bash
# Required
OPENAI_API_KEY=sk-your-actual-api-key-here

# Optional (defaults shown)
LOG_LEVEL=INFO
HOST=0.0.0.0
PORT=8000
PYTHONPATH=.
```

#### Option B: Export Environment Variables

```bash
# Linux/macOS
export OPENAI_API_KEY="sk-your-actual-api-key-here"
export LOG_LEVEL="INFO"
export HOST="0.0.0.0"
export PORT="8000"

# Add to ~/.bashrc or ~/.zshrc for persistence
echo 'export OPENAI_API_KEY="sk-your-key"' >> ~/.bashrc
source ~/.bashrc

# Windows (PowerShell)
$env:OPENAI_API_KEY="sk-your-actual-api-key-here"
$env:LOG_LEVEL="INFO"
```

### Step 5: Verify OpenAI API Key

```bash
# Test API key
uv run python -c "
import os
from openai import OpenAI

client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
print('✅ OpenAI API key is valid')
"

# If this fails, check your API key
```

---

## ⚙️ Configuration

### Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `OPENAI_API_KEY` | **Yes** | None | OpenAI API key for DSPy agents |
| `LOG_LEVEL` | No | `INFO` | Logging level: DEBUG, INFO, WARNING, ERROR |
| `HOST` | No | `0.0.0.0` | Server host address |
| `PORT` | No | `8000` | Server port |
| `PYTHONPATH` | No | `.` | Python module search path |

### Configuration Files

#### `src/settings.py`
Main configuration file for application settings:

```python
# View current settings
uv run python -c "
from src.settings import get_settings
settings = get_settings()
print(f'Log Level: {settings.log_level}')
print(f'Host: {settings.host}')
print(f'Port: {settings.port}')
"
```

#### `pyproject.toml`
Project metadata and dependencies:

```bash
# View project info
cat pyproject.toml
```

#### `uv.lock`
Locked dependency versions (don't edit manually):

```bash
# Update dependencies
uv sync --upgrade

# Export to requirements.txt
uv export --format requirements-txt --output-file requirements.txt --no-hashes
```

---

## 🏃 Running the Application

### Development Server (With Auto-Reload)

```bash
# Start development server
uv run litestar run --host 0.0.0.0 --port 8000 --reload

# Server will start at http://localhost:8000
# Auto-reloads on code changes
```

**Output**:
```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

### Production Server (No Auto-Reload)

```bash
# Using uvicorn directly
uv run uvicorn src.main:app --host 0.0.0.0 --port 8000 --workers 4

# Or using gunicorn (for better production performance)
uv run gunicorn src.main:app --workers 4 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

### Using the Run Script

```bash
# Make script executable
chmod +x run.sh

# Run server
./run.sh

# Or with custom port
PORT=9000 ./run.sh
```

### Verify Server Is Running

```bash
# Health check
curl http://localhost:8000/

# Expected output:
# "Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."

# Check OpenAPI documentation
curl http://localhost:8000/schema/openapi.json

# Open Swagger UI in browser
open http://localhost:8000/schema/swagger  # macOS
xdg-open http://localhost:8000/schema/swagger  # Linux
start http://localhost:8000/schema/swagger  # Windows
```

---

## 🧪 Testing

### Run All Tests

```bash
# Run complete test suite (264 tests)
uv run pytest tests/ -v

# Expected output:
# ======================== 264 passed in 2.50s ========================
```

### Run Specific Test Modules

```bash
# API tests only (19 tests)
uv run pytest tests/test_api.py -v

# Core logic tests
uv run pytest tests/test_orchestrator.py -v

# Graph tests
uv run pytest tests/test_graph.py -v

# End-to-end tests
uv run pytest tests/test_e2e_workflow.py -v
```

### Run Tests with Coverage

```bash
# Generate coverage report
uv run pytest tests/ --cov=src --cov-report=html --cov-report=term

# View HTML coverage report
open htmlcov/index.html  # macOS
xdg-open htmlcov/index.html  # Linux
start htmlcov/index.html  # Windows
```

### Run Tests in Watch Mode

```bash
# Install pytest-watch
uv add --dev pytest-watch

# Run tests on file changes
uv run ptw tests/
```

### Run API Tests (Shell Script)

```bash
# Make script executable
chmod +x test_api.sh

# Run API tests
./test_api.sh

# Expected output:
# ✅ Health check passed
# ✅ Analysis endpoint works
# ✅ All tests passed
```

---

## 💻 Development Setup

### IDE Configuration

#### **Visual Studio Code**

1. **Install Python Extension**
   ```bash
   code --install-extension ms-python.python
   ```

2. **Configure Python Interpreter**
   - Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
   - Type "Python: Select Interpreter"
   - Choose `.venv/bin/python`

3. **Recommended Settings** (`.vscode/settings.json`):
   ```json
   {
     "python.defaultInterpreterPath": "${workspaceFolder}/.venv/bin/python",
     "python.testing.pytestEnabled": true,
     "python.testing.unittestEnabled": false,
     "python.linting.enabled": true,
     "python.linting.ruffEnabled": true,
     "python.formatting.provider": "black",
     "[python]": {
       "editor.formatOnSave": true,
       "editor.codeActionsOnSave": {
         "source.organizeImports": true
       }
     }
   }
   ```

#### **PyCharm**

1. **Open Project**: File → Open → Select `florent/` directory
2. **Configure Interpreter**:
   - Settings → Project → Python Interpreter
   - Add Interpreter → Existing Environment
   - Select `.venv/bin/python`
3. **Enable pytest**:
   - Settings → Tools → Python Integrated Tools
   - Testing → Default test runner → pytest

### Linting and Formatting

```bash
# Run ruff linter
uv run ruff check src/

# Auto-fix linting issues
uv run ruff check --fix src/

# Format code
uv run ruff format src/

# Check types (if using mypy)
uv run mypy src/
```

### Pre-commit Hooks (Optional)

```bash
# Install pre-commit
uv add --dev pre-commit

# Install hooks
uv run pre-commit install

# Run hooks manually
uv run pre-commit run --all-files
```

### Development Workflow

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes to code
# ... edit files ...

# 3. Run tests
uv run pytest tests/ -v

# 4. Lint code
uv run ruff check src/

# 5. Commit changes
git add .
git commit -m "feat: Add my feature"

# 6. Push and create PR
git push -u origin feature/my-feature
```

---

## 🐳 Production Deployment

### Docker Deployment

#### Build Docker Image

```bash
# Build image
docker build -t florent-engine .

# Verify image
docker images | grep florent
```

#### Run Docker Container

```bash
# Run container
docker run -d \
  --name florent \
  -p 8000:8000 \
  -e OPENAI_API_KEY="sk-your-key" \
  -e LOG_LEVEL="INFO" \
  florent-engine

# Check logs
docker logs -f florent

# Stop container
docker stop florent

# Remove container
docker rm florent
```

#### Docker Compose (Recommended)

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f florent

# Stop services
docker-compose down

# Rebuild and restart
docker-compose up -d --build
```

**`docker-compose.yml`** (already included):
```yaml
version: '3.8'

services:
  florent:
    build: .
    ports:
      - "8000:8000"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Cloud Deployment

#### **AWS (EC2 + Docker)**

```bash
# 1. Launch EC2 instance (Ubuntu 22.04, t3.medium)
# 2. SSH into instance
ssh -i key.pem ubuntu@<instance-ip>

# 3. Install Docker
sudo apt update
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 4. Clone and run
git clone <repo-url>
cd florent
export OPENAI_API_KEY="sk-your-key"
docker-compose up -d

# 5. Configure security group to allow port 8000
```

#### **Google Cloud Run**

```bash
# 1. Build and push to GCR
gcloud builds submit --tag gcr.io/PROJECT_ID/florent

# 2. Deploy to Cloud Run
gcloud run deploy florent \
  --image gcr.io/PROJECT_ID/florent \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars OPENAI_API_KEY=sk-your-key
```

#### **DigitalOcean App Platform**

```bash
# 1. Connect GitHub repository
# 2. Add environment variable: OPENAI_API_KEY
# 3. Deploy automatically on git push
```

### Reverse Proxy (NGINX)

```nginx
# /etc/nginx/sites-available/florent

server {
    listen 80;
    server_name florent.example.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/florent /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### SSL/TLS (Let's Encrypt)

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d florent.example.com

# Auto-renewal is configured automatically
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. **"ModuleNotFoundError: No module named 'litestar'"**

**Problem**: Dependencies not installed

**Solution**:
```bash
# Reinstall dependencies
uv sync

# Or if using pip
pip install -r requirements.txt

# Verify installation
uv run python -c "import litestar; print('✅ OK')"
```

#### 2. **"OpenAI API key not found"**

**Problem**: Environment variable not set

**Solution**:
```bash
# Check if set
echo $OPENAI_API_KEY

# If empty, set it
export OPENAI_API_KEY="sk-your-key"

# Add to .env file for persistence
echo "OPENAI_API_KEY=sk-your-key" >> .env
```

#### 3. **"Address already in use (port 8000)"**

**Problem**: Another process using port 8000

**Solution**:
```bash
# Find process using port
lsof -i :8000  # macOS/Linux
netstat -ano | findstr :8000  # Windows

# Kill process
kill -9 <PID>  # macOS/Linux
taskkill /PID <PID> /F  # Windows

# Or use different port
uv run litestar run --port 8001
```

#### 4. **Tests failing with "Connection refused"**

**Problem**: Server not running or wrong port

**Solution**:
```bash
# Make sure server is running
curl http://localhost:8000/

# If not running, start it in another terminal
uv run litestar run --reload

# Then run tests
uv run pytest tests/test_api.py -v
```

#### 5. **"ImportError: cannot import name 'X' from 'src.Y'"**

**Problem**: PYTHONPATH not set correctly

**Solution**:
```bash
# Set PYTHONPATH
export PYTHONPATH=.

# Or add to .env
echo "PYTHONPATH=." >> .env

# Or run with explicit path
PYTHONPATH=. uv run pytest tests/
```

#### 6. **Docker build fails**

**Problem**: Missing dependencies or network issues

**Solution**:
```bash
# Clear Docker cache
docker system prune -a

# Rebuild with no cache
docker build --no-cache -t florent-engine .

# Check Dockerfile
cat Dockerfile
```

#### 7. **High memory usage**

**Problem**: Large graphs or memory leak

**Solution**:
```bash
# Limit budget parameter
# In analysis request, set budget=50 instead of 100

# Monitor memory
docker stats florent  # If using Docker

# Restart server periodically
```

---

## 🎯 Next Steps

### After Installation

✅ **You're all set!** Here's what to do next:

#### 1. **Test the API**
```bash
# Test health endpoint
curl http://localhost:8000/

# View API docs
open http://localhost:8000/schema/swagger
```

#### 2. **Run Example Analysis**
```bash
# Test with example data
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "examples/firm.json",
    "project_path": "examples/project.json",
    "budget": 50
  }'
```

#### 3. **Explore Documentation**
- [API Reference](API.md) - Complete API documentation
- [System Audit](audit.md) - Implementation status
- [Technical Roadmap](ROADMAP.md) - Mathematical foundations
- [INDEX](INDEX.md) - Documentation hub

#### 4. **Integrate with MATLAB** (Optional)
- [MATLAB Setup Guide](../MATLAB/SETUP.md)
- [MATLAB Functions](../MATLAB/README_FUNCTIONS.md)

#### 5. **Generate Client SDKs** (Optional)
```bash
# Generate Python client
openapi-generator-cli generate \
  -i docs/openapi.json \
  -g python \
  -o clients/python
```

### Learning Resources

**Tutorials**:
- [Quick Start Tutorial](#quick-start)
- [API Usage Examples](API.md#examples)
- [Testing Guide](../tests/TESTING_GUIDE.md)

**API Documentation**:
- Interactive Swagger UI: http://localhost:8000/schema/swagger
- OpenAPI Spec: http://localhost:8000/schema/openapi.json
- ReDoc: http://localhost:8000/schema/redoc

**Development**:
- [Contributing Guide](../CONTRIBUTING.md) (if exists)
- [Development Workflow](#development-workflow)
- [Code Style Guide](../CODE_STYLE.md) (if exists)

---

## 📞 Support

### Getting Help

**If you encounter issues**:

1. **Check this guide** - Most issues covered in [Troubleshooting](#troubleshooting)
2. **Check logs** - Look for error messages:
   ```bash
   # View server logs
   docker-compose logs -f florent  # If using Docker

   # Or check console output if running directly
   ```
3. **Run diagnostics**:
   ```bash
   # Verify Python version
   python --version

   # Verify dependencies
   uv run python -c "import litestar, dspy, pydantic; print('✅ All OK')"

   # Run tests
   uv run pytest tests/ -v
   ```
4. **Open an issue** - Include:
   - Error message
   - Steps to reproduce
   - Python version
   - OS information

### Health Check Script

```bash
#!/bin/bash
# Save as check_health.sh

echo "🔍 Florent Health Check"
echo "======================"

# Check Python
python --version && echo "✅ Python OK" || echo "❌ Python missing"

# Check uv
uv --version && echo "✅ uv OK" || echo "❌ uv missing"

# Check dependencies
uv run python -c "import litestar" && echo "✅ Dependencies OK" || echo "❌ Dependencies missing"

# Check API key
[ -n "$OPENAI_API_KEY" ] && echo "✅ API key set" || echo "❌ API key missing"

# Check server
curl -s http://localhost:8000/ > /dev/null && echo "✅ Server running" || echo "❌ Server not running"

echo "======================"
echo "Run 'uv run litestar run' to start server"
```

---

## 📝 Quick Reference

### Essential Commands

```bash
# Install dependencies
uv sync

# Run server (development)
uv run litestar run --reload

# Run tests
uv run pytest tests/ -v

# Run linter
uv run ruff check src/

# Generate OpenAPI spec
uv run python scripts/generate_openapi.py

# Update dependencies
./update.sh

# View API docs
open http://localhost:8000/schema/swagger
```

### File Structure

```
florent/
├── src/                    # Source code
│   ├── main.py            # API entry point
│   ├── models/            # Data models
│   ├── services/          # Business logic
│   └── settings.py        # Configuration
├── tests/                 # Test suite (264 tests)
├── docs/                  # Documentation
├── examples/              # Example data
├── scripts/               # Utility scripts
├── .env                   # Environment variables (create this)
├── requirements.txt       # Dependencies
├── Dockerfile            # Docker configuration
├── docker-compose.yml    # Docker Compose config
└── README.md             # Project overview
```

---

## ✅ Setup Checklist

- [ ] Python 3.11+ installed
- [ ] `uv` installed
- [ ] Repository cloned
- [ ] Dependencies installed (`uv sync`)
- [ ] OpenAI API key configured
- [ ] `.env` file created
- [ ] Tests passing (`uv run pytest tests/ -v`)
- [ ] Server running (`uv run litestar run`)
- [ ] API responding (`curl http://localhost:8000/`)
- [ ] Swagger UI accessible (`http://localhost:8000/schema/swagger`)

**All checked?** You're ready to go! 🚀

---

## 📚 Additional Resources

- [README](../README.md) - Project overview
- [API Documentation](API.md) - REST API reference
- [System Audit](audit.md) - Implementation status
- [Technical Roadmap](ROADMAP.md) - Mathematical foundations
- [Documentation Index](INDEX.md) - All documentation

**Questions?** Check the [Troubleshooting](#troubleshooting) section or open an issue.

---

**Setup Guide Version**: 1.0.0
**Last Updated**: 2026-02-07
**Maintained By**: Florent Development Team

Good luck with your risk analysis! 🎯
