# Florent Testing Guide

## Quick Start

### Validate Setup
```bash
python tests/validate_setup.py
```

### Run All Tests
```bash
# Using the test runner
python tests/run_tests.py

# Using pytest
python -m pytest tests/

# Using unittest
python -m unittest discover tests/
```

### Run Specific Tests
```bash
# Run unit tests only
python tests/run_tests.py unit

# Run integration tests only
python tests/run_tests.py integration

# Run with coverage
python tests/run_tests.py coverage

# Run specific file
python -m pytest tests/test_graph.py -v
```

## Test Suite Overview

### Test Statistics
- **11 test files** covering all modules
- **~2800 lines** of test code
- **Unit + Integration** test coverage

### Test Files

| File | Module Tested | Test Count | Purpose |
|------|--------------|------------|---------|
| test_base.py | models/base.py | ~25 tests | Base models, data loaders, registries |
| test_entities.py | models/entities.py | ~30 tests | Business entities (Firm, Project, Risk) |
| test_graph.py | models/graph.py | ~7 tests | Graph structures, DAG validation |
| test_traversal.py | agent/core/traversal.py | ~20 tests | Stack and Heap data structures |
| test_orchestrator.py | agent/core/orchestrator.py | ~15 tests | Agent orchestration logic |
| test_signatures.py | agent/models/signatures.py | ~15 tests | DSPy signature definitions |
| test_tensor_ops.py | agent/ops/tensor_ops_cpp.py | ~15 tests | C++ tensor operation bindings |
| test_ai_client.py | clients/ai_client.py | ~10 tests | AI client initialization |
| test_geo.py | country/geo.py | ~20 tests | Geo-spatial analysis |
| test_settings.py | settings.py | ~15 tests | Application settings |
| test_integration.py | Multiple | ~10 tests | End-to-end workflows |

## Test Categories

### Unit Tests
Test individual components in isolation with mocked dependencies:
- Model validation
- Data structure operations
- Business logic
- Error handling

### Integration Tests
Test component interactions and complete workflows:
- End-to-end project creation
- Graph traversal workflows
- Multi-component analysis pipelines

## Common Commands

### Testing Specific Components
```bash
# Test graph functionality
python -m pytest tests/test_graph.py -v

# Test with specific pattern
python -m pytest tests/ -k "graph" -v

# Test and show print statements
python -m pytest tests/test_graph.py -v -s
```

### Coverage Analysis
```bash
# Generate HTML coverage report
python tests/run_tests.py coverage

# View coverage in terminal
python -m pytest tests/ --cov=src --cov-report=term

# Generate detailed HTML report
python -m pytest tests/ --cov=src --cov-report=html
open htmlcov/index.html
```

### Debugging Failed Tests
```bash
# Stop on first failure
python tests/run_tests.py -f

# Show full traceback
python -m pytest tests/ --tb=long

# Run only failed tests from last run
python -m pytest tests/ --lf

# Run failed tests first
python -m pytest tests/ --ff
```

## Test Development

### Adding New Tests

1. **Create test file**: `tests/test_mymodule.py`

2. **Add imports**:
```python
import sys
import os
import unittest
from unittest.mock import patch

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.mymodule import MyClass
```

3. **Write test class**:
```python
class TestMyClass(unittest.TestCase):
    def setUp(self):
        """Set up test fixtures."""
        self.instance = MyClass()

    def test_my_feature(self):
        """Test specific feature."""
        result = self.instance.my_method()
        self.assertEqual(result, expected_value)
```

4. **Run your tests**:
```bash
python -m pytest tests/test_mymodule.py -v
```

### Using Fixtures

Pytest fixtures are defined in `conftest.py`:

```python
def test_with_fixture(sample_node):
    """Test using a fixture from conftest.py."""
    assert sample_node.id == "TEST_NODE"
```

Available fixtures:
- `sample_country` - Country object
- `sample_operation_type` - OperationType object
- `sample_node` - Node object
- `sample_graph` - Graph with nodes and edges
- `mock_countries_data` - Mock country data
- `mock_affiliations_data` - Mock affiliation data

### Mocking Best Practices

```python
# Mock file loading
with patch('builtins.open', mock_open(read_data='{"key": "value"}')):
    result = load_data()

# Mock environment variables
@patch.dict(os.environ, {'API_KEY': 'test-key'})
def test_with_env():
    pass

# Mock external libraries
@patch('external_lib.function', return_value='mocked')
def test_external(mock_func):
    pass
```

## Continuous Integration

Tests are designed for CI/CD:
- **Fast execution**: < 30 seconds for full suite
- **No external dependencies**: All I/O mocked
- **Deterministic**: Same results every run
- **Clear output**: Easy to identify failures

### GitHub Actions Example
```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Set up Python
        uses: actions/setup-python@v2
        with:
          python-version: 3.9
      - name: Install dependencies
        run: pip install -r requirements.txt
      - name: Run tests
        run: python tests/run_tests.py
```

## Troubleshooting

### Import Errors
```bash
# Check Python path
echo $PYTHONPATH

# Verify you're in project root
pwd  # Should be .../florent

# Run from project root
cd /path/to/florent
python tests/run_tests.py
```

### Mock Not Working
```python
# Ensure correct import path
# If code does: from src.models import base
# Mock should be: @patch('src.models.base.function')

# Not: @patch('src.models.function')  [ERROR]
```

### Tests Pass Individually But Fail Together
```python
# Ensure proper cleanup in tearDown
def tearDown(self):
    self.patcher.stop()
    # Reset global state
    # Clear caches
```

### Pydantic Validation Errors
```python
# Check mock registries are active
@patch('src.models.base.get_categories', return_value={'valid_category'})
def test_with_categories(mock_get):
    # Now validation will pass
    op = OperationType(category='valid_category', ...)
```

## Performance Tips

### Speed Up Tests
```bash
# Run in parallel with pytest-xdist
pip install pytest-xdist
python -m pytest tests/ -n auto

# Skip slow tests
python -m pytest tests/ -m "not slow"

# Run only changed tests
python -m pytest tests/ --testmon
```

### Profile Tests
```bash
# Show slowest tests
python -m pytest tests/ --durations=10

# Profile with coverage
python -m pytest tests/ --cov=src --cov-report=html --profile
```

## Test Quality Metrics

### Coverage Goals
- **Unit tests**: > 90% coverage
- **Integration tests**: Critical paths covered
- **Overall**: > 80% coverage

### Test Quality Checklist
- [ ] Tests are independent
- [ ] Tests are deterministic
- [ ] Tests are well-named
- [ ] Tests have docstrings
- [ ] Mocks are properly isolated
- [ ] Edge cases are covered
- [ ] Error cases are tested

## Resources

- **unittest documentation**: https://docs.python.org/3/library/unittest.html
- **pytest documentation**: https://docs.pytest.org/
- **unittest.mock guide**: https://docs.python.org/3/library/unittest.mock.html
- **Pydantic testing**: https://docs.pydantic.dev/latest/usage/validation_errors/

## Support

For test-related issues:
1. Check this guide
2. Review test documentation in README.md
3. Run validate_setup.py for diagnostics
4. Check individual test file docstrings

Happy testing! 
