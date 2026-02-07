"""
Pytest configuration and shared fixtures for Florent tests.
"""
import pytest
import sys
import os
from unittest.mock import patch

# Add src to path for all tests
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


@pytest.fixture(autouse=True)
def mock_registries():
    """Auto-use fixture to mock data registries for all tests."""
    mock_categories = {"transportation", "logistics", "construction", "engineering", "test_category"}
    mock_sectors = {"infrastructure", "energy", "finance"}
    mock_focuses = {"efficiency", "sustainability", "growth", "quality"}

    try:
        with patch('src.models.base.get_categories', return_value=mock_categories), \
             patch('src.models.base.get_sectors', return_value=mock_sectors), \
             patch('src.models.base.get_focuses', return_value=mock_focuses):
            yield
    except (ImportError, AttributeError):
        # Skip mocking if the modules don't exist yet
        yield


@pytest.fixture
def sample_country():
    """Fixture providing a sample Country object."""
    from src.models.base import Country
    return Country(
        name="United States",
        a2="US",
        a3="USA",
        num="840",
        region="Americas",
        sub_region="Northern America",
        affiliations=["NATO", "OECD"]
    )


@pytest.fixture
def sample_operation_type():
    """Fixture providing a sample OperationType object."""
    from src.models.base import OperationType
    return OperationType(
        name="Test Operation",
        category="transportation",
        description="A test operation for unit tests"
    )


@pytest.fixture
def sample_node(sample_operation_type):
    """Fixture providing a sample Node object."""
    from src.models.graph import Node
    return Node(
        id="TEST_NODE",
        name="Test Node",
        type=sample_operation_type,
        embedding=[0.1, 0.2, 0.3]
    )


@pytest.fixture
def sample_graph(sample_operation_type):
    """Fixture providing a sample Graph with nodes and edges."""
    from src.models.graph import Node, Edge, Graph

    nodes = [
        Node(id="A", name="Node A", type=sample_operation_type, embedding=[0.1, 0.2]),
        Node(id="B", name="Node B", type=sample_operation_type, embedding=[0.3, 0.4]),
        Node(id="C", name="Node C", type=sample_operation_type, embedding=[0.5, 0.6])
    ]

    edges = [
        Edge(source=nodes[0], target=nodes[1], weight=0.5, relationship="leads to"),
        Edge(source=nodes[1], target=nodes[2], weight=0.8, relationship="prerequisite")
    ]

    return Graph(nodes=nodes, edges=edges)


@pytest.fixture
def mock_countries_data():
    """Fixture providing mock countries data."""
    return [
        {
            "name": "United States",
            "a2": "US",
            "a3": "USA",
            "num": "840",
            "region": "Americas",
            "sub_region": "Northern America",
            "affiliations": ["NATO", "OECD"]
        },
        {
            "name": "Canada",
            "a2": "CA",
            "a3": "CAN",
            "num": "124",
            "region": "Americas",
            "sub_region": "Northern America",
            "affiliations": ["NATO", "OECD"]
        }
    ]


@pytest.fixture
def mock_affiliations_data():
    """Fixture providing mock affiliations data."""
    return {
        "NATO": ["USA", "CAN"],
        "OECD": ["USA", "CAN"]
    }


@pytest.fixture(scope="session")
def test_data_dir(tmp_path_factory):
    """Create a temporary directory for test data files."""
    return tmp_path_factory.mktemp("test_data")


# Pytest configuration
def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "unit: mark test as a unit test"
    )
    config.addinivalue_line(
        "markers", "integration: mark test as an integration test"
    )
    config.addinivalue_line(
        "markers", "slow: mark test as slow running"
    )
