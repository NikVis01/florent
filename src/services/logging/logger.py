"""Structured logging service using structlog.

Provides JSON-structured logging with context, timestamps, and proper levels.
No fallbacks - if logging fails, the system should crash.
"""

import sys
import structlog
from typing import Any
import os


def configure_logging(
    level: str = "INFO",
    json_output: bool = True,
    include_timestamp: bool = True,
) -> None:
    """
    Configure structlog for the entire application.

    Args:
        level: Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
        json_output: If True, output JSON. If False, use colored console output.
        include_timestamp: Include ISO timestamp in logs

    Must be called once at application startup.
    """
    processors = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
    ]

    if include_timestamp:
        processors.append(structlog.processors.TimeStamper(fmt="iso", utc=True))

    if json_output:
        # Production: JSON output for log aggregation
        processors.extend([
            structlog.processors.dict_tracebacks,
            structlog.processors.JSONRenderer()
        ])
    else:
        # Development: Colored console output
        processors.extend([
            structlog.dev.set_exc_info,
            structlog.dev.ConsoleRenderer(colors=True)
        ])

    structlog.configure(
        processors=processors,
        wrapper_class=structlog.make_filtering_bound_logger(
            _level_to_int(level)
        ),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(file=sys.stdout),
        cache_logger_on_first_use=True,
    )


def _level_to_int(level: str) -> int:
    """Convert string level to integer."""
    levels = {
        "DEBUG": 10,
        "INFO": 20,
        "WARNING": 30,
        "ERROR": 40,
        "CRITICAL": 50,
    }
    return levels.get(level.upper(), 20)


def get_logger(name: str) -> structlog.BoundLogger:
    """
    Get a structured logger instance.

    Args:
        name: Logger name (typically __name__ of the calling module)

    Returns:
        Configured structlog logger

    Usage:
        logger = get_logger(__name__)
        logger.info("node_evaluated", node_id="n_123", score=0.85)
        logger.error("graph_invalid", reason="cycle detected", nodes=["a", "b"])
    """
    return structlog.get_logger(name)


def with_context(**kwargs: Any) -> structlog.BoundLogger:
    """
    Create a logger with persistent context.

    Args:
        **kwargs: Context to include in all subsequent log messages

    Returns:
        Logger with bound context

    Usage:
        logger = with_context(request_id="req_abc", firm_id="firm_001")
        logger.info("analysis_started")  # Automatically includes request_id and firm_id
        logger.info("node_processed", node_id="n_5")
    """
    return structlog.get_logger().bind(**kwargs)


# Auto-configure on import with environment-based settings
_log_level = os.getenv("LOG_LEVEL", "INFO")
_json_output = os.getenv("LOG_JSON", "true").lower() == "true"
_env = os.getenv("ENVIRONMENT", "development")

# Force JSON in production, allow colored console in dev
if _env == "production":
    _json_output = True

configure_logging(
    level=_log_level,
    json_output=_json_output,
    include_timestamp=True
)
