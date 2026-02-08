import os
from dotenv import load_dotenv
from functools import cached_property
from typing import Dict, Any

from src.config import PROJECT_ROOT
from src.services.logging import get_logger

logger = get_logger(__name__)


class Settings:
    """
    Application settings loaded from environment variables.

    Provides both legacy flat attributes and new structured config objects
    for backward compatibility and improved type safety.
    """

    def __init__(self):
        """Initialize settings from environment variables."""
        # Load environment variables from .env
        load_dotenv(os.path.join(PROJECT_ROOT, ".env"), override=False)

        # LLM Settings
        self.OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
        self.LLM_MODEL = os.getenv("LLM_MODEL", "gpt-4o-mini")

        # BGE-M3 Settings
        self.BGE_M3_URL = os.getenv("BGE_M3_URL", "http://localhost:8080")
        self.BGE_M3_MODEL = os.getenv("BGE_M3_MODEL", "BAAI/bge-m3")
        # Cross-encoder endpoint (same as BGE_M3_URL, uses embedding similarity)
        self.CROSS_ENCODER_ENDPOINT = os.getenv("CROSS_ENCODER_ENDPOINT", self.BGE_M3_URL)
        self.USE_CROSS_ENCODER = os.getenv("USE_CROSS_ENCODER", "true").lower() == "true"

        # Engine Constants
        self.DEFAULT_ATTENUATION_FACTOR = float(os.getenv("DEFAULT_ATTENUATION_FACTOR", "1.2"))
        self.MAX_TRAVERSAL_DEPTH = int(os.getenv("MAX_TRAVERSAL_DEPTH", "10"))

        # Graph Builder Settings
        self.GRAPH_GAP_THRESHOLD = float(os.getenv("GRAPH_GAP_THRESHOLD", "0.3"))
        self.GRAPH_MAX_ITERATIONS = int(os.getenv("GRAPH_MAX_ITERATIONS", "10"))
        self.GRAPH_MAX_DISCOVERED_NODES = int(os.getenv("GRAPH_MAX_DISCOVERED_NODES", "50"))

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

    # ===========================================================================
    # Structured Configuration Objects (New)
    # ===========================================================================

    @cached_property
    def cross_encoder(self):
        """Get CrossEncoderConfig object."""
        from src.config.schemas import CrossEncoderConfig
        config = CrossEncoderConfig.from_env()
        config.validate()
        return config

    @cached_property
    def agent(self):
        """Get AgentConfig object."""
        from src.config.schemas import AgentConfig
        config = AgentConfig.from_env()
        config.validate()
        return config

    @cached_property
    def matrix(self):
        """Get MatrixConfig object."""
        from src.config.schemas import MatrixConfig
        config = MatrixConfig.from_env()
        config.validate()
        return config

    @cached_property
    def bidding(self):
        """Get BiddingConfig object."""
        from src.config.schemas import BiddingConfig
        config = BiddingConfig.from_env()
        config.validate()
        return config

    @cached_property
    def graph_builder(self):
        """Get GraphBuilderConfig object."""
        from src.config.schemas import GraphBuilderConfig
        config = GraphBuilderConfig.from_env()
        config.validate()
        return config

    @cached_property
    def pipeline(self):
        """Get PipelineConfig object."""
        from src.config.schemas import PipelineConfig
        config = PipelineConfig.from_env()
        config.validate()
        return config

    def get_all_configs(self) -> Dict[str, Any]:
        """
        Get all structured configuration objects.

        Returns:
            Dictionary with all config objects:
            {cross_encoder, agent, matrix, bidding, graph_builder, pipeline}
        """
        return {
            "cross_encoder": self.cross_encoder,
            "agent": self.agent,
            "matrix": self.matrix,
            "bidding": self.bidding,
            "graph_builder": self.graph_builder,
            "pipeline": self.pipeline
        }

    def export_config_dict(self) -> Dict[str, Dict[str, Any]]:
        """
        Export all configurations as nested dictionaries (for serialization/logging).

        Returns:
            Nested dictionary: {module: {param: value}}
        """
        from dataclasses import asdict
        configs = self.get_all_configs()
        return {
            module: asdict(config_obj)
            for module, config_obj in configs.items()
        }


settings = Settings()
