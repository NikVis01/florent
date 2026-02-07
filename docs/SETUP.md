# Florent Developer Setup

**Get up and running on the Florent codebase in 10 minutes**

**Version**: 2.0 (Developer-Focused)
**Last Updated**: 2026-02-07
**Estimated Setup Time**: 10-15 minutes
**Audience**: Developers joining the project or setting up a new machine

> **Assumption**: You already have the repository on your machine. This guide gets you from "I have the code" to "I'm running the server and tests."

---

## 📋 Table of Contents

1. [Quick Start](#quick-start-5-minutes)
2. [Prerequisites](#prerequisites)
3. [Environment Setup](#environment-setup)
4. [Development Workflow](#development-workflow)
5. [Running & Testing](#running--testing)
6. [IDE Configuration](#ide-configuration)
7. [Docker Development](#docker-development)
8. [Troubleshooting](#troubleshooting)
9. [Daily Workflow](#daily-workflow)

---

## ⚡ Quick Start (5 Minutes)

**TL;DR - Get running now:**

```bash
# 1. Install uv (if needed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# 2. Install dependencies
uv sync

# 3. Set API key
export OPENAI_API_KEY="sk-proj-your-key-here"

# 4. Verify everything works
uv run pytest tests/ -v

# 5. Start server
uv run litestar run --reload

# 6. Test it
curl http://localhost:8000/
```

**Done!** Server is at http://localhost:8000, Swagger UI at http://localhost:8000/schema/swagger

**Skip the rest if everything worked.** Otherwise, read on.

---

## 📦 Prerequisites

**What you need before starting:**

### Required (Can't develop without these)

✅ **Python 3.11+**
```bash
python --version  # Must be 3.11 or higher
```

✅ **uv** (Package manager - better than pip)
```bash
uv --version  # If not installed: curl -LsSf https://astral.sh/uv/install.sh | sh
```

✅ **OpenAI API Key** (For AI features)
- Get one: https://platform.openai.com/api-keys
- Cost: ~$0.01-0.10 per analysis
- **Without this, AI features won't work** (tests will fail)

### Optional (Nice to have)

⚠️ **Docker** (If you want to run containerized)
```bash
docker --version && docker-compose --version
```

⚠️ **Make** (For running `make all` build command)
```bash
make --version
```

### Don't Have These? Install Now

<details>
<summary><b>Ubuntu/Debian</b></summary>

```bash
# Python 3.11
sudo apt update && sudo apt install python3.11 python3.11-venv

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Docker
curl -fsSL https://get.docker.com | sh

# Make
sudo apt install build-essential
```
</details>

<details>
<summary><b>macOS</b></summary>

```bash
# Python 3.11
brew install python@3.11

# uv
curl -LsSf https://astral.sh/uv/install.sh | sh

# Docker
brew install --cask docker

# Make (usually pre-installed)
xcode-select --install
```
</details>

<details>
<summary><b>Windows</b></summary>

**Recommendation**: Use WSL2 (Windows Subsystem for Linux)

```powershell
# Enable WSL2
wsl --install

# Then follow Ubuntu instructions inside WSL
```

Or install directly on Windows:
- Python: https://www.python.org/downloads/
- Docker Desktop: https://www.docker.com/products/docker-desktop
- Git for Windows: https://git-scm.com/downloads
</details>

---

## 🛠️ Environment Setup

**You're in the repo directory. Now set up your environment.**

### Step 1: Install Dependencies

**Using uv (recommended)**:
```bash
# Install everything from uv.lock
uv sync

# Creates .venv/ and installs all packages
# Takes ~30 seconds
```

**Alternative - using pip** (if you don't have uv):
```bash
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### Step 2: Verify Installation

```bash
# Quick check
uv run python -c "import litestar, dspy, pydantic; print('✅ All dependencies OK')"

# If that works, you're good. If not, run:
uv pip list | grep -E "litestar|dspy|pydantic"
```

### Step 3: Configure Environment Variables

**Option A: `.env` file** (recommended for dev):

```bash
# Create .env file
cat > .env << 'EOF'
OPENAI_API_KEY=sk-proj-your-actual-key-here
LOG_LEVEL=INFO
HOST=0.0.0.0
PORT=8000
PYTHONPATH=.
EOF

# Or copy from example if it exists
cp .env.example .env
# Then edit with: nano .env
```

**Option B: Shell export** (quick & dirty):

```bash
# Add to your shell profile for persistence
export OPENAI_API_KEY="sk-proj-your-key-here"
export LOG_LEVEL="DEBUG"  # Use DEBUG for development

# Verify it's set
echo $OPENAI_API_KEY  # Should print your key
```

**Get an OpenAI API key**:
1. Go to https://platform.openai.com/api-keys
2. Click "Create new secret key"
3. Copy the key (starts with `sk-proj-...`)
4. Paste into `.env` or export command

### Step 4: Verify Everything Works

```bash
# Run a subset of fast tests
uv run pytest tests/test_base.py -v

# If that passes, run everything (takes ~3 seconds)
uv run pytest tests/ -v

# Expected: 264 passed in 2-3 seconds
```

**If tests pass, you're done with setup!** ✅

---

## 🔧 Development Workflow

### Daily Commands You'll Use

```bash
# Start development server (auto-reloads on code changes)
uv run litestar run --reload

# Run tests (do this before committing)
uv run pytest tests/ -v

# Run specific test file
uv run pytest tests/test_api.py -v

# Lint code (check for issues)
uv run ruff check src/

# Auto-fix linting issues
uv run ruff check --fix src/

# Update everything (dependencies, tests, OpenAPI spec, Docker)
./update.sh
```

### Project Structure (What's Where)

```
florent/
├── src/                      # All source code
│   ├── main.py              # API entry point (Litestar app)
│   ├── models/              # Data models (Firm, Project, Graph)
│   ├── services/            # Business logic
│   │   ├── agent/           # DSPy AI orchestration
│   │   ├── math/            # Risk calculations
│   │   └── logging/         # Structured logging
│   └── settings.py          # Configuration
├── tests/                   # All tests (264 tests)
│   ├── test_api.py         # REST API tests (19 tests)
│   ├── test_orchestrator.py # Agent tests
│   └── ...                 # More test files
├── docs/                    # Documentation
├── scripts/                 # Utility scripts
│   ├── generate_openapi.py # Generate OpenAPI spec
│   └── validate_data.py    # Validate JSON data
├── examples/               # Example firm/project JSONs
├── .env                    # Your environment vars (create this)
├── requirements.txt        # Python dependencies
├── uv.lock                # Locked versions (don't edit)
└── update.sh              # Run this to update everything
```

### Configuration Files

**Environment Variables** (`.env`):
```bash
OPENAI_API_KEY=sk-proj-...    # Required for AI
LOG_LEVEL=DEBUG               # DEBUG in dev, INFO in prod
HOST=0.0.0.0                 # Server host
PORT=8000                    # Server port
PYTHONPATH=.                 # Python module path
```

**View current config**:
```bash
uv run python -c "from src.settings import get_settings; print(get_settings())"
```

---

## 🏃 Running & Testing

### Start the Server

**Development mode** (auto-reloads on changes):
```bash
uv run litestar run --reload

# Server starts at http://localhost:8000
# Logs show in terminal
# Press Ctrl+C to stop
```

**Different port**:
```bash
uv run litestar run --port 9000 --reload
```

**Using the run script**:
```bash
./run.sh  # Starts on port 8000
```

### Test the API

**Quick health check**:
```bash
curl http://localhost:8000/
# Should return: "Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."
```

**Interactive API docs** (best way to explore):
```bash
# Open Swagger UI
open http://localhost:8000/schema/swagger

# Or just paste in browser: http://localhost:8000/schema/swagger
```

**Run example analysis**:
```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "examples/firm.json",
    "project_path": "examples/project.json",
    "budget": 50
  }'
```

### Run Tests

**All tests** (takes ~3 seconds):
```bash
uv run pytest tests/ -v
# Expected: 264 passed
```

**Specific test file**:
```bash
uv run pytest tests/test_api.py -v        # API tests (19 tests)
uv run pytest tests/test_graph.py -v      # Graph tests
uv run pytest tests/test_orchestrator.py -v  # Orchestrator tests
```

**With coverage report**:
```bash
uv run pytest tests/ --cov=src --cov-report=term
# Shows coverage percentage
```

**Fast tests only** (skip slow E2E):
```bash
uv run pytest tests/ -m "not slow" -v
```

**Watch mode** (re-run on file changes):
```bash
uv add --dev pytest-watch  # Install if needed
uv run ptw tests/
```

### API Test Script

```bash
chmod +x test_api.sh  # Make executable
./test_api.sh         # Run all API tests

# Output shows:
# ✅ Health check
# ✅ Analysis endpoint
# ✅ All tests passed
```

---

## 💻 IDE Configuration

### VS Code Setup (Recommended)

**Quick setup**:
```bash
# Install Python extension
code --install-extension ms-python.python

# Configure interpreter
# Press Cmd+Shift+P → "Python: Select Interpreter" → Choose .venv/bin/python
```

**Create `.vscode/settings.json`**:
```json
{
  "python.defaultInterpreterPath": ".venv/bin/python",
  "python.testing.pytestEnabled": true,
  "python.linting.ruffEnabled": true,
  "[python]": {
    "editor.formatOnSave": true,
    "editor.rulers": [88, 120]
  }
}
```

**Recommended extensions**:
- Python (ms-python.python)
- Ruff (charliermarsh.ruff)
- REST Client (humao.rest-client) - for testing API
- Error Lens (usernamehw.errorlens) - inline errors

### PyCharm Setup

1. **File → Open** → Select florent directory
2. **Settings → Project → Python Interpreter**
   - Add Interpreter → Existing → `.venv/bin/python`
3. **Settings → Tools → Python Integrated Tools**
   - Default test runner → pytest

### Code Quality Tools

**Linting** (find issues):
```bash
uv run ruff check src/         # Check for issues
uv run ruff check --fix src/   # Auto-fix what's possible
```

**Formatting** (make pretty):
```bash
uv run ruff format src/  # Format all code
```

**Pre-commit hooks** (optional but good):
```bash
uv add --dev pre-commit
uv run pre-commit install
# Now linting runs automatically on git commit
```

---

## 🐳 Docker Development

**Want to run in Docker instead?**

### Quick Docker Start

```bash
# Build image
docker build -t florent-engine .

# Run container
docker run -d \
  --name florent \
  -p 8000:8000 \
  -e OPENAI_API_KEY="sk-your-key" \
  florent-engine

# View logs
docker logs -f florent

# Stop
docker stop florent && docker rm florent
```

### Docker Compose (Better)

```bash
# Start everything
docker-compose up -d

# View logs
docker-compose logs -f

# Stop everything
docker-compose down

# Rebuild after code changes
docker-compose up -d --build
```

**docker-compose.yml** (already in repo):
```yaml
services:
  florent:
    build: .
    ports:
      - "8000:8000"
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY}
      - LOG_LEVEL=INFO
```

### Develop Inside Container

```bash
# Start with shell access
docker-compose run --rm florent /bin/bash

# Inside container, run commands:
pytest tests/ -v
litestar run --reload
```

---

## 🔧 Troubleshooting

### Quick Fixes

**1. "Module not found" errors**
```bash
uv sync  # Reinstall everything
```

**2. "OpenAI API key not found"**
```bash
echo $OPENAI_API_KEY  # Check if set
export OPENAI_API_KEY="sk-your-key"  # Set it
# Or add to .env file
```

**3. "Port 8000 already in use"**
```bash
lsof -i :8000  # Find what's using port (macOS/Linux)
kill -9 <PID>  # Kill it
# Or: uv run litestar run --port 9000  (use different port)
```

**4. Tests fail with connection errors**
```bash
# Start server first in another terminal
uv run litestar run --reload
# Then run tests
uv run pytest tests/ -v
```

**5. Import errors / PYTHONPATH issues**
```bash
export PYTHONPATH=.
# Or add to .env: echo "PYTHONPATH=." >> .env
```

**6. Docker won't build**
```bash
docker system prune -a  # Clear cache
docker build --no-cache -t florent-engine .
```

**7. Everything is broken**
```bash
# Nuclear option: start fresh
rm -rf .venv/
uv sync
export OPENAI_API_KEY="sk-your-key"
uv run pytest tests/ -v
```

### Health Check Script

**Save as `check.sh`**:
```bash
#!/bin/bash
echo "🔍 Florent Health Check"
python --version || echo "❌ Python missing"
uv --version || echo "❌ uv missing"
uv run python -c "import litestar" && echo "✅ Dependencies OK" || echo "❌ Run: uv sync"
[ -n "$OPENAI_API_KEY" ] && echo "✅ API key set" || echo "❌ Set OPENAI_API_KEY"
curl -s http://localhost:8000/ > /dev/null && echo "✅ Server running" || echo "⚠️ Start server"
```

```bash
chmod +x check.sh && ./check.sh
```

---

## 📋 Daily Workflow

**What you'll actually do day-to-day:**

### Morning Routine
```bash
# 1. Pull latest changes
git pull

# 2. Update dependencies (if needed)
uv sync

# 3. Start server
uv run litestar run --reload

# Leave this running in terminal 1
```

### Development Cycle
```bash
# In terminal 2:

# 1. Edit code in your IDE
# (server auto-reloads when you save)

# 2. Run tests after changes
uv run pytest tests/ -v

# 3. Lint before committing
uv run ruff check src/

# 4. Commit
git add src/
git commit -m "feat: Your change"
git push
```

### Before Committing Checklist

- [ ] Tests pass: `uv run pytest tests/ -v`
- [ ] Linting passes: `uv run ruff check src/`
- [ ] Code formatted: `uv run ruff format src/`
- [ ] API still works: `curl http://localhost:8000/`

### Useful Development Commands

```bash
# Quick test a single file
uv run pytest tests/test_api.py -v

# Run server on different port
uv run litestar run --port 9000 --reload

# Update everything (deps, tests, OpenAPI, Docker)
./update.sh

# Generate OpenAPI spec
uv run python scripts/generate_openapi.py

# Validate data files
python scripts/validate_data.py

# Check what's using port 8000
lsof -i :8000

# View server logs (if Docker)
docker-compose logs -f
```

### Working on Features

```bash
# 1. Create feature branch
git checkout -b feature/my-feature

# 2. Make changes, test, commit
# ... development cycle ...

# 3. Run full test suite
uv run pytest tests/ -v

# 4. Update docs if needed
nano docs/API.md  # or whatever changed

# 5. Push and create PR
git push -u origin feature/my-feature
```

---

## 📚 Key Documentation

**After setup, read these**:

- **[API.md](API.md)** - How to use the API
- **[audit.md](audit.md)** - What's implemented (264 tests status)
- **[ROADMAP.md](ROADMAP.md)** - Math/algorithms explained
- **[INDEX.md](INDEX.md)** - All documentation index

**API endpoints to know**:
- `GET /` - Health check
- `POST /analyze` - Main analysis endpoint
- `GET /schema/swagger` - Interactive API docs

---

## ✅ Setup Complete!

**You should now have**:
- ✅ Dependencies installed
- ✅ API key configured
- ✅ Tests passing (264/264)
- ✅ Server running on http://localhost:8000
- ✅ Swagger UI at http://localhost:8000/schema/swagger

**Start coding!** 🚀

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
