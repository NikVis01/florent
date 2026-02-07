import os
from dotenv import load_dotenv
from src.services.logging import get_logger

# Load environment variables from .env file
load_dotenv()

logger = get_logger(__name__)


class Settings:
    """Application settings loaded from environment variables."""

    # LLM Settings
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
    LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")

    # BGE-M3 Settings
    BGE_M3_URL = os.getenv("BGE_M3_URL", "http://localhost:8080")
    BGE_M3_MODEL = os.getenv("BGE_M3_MODEL", "BAAI/bge-m3")

    # Engine Constants
    DEFAULT_ATTENUATION_FACTOR = float(os.getenv("DEFAULT_ATTENUATION_FACTOR", "1.2"))
    MAX_TRAVERSAL_DEPTH = int(os.getenv("MAX_TRAVERSAL_DEPTH", "10"))

    # Project Paths
    BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    DATA_DIR = os.path.join(BASE_DIR, "src", "data")
    GEO_DIR = os.path.join(DATA_DIR, "geo")
    TAXONOMY_DIR = os.path.join(DATA_DIR, "taxonomy")
    CONFIG_DIR = os.path.join(DATA_DIR, "config")
    POC_DIR = os.path.join(DATA_DIR, "poc")

    def __init__(self):
        """Validate required settings on initialization."""
        self._validate_settings()

    def _validate_settings(self):
        """Validate that required settings are present."""
        if not self.OPENAI_API_KEY:
            logger.warning("OPENAI_API_KEY not set - LLM features will not work")

        # Validate paths exist
        if not os.path.exists(self.DATA_DIR):
            logger.warning(f"Data directory not found: {self.DATA_DIR}")

        logger.info(f"Settings initialized - Model: {self.LLM_MODEL}, BGE URL: {self.BGE_M3_URL}")


settings = Settings()
