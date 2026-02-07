# Florent Logging Service

## Overview

Florent uses **structlog** for modern structured logging. All logs are JSON-formatted with timestamps, context, and structured data.

**Philosophy**: No fallbacks. If logging fails, the system crashes. Logs are first-class citizens.

---

## Quick Start

### Installation

```bash
uv add structlog
```

### Basic Usage

```python
from src.services.logging import get_logger

logger = get_logger(__name__)

# Simple message
logger.info("node_evaluated")

# With structured data
logger.info(
    "risk_calculated",
    node_id="n_123",
    risk_score=0.85,
    influence_score=0.62
)

# Error with context
logger.error(
    "calculation_failed",
    node_id="n_456",
    error_type="ValueError",
    error_message="Invalid probability"
)
```

---

## Context Management

### Persistent Context

Use `with_context()` to bind context that persists across multiple log calls:

```python
from src.services.logging import with_context

# All logs from this logger will include request_id and firm_id
logger = with_context(request_id="req_abc", firm_id="firm_001")

logger.info("analysis_started")
# Output: {"event": "analysis_started", "request_id": "req_abc", "firm_id": "firm_001", ...}

logger.info("node_processed", node_id="n_5")
# Output: {"event": "node_processed", "request_id": "req_abc", "firm_id": "firm_001", "node_id": "n_5", ...}
```

### Temporary Context

Use `log_context()` for scoped context:

```python
from src.services.logging.context import log_context

with log_context(request_id="req_123") as log:
    log.info("processing_started")
    # ... do work
    log.info("processing_completed")

# Context cleared after exiting
```

---

## Automatic Operation Logging

### Context Manager

```python
from src.services.logging.context import log_operation

with log_operation("risk_propagation", node_id="n_789") as log:
    # Automatically logs: {"event": "operation_started", "operation": "risk_propagation", "node_id": "n_789"}

    log.info("calculating_parents", parent_count=3)
    # ... perform operation

    # Automatically logs: {"event": "operation_completed", "operation": "risk_propagation", "node_id": "n_789"}
```

If an exception occurs, logs `operation_failed` with error details.

---

## Function Decorators

### Log Execution

```python
from src.services.logging.decorators import log_execution

@log_execution
def calculate_influence_score(ce_score: float, distance: int) -> float:
    # Automatically logs function_started and function_completed with timing
    return ce_score * (1.2 ** -distance)

score = calculate_influence_score(0.8, 2)
# Logs: {"event": "function_completed", "function": "calculate_influence_score", "duration_ms": 0.15}
```

### Log Method

```python
from src.services.logging.decorators import log_method

class RiskAnalyzer:
    @log_method
    def analyze(self, project_id: str) -> AnalysisOutput:
        # Automatically logs with class context
        return self._perform_analysis(project_id)

analyzer = RiskAnalyzer()
result = analyzer.analyze("proj_001")
# Logs: {"event": "method_completed", "class_name": "RiskAnalyzer", "method": "analyze", "duration_ms": 45.2}
```

---

## Log Levels

Use appropriate levels for different scenarios:

```python
logger.debug("detailed_state", node_stack_size=12)  # Verbose debugging
logger.info("node_evaluated", node_id="n_5")        # Normal operations
logger.warning("low_confidence", score=0.3)         # Concerning but not fatal
logger.error("validation_failed", reason="cycle")   # Operation failed
logger.critical("system_failure", component="dspy") # Unrecoverable error
```

---

## Configuration

### Environment Variables

```bash
# Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
LOG_LEVEL=INFO

# Output format (true = JSON, false = colored console)
LOG_JSON=true

# Environment (production forces JSON)
ENVIRONMENT=production
```

### Programmatic Configuration

```python
from src.services.logging import configure_logging

# Development: colored console output
configure_logging(level="DEBUG", json_output=False)

# Production: JSON output
configure_logging(level="INFO", json_output=True)
```

---

## Output Format

### JSON (Production)

```json
{
  "event": "risk_calculated",
  "level": "info",
  "timestamp": "2026-02-07T12:34:56.789012Z",
  "node_id": "n_123",
  "risk_score": 0.85,
  "influence_score": 0.62,
  "quadrant": "Q1_KNOWN_KNOWNS"
}
```

### Console (Development)

```
2026-02-07 12:34:56 [info     ] risk_calculated           node_id=n_123 risk_score=0.85 influence_score=0.62
```

---

## Best Practices

### 1. Always Include Context

**Bad**:
```python
logger.info("node processed")
```

**Good**:
```python
logger.info("node_processed", node_id=node.id, risk_score=score)
```

### 2. Use Snake Case for Event Names

**Bad**:
```python
logger.info("NodeEvaluated")
logger.info("risk-calculated")
```

**Good**:
```python
logger.info("node_evaluated")
logger.info("risk_calculated")
```

### 3. Log Action Events, Not States

**Bad**:
```python
logger.info("node is being evaluated")
```

**Good**:
```python
logger.info("node_evaluation_started")
# ... work
logger.info("node_evaluation_completed")
```

### 4. Include Error Details

**Bad**:
```python
except Exception as e:
    logger.error("error occurred")
```

**Good**:
```python
except Exception as e:
    logger.error(
        "calculation_failed",
        error_type=type(e).__name__,
        error_message=str(e),
        node_id=node.id,
        operation="risk_propagation"
    )
    raise  # No swallowing errors
```

### 5. Use Decorators for Timing

**Bad**:
```python
def analyze(project):
    start = time.time()
    result = do_work()
    logger.info("done", duration=time.time() - start)
    return result
```

**Good**:
```python
@log_execution
def analyze(project):
    return do_work()
```

---

## Example Output

```bash
$ python -c "from src.services.logging import get_logger; logger = get_logger('test'); logger.info('service_ready', status='operational')"
```

**Output**:
```json
{"status": "operational", "event": "service_ready", "level": "info", "timestamp": "2026-02-07T15:27:55.563699Z"}
```

---

**Last Updated**: 2026-02-07
