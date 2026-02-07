# Environment Variable Loading

## Overview

This project uses a centralized, resilient approach to loading environment variables from the `.env` file.

## How It Works

The `src/config.py` module provides a robust way to find and load the `.env` file from the project root, regardless of where your script is executed from or what directory you're in.

### Key Features

1. **Automatic Project Root Detection**: Finds the project root by looking for marker files (`.env`, `.git`, `pyproject.toml`)
2. **Works from Any Location**: Doesn't rely on relative paths that break when scripts are run from different directories
3. **Centralized Loading**: Environment variables are loaded once when `src.config` is imported
4. **No Duplicate Loading**: All modules use the same `PROJECT_ROOT` from `src/config`

## Usage

Simply import `PROJECT_ROOT` from `src.config` in any module that needs it:

```python
from src.config import PROJECT_ROOT

# PROJECT_ROOT is a pathlib.Path object pointing to the project root
data_file = PROJECT_ROOT / "data" / "my_data.csv"
```

Environment variables are automatically loaded when you import from `src.config`, so you can use `os.getenv()` anywhere:

```python
import os
from src.config import PROJECT_ROOT

api_key = os.getenv("OPENAI_API_KEY")
```

## Why This Approach?

### Before (Fragile)
```python
# In src/settings.py
project_root = Path(__file__).parent.parent  # Goes up 2 levels

# In src/services/clients/ai_client.py
project_root = Path(__file__).parent.parent.parent  # Goes up 3 levels - WRONG!
```

**Problems:**
- Each file needs different numbers of `.parent` calls
- Easy to make mistakes
- Breaks if you reorganize directory structure
- Your colleague gets path errors depending on where they run the script

### After (Resilient)
```python
from src.config import PROJECT_ROOT
```

**Benefits:**
- Works from any directory level
- Consistent across all modules
- Finds project root intelligently by looking for marker files
- Easy to maintain and understand

## Configuration

By default, `find_project_root()` looks for these marker files:
- `.env`
- `.git`
- `pyproject.toml`

If you need to customize this, edit `src/config.py`:

```python
def find_project_root(marker_files=(".env", ".git", "pyproject.toml", "setup.py")):
    ...
```

## Troubleshooting

If you get `FileNotFoundError: Could not find project root`:
1. Make sure you have at least one marker file (`.env`, `.git`, or `pyproject.toml`) in your project root
2. Check that you're running the script from within the project directory or a subdirectory

## Testing

The configuration is tested in:
- `tests/test_settings.py::TestLoggingConfiguration::test_dotenv_loaded`
- `tests/test_ai_client.py::TestAIClientDotenv::test_load_dotenv_called`

Run tests with:
```bash
pytest tests/test_settings.py tests/test_ai_client.py -v
```
