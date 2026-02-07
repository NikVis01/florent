"""Structured logging service for Florent.

Usage:
    from src.services.logging import get_logger

    logger = get_logger(__name__)
    logger.info("operation_started", firm_id="firm_001", node_count=45)
    logger.error("calculation_failed", error=str(e), node_id="node_123")
"""

from src.services.logging.logger import get_logger, configure_logging, with_context

__all__ = ["get_logger", "configure_logging", "with_context"]
