# Florent Test Suite

Comprehensive unit and integration tests for the Florent project analysis system.

## Test Structure

```
tests/
├── __init__.py              # Test package initialization
├── conftest.py              # Pytest fixtures and configuration
├── pytest.ini               # Pytest settings
├── README.md                # This file
├── test_base.py             # Tests for base models and data loaders
├── test_entities.py         # Tests for business entities (Firm, Project, etc.)
├── test_graph.py            # Tests for graph models (Node, Edge, Graph)
├── test_traversal.py        # Tests for traversal structures (Stack, Heap)
├── test_orchestrator.py     # Tests for agent orchestrator
├── test_signatures.py       # Tests for DSPy signatures
├── test_tensor_ops.py       # Tests for C++ tensor operations
├── test_ai_client.py        # Tests for AI client initialization
├── test_geo.py              # Tests for geo-spatial analysis
├── test_settings.py         # Tests for application settings
└── test_integration.py      # End-to-end integration tests
```

## Running Tests

### Run all tests
```bash
python -m pytest tests/
```

### Run specific test file
```bash
python -m pytest tests/test_graph.py
```

### Run tests with verbose output
```bash
python -m pytest tests/ -v
```

### Run only unit tests
```bash
python -m pytest tests/ -m unit
```

### Run only integration tests
```bash
python -m pytest tests/ -m integration
```

### Run with coverage report
```bash
python -m pytest tests/ --cov=src --cov-report=html
```

### Run specific test class or method
```bash
python -m pytest tests/test_graph.py::TestGraphModels::test_valid_dag
```

## Using unittest

Tests are also compatible with unittest:

```bash
# Run all tests
python -m unittest discover tests/

# Run specific test file
python -m unittest tests.test_graph

# Run specific test class
python -m unittest tests.test_graph.TestGraphModels

# Run specific test method
python -m unittest tests.test_graph.TestGraphModels.test_valid_dag
```

## Test Coverage

### Unit Tests
- **test_base.py**: Data loaders, OperationType, Sectors, StrategicFocus, Country models
- **test_entities.py**: Firm, Project, RiskProfile, AnalysisOutput models
- **test_graph.py**: Node, Edge, Graph models, DAG validation, cycle detection
- **test_traversal.py**: NodeStack (LIFO), NodeHeap (Priority Queue) data structures
- **test_orchestrator.py**: AgentOrchestrator exploration and blast radius analysis
- **test_signatures.py**: DSPy signature definitions (NodeSignature, PropagationSignature)
- **test_tensor_ops.py**: C++ tensor operation bindings (cosine similarity, risk propagation)
- **test_ai_client.py**: DSPy/OpenAI client initialization
- **test_geo.py**: GeoAnalyzer for country similarity and geo-spatial analysis
- **test_settings.py**: Application settings and environment variable handling

### Integration Tests
- **test_integration.py**:
  - End-to-end project workflow (Country → Firm → Project → Graph → Analysis)
  - Graph traversal with stack/heap integration
  - Orchestrator with graph integration
  - GeoAnalyzer with entity models
  - Complete analysis pipeline simulation

## Test Features

### Mocking
- All tests use mocks for external dependencies (file I/O, API calls, C++ libraries)
- Shared fixtures in `conftest.py` for common test data
- Environment variable mocking for settings tests

### Data Validation
- Pydantic model validation testing
- Boundary value testing for numeric constraints
- Registry validation for categories, sectors, and focuses

### Error Handling
- Tests for missing/invalid data
- Exception handling verification
- Edge case coverage

## Writing New Tests

### Unit Test Template
```python
import sys
import os
import unittest
from unittest.mock import patch

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.module import YourClass

class TestYourClass(unittest.TestCase):
    def setUp(self):
        """Set up test data."""
        pass

    def tearDown(self):
        """Clean up after tests."""
        pass

    def test_feature(self):
        """Test description."""
        # Arrange
        # Act
        # Assert
        pass

if __name__ == '__main__':
    unittest.main()
```

### Integration Test Template
```python
class TestFeatureIntegration(unittest.TestCase):
    """Integration test for feature workflow."""

    def test_complete_workflow(self):
        """Test complete workflow from input to output."""
        # Create all necessary components
        # Execute workflow
        # Verify end-to-end behavior
        pass
```

## Best Practices

1. **Isolation**: Each test should be independent and not rely on others
2. **Mocking**: Mock external dependencies (files, APIs, databases)
3. **Clear Naming**: Test names should describe what they test
4. **Arrange-Act-Assert**: Structure tests in three clear phases
5. **Edge Cases**: Test boundary conditions and error cases
6. **Documentation**: Add docstrings explaining what each test validates

## Continuous Integration

These tests are designed to run in CI/CD pipelines:
- Fast execution (< 30 seconds for full suite)
- No external dependencies required
- Comprehensive mocking of I/O operations
- Clear pass/fail indicators

## Troubleshooting

### Import Errors
If you encounter import errors, ensure:
1. You're running from the project root directory
2. The `src` directory is in your Python path
3. All required dependencies are installed

### Mock Errors
If mocks aren't working:
1. Check that patches are applied in the correct order
2. Verify patch paths match actual import paths
3. Ensure `setUp` and `tearDown` methods properly start/stop patchers

### Test Failures
If tests fail unexpectedly:
1. Run tests in verbose mode: `pytest -v`
2. Check for recent code changes that might affect test assumptions
3. Verify that mock data matches expected formats
4. Review test isolation - tests may be interfering with each other

## Contributing

When adding new features:
1. Write tests first (TDD approach recommended)
2. Ensure 80%+ code coverage for new modules
3. Add integration tests for workflows involving multiple components
4. Update this README with new test files

## Dependencies

Test dependencies (from requirements.txt):
- pytest
- pytest-cov (optional, for coverage reports)
- unittest (standard library)
- unittest.mock (standard library)

## Contact

For questions about tests, refer to project documentation or open an issue.
