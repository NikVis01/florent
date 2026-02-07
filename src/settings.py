import os
from src.config import PROJECT_ROOT
from src.services.logging import get_logger

logger = get_logger(__name__)


class Settings:
    """Application settings loaded from environment variables."""

    def __init__(self):
        """Initialize settings from environment variables."""
        # LLM Settings
        self.OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
        self.LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")

        # BGE-M3 Settings
        self.BGE_M3_URL = os.getenv("BGE_M3_URL", "http://localhost:8080")
        self.BGE_M3_MODEL = os.getenv("BGE_M3_MODEL", "BAAI/bge-m3")

        # Engine Constants
        self.DEFAULT_ATTENUATION_FACTOR = float(os.getenv("DEFAULT_ATTENUATION_FACTOR", "1.2"))
        self.MAX_TRAVERSAL_DEPTH = int(os.getenv("MAX_TRAVERSAL_DEPTH", "10"))

        # Project Paths
        self.BASE_DIR = str(PROJECT_ROOT)
        self.DATA_DIR = os.path.join(self.BASE_DIR, "src", "data")
        self.GEO_DIR = os.path.join(self.DATA_DIR, "geo")
        self.TAXONOMY_DIR = os.path.join(self.DATA_DIR, "taxonomy")
        self.CONFIG_DIR = os.path.join(self.DATA_DIR, "config")
        self.POC_DIR = os.path.join(self.DATA_DIR, "poc")

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
