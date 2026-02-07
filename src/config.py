"""Configuration utilities for loading environment variables."""
from pathlib import Path
from dotenv import load_dotenv


def find_project_root(marker_files=(".env", ".git", "pyproject.toml")) -> Path:
    """
    Find the project root by looking for marker files.

    Walks up the directory tree from the current file until it finds
    a directory containing one of the marker files.

    Args:
        marker_files: Tuple of filenames that indicate the project root

    Returns:
        Path to the project root directory

    Raises:
        FileNotFoundError: If project root cannot be found
    """
    current = Path(__file__).resolve().parent

    # Walk up the directory tree
    for parent in [current] + list(current.parents):
        if any((parent / marker).exists() for marker in marker_files):
            return parent

    raise FileNotFoundError(
        f"Could not find project root. Looked for: {marker_files}"
    )


def load_env_from_project_root() -> Path:
    """
    Load environment variables from .env file in project root.

    Returns:
        Path to the project root directory
    """
    project_root = find_project_root()
    dotenv_path = project_root / ".env"

    if dotenv_path.exists():
        load_dotenv(dotenv_path=dotenv_path, override=False)

    return project_root


# Load environment variables when this module is imported
PROJECT_ROOT = load_env_from_project_root()
