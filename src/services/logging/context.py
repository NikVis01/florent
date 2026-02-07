"""Context managers for structured logging."""

from contextlib import contextmanager
from typing import Any, Generator
import structlog


@contextmanager
def log_context(**kwargs: Any) -> Generator[structlog.BoundLogger, None, None]:
    """
    Context manager for temporary logging context.

    Usage:
        with log_context(request_id="req_123", firm_id="firm_001") as log:
            log.info("analysis_started")
            # ... do work
            log.info("analysis_completed")

        # Context is cleared after exiting
    """
    logger = structlog.get_logger().bind(**kwargs)
    try:
        yield logger
    finally:
        structlog.contextvars.clear_contextvars()


@contextmanager
def log_operation(operation: str, **kwargs: Any) -> Generator[structlog.BoundLogger, None, None]:
    """
    Context manager for logging an operation with automatic start/end events.

    Usage:
        with log_operation("risk_calculation", node_id="n_123") as log:
            # ... perform calculation
            log.info("intermediate_step", progress=0.5)
            # ... continue

        # Automatically logs operation_started and operation_completed
    """
    logger = structlog.get_logger().bind(operation=operation, **kwargs)
    logger.info("operation_started")

    try:
        yield logger
        logger.info("operation_completed")
    except Exception as e:
        logger.error(
            "operation_failed",
            error_type=type(e).__name__,
            error_message=str(e)
        )
        raise
    finally:
        structlog.contextvars.clear_contextvars()
