"""Logging decorators for automatic function instrumentation."""

import functools
import time
from typing import Callable, Any
from src.services.logging import get_logger

logger = get_logger(__name__)


def log_execution(func: Callable) -> Callable:
    """
    Decorator to log function execution with timing.

    Usage:
        @log_execution
        def calculate_risk(node_id: str) -> float:
            # ... implementation
            return risk_score
    """
    @functools.wraps(func)
    def wrapper(*args, **kwargs) -> Any:
        func_name = func.__qualname__
        start_time = time.perf_counter()

        logger.debug(
            "function_started",
            function=func_name,
            args_count=len(args),
            kwargs_count=len(kwargs)
        )

        try:
            result = func(*args, **kwargs)
            duration_ms = (time.perf_counter() - start_time) * 1000

            logger.info(
                "function_completed",
                function=func_name,
                duration_ms=round(duration_ms, 2)
            )

            return result

        except Exception as e:
            duration_ms = (time.perf_counter() - start_time) * 1000

            logger.error(
                "function_failed",
                function=func_name,
                duration_ms=round(duration_ms, 2),
                error_type=type(e).__name__,
                error_message=str(e)
            )
            raise

    return wrapper


def log_method(func: Callable) -> Callable:
    """
    Decorator to log class method execution with class context.

    Usage:
        class RiskAnalyzer:
            @log_method
            def analyze(self, project_id: str) -> AnalysisOutput:
                # ... implementation
    """
    @functools.wraps(func)
    def wrapper(self, *args, **kwargs) -> Any:
        class_name = self.__class__.__name__
        method_name = func.__name__
        start_time = time.perf_counter()

        logger.debug(
            "method_started",
            class_name=class_name,
            method=method_name
        )

        try:
            result = func(self, *args, **kwargs)
            duration_ms = (time.perf_counter() - start_time) * 1000

            logger.info(
                "method_completed",
                class_name=class_name,
                method=method_name,
                duration_ms=round(duration_ms, 2)
            )

            return result

        except Exception as e:
            duration_ms = (time.perf_counter() - start_time) * 1000

            logger.error(
                "method_failed",
                class_name=class_name,
                method=method_name,
                duration_ms=round(duration_ms, 2),
                error_type=type(e).__name__,
                error_message=str(e)
            )
            raise

    return wrapper
