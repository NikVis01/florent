"""
Tests for Critical Chain Detection

Tests path finding, risk calculation, and filtering logic.
"""

import pytest
from unittest.mock import patch
from src.models.graph import Graph, Node
from src.models.base import OperationType
from src.services.analysis.chains import (
    find_critical_chains,
    _find_all_paths_dfs,
    _calculate_cumulative_risk,
    _generate_description
)


@pytest.fixture(autouse=True)
def mock_categories():
    """Mock the category validation for all tests."""
    with patch('src.models.base.get_categories', return_value={"test_category"}):
        yield


@pytest.fixture
def simple_linear_graph():
    """
    Simple linear graph: A -> B -> C
    """
    op_type = OperationType(name="Test", category="test_category", description="Test operation")
    node_a = Node(id="a", name="Start", type=op_type)
    node_b = Node(id="b", name="Process", type=op_type)
    node_c = Node(id="c", name="End", type=op_type)

    graph = Graph(nodes=[node_a, node_b, node_c])
    graph.add_edge(node_a, node_b, weight=1.0, relationship="leads to")
    graph.add_edge(node_b, node_c, weight=1.0, relationship="leads to")

    return graph


@pytest.fixture
def branching_graph():
    r"""
    Graph with multiple paths:
          A
         / \
        B   C
         \ /
          D

    Paths: A -> B -> D, A -> C -> D
    """
    op_type = OperationType(name="Test", category="test_category", description="Test operation")
    node_a = Node(id="a", name="Start", type=op_type)
    node_b = Node(id="b", name="Path1", type=op_type)
    node_c = Node(id="c", name="Path2", type=op_type)
    node_d = Node(id="d", name="End", type=op_type)

    graph = Graph(nodes=[node_a, node_b, node_c, node_d])
    graph.add_edge(node_a, node_b, weight=1.0, relationship="leads to")
    graph.add_edge(node_a, node_c, weight=1.0, relationship="leads to")
    graph.add_edge(node_b, node_d, weight=1.0, relationship="leads to")
    graph.add_edge(node_c, node_d, weight=1.0, relationship="leads to")

    return graph


@pytest.fixture
def complex_graph():
    """
    More complex graph with multiple entry and exit nodes:
        A -> B -> D -> F
        |         |
        v         v
        C ------> E -> G

    Entry nodes: A
    Exit nodes: F, G
    Paths: A->B->D->F, A->B->D->E->G, A->C->E->G
    """
    op_type = OperationType(name="Test", category="test_category", description="Test operation")
    nodes = [
        Node(id="a", name="Entry", type=op_type),
        Node(id="b", name="Auth", type=op_type),
        Node(id="c", name="Cache", type=op_type),
        Node(id="d", name="Process", type=op_type),
        Node(id="e", name="Store", type=op_type),
        Node(id="f", name="ExitFast", type=op_type),
        Node(id="g", name="ExitSlow", type=op_type),
    ]

    graph = Graph(nodes=nodes)
    graph.add_edge(nodes[0], nodes[1], weight=1.0)  # A -> B
    graph.add_edge(nodes[0], nodes[2], weight=1.0)  # A -> C
    graph.add_edge(nodes[1], nodes[3], weight=1.0)  # B -> D
    graph.add_edge(nodes[3], nodes[4], weight=1.0)  # D -> E
    graph.add_edge(nodes[3], nodes[5], weight=1.0)  # D -> F
    graph.add_edge(nodes[2], nodes[4], weight=1.0)  # C -> E
    graph.add_edge(nodes[4], nodes[6], weight=1.0)  # E -> G

    return graph


class TestCalculateCumulativeRisk:
    """Test cumulative risk calculation."""

    def test_single_node_risk(self, simple_linear_graph):
        """Single node with 50% risk should give 0.5 cumulative risk."""
        path = [simple_linear_graph.nodes[0]]  # Just node A
        assessments = {"a": {"risk": 0.5}}

        risk = _calculate_cumulative_risk(path, assessments)

        assert risk == pytest.approx(0.5)

    def test_two_independent_risks(self, simple_linear_graph):
        """Two nodes with 0.5 risk each: 1 - (0.5 * 0.5) = 0.75"""
        path = [simple_linear_graph.nodes[0], simple_linear_graph.nodes[1]]
        assessments = {
            "a": {"risk": 0.5},
            "b": {"risk": 0.5}
        }

        risk = _calculate_cumulative_risk(path, assessments)

        # 1 - (1-0.5) * (1-0.5) = 1 - 0.25 = 0.75
        assert risk == pytest.approx(0.75)

    def test_zero_risk_nodes(self, simple_linear_graph):
        """Nodes with zero risk should give zero cumulative risk."""
        path = simple_linear_graph.nodes
        assessments = {
            "a": {"risk": 0.0},
            "b": {"risk": 0.0},
            "c": {"risk": 0.0}
        }

        risk = _calculate_cumulative_risk(path, assessments)

        assert risk == pytest.approx(0.0)

    def test_high_risk_nodes(self, simple_linear_graph):
        """Three nodes with 0.9 risk each."""
        path = simple_linear_graph.nodes
        assessments = {
            "a": {"risk": 0.9},
            "b": {"risk": 0.9},
            "c": {"risk": 0.9}
        }

        risk = _calculate_cumulative_risk(path, assessments)

        # 1 - (0.1 * 0.1 * 0.1) = 1 - 0.001 = 0.999
        assert risk == pytest.approx(0.999)

    def test_missing_assessment_defaults_to_zero(self, simple_linear_graph):
        """Nodes without assessments should default to 0 risk."""
        path = simple_linear_graph.nodes
        assessments = {"a": {"risk": 0.5}}  # Only A has assessment

        risk = _calculate_cumulative_risk(path, assessments)

        # Only node A contributes risk
        assert risk == pytest.approx(0.5)


class TestFindAllPathsDFS:
    """Test DFS path finding."""

    def test_single_path(self, simple_linear_graph):
        """Linear graph should have exactly one path."""
        entry = simple_linear_graph.get_entry_nodes()[0]
        exit_ids = {n.id for n in simple_linear_graph.get_exit_nodes()}

        paths = _find_all_paths_dfs(simple_linear_graph, entry, exit_ids)

        assert len(paths) == 1
        assert [n.id for n in paths[0]] == ["a", "b", "c"]

    def test_multiple_paths(self, branching_graph):
        """Branching graph should find both paths."""
        entry = branching_graph.get_entry_nodes()[0]
        exit_ids = {n.id for n in branching_graph.get_exit_nodes()}

        paths = _find_all_paths_dfs(branching_graph, entry, exit_ids)

        assert len(paths) == 2

        # Convert to sets for comparison (order doesn't matter)
        path_ids = {tuple(n.id for n in path) for path in paths}
        expected = {("a", "b", "d"), ("a", "c", "d")}
        assert path_ids == expected

    def test_complex_paths(self, complex_graph):
        """Complex graph should find all three paths."""
        entry = complex_graph.get_entry_nodes()[0]
        exit_ids = {n.id for n in complex_graph.get_exit_nodes()}

        paths = _find_all_paths_dfs(complex_graph, entry, exit_ids)

        assert len(paths) == 3

        path_ids = {tuple(n.id for n in path) for path in paths}
        expected = {
            ("a", "b", "d", "f"),  # Fast path
            ("a", "b", "d", "e", "g"),  # Through processing
            ("a", "c", "e", "g")  # Cache path
        }
        assert path_ids == expected


class TestGenerateDescription:
    """Test description generation."""

    def test_no_high_risk_nodes(self, simple_linear_graph):
        """Description for path with low-risk nodes."""
        path = simple_linear_graph.nodes
        assessments = {
            "a": {"risk": 0.3},
            "b": {"risk": 0.5},
            "c": {"risk": 0.6}
        }

        desc = _generate_description(path, 0.85, assessments)

        assert "Critical path with 3 nodes" in desc
        # Should not mention high-risk nodes
        assert "high-risk" not in desc

    def test_single_high_risk_node(self, simple_linear_graph):
        """Description with one high-risk node."""
        path = simple_linear_graph.nodes
        assessments = {
            "a": {"risk": 0.3},
            "b": {"risk": 0.9},  # High risk
            "c": {"risk": 0.5}
        }

        desc = _generate_description(path, 0.95, assessments)

        assert "Critical path with 3 nodes" in desc
        assert "high-risk Process" in desc

    def test_two_high_risk_nodes(self, simple_linear_graph):
        """Description with two high-risk nodes."""
        path = simple_linear_graph.nodes
        assessments = {
            "a": {"risk": 0.8},  # High risk
            "b": {"risk": 0.9},  # High risk
            "c": {"risk": 0.5}
        }

        desc = _generate_description(path, 0.98, assessments)

        assert "Critical path with 3 nodes" in desc
        assert "high-risk Start and Process" in desc

    def test_many_high_risk_nodes(self, complex_graph):
        """Description with more than two high-risk nodes."""
        path = [complex_graph.nodes[i] for i in [0, 1, 3, 4, 6]]  # A, B, D, E, G
        assessments = {
            "a": {"risk": 0.8},
            "b": {"risk": 0.85},
            "d": {"risk": 0.9},
            "e": {"risk": 0.75},
            "g": {"risk": 0.6}
        }

        desc = _generate_description(path, 0.99, assessments)

        assert "Critical path with 5 nodes" in desc
        # Should mention first two and count the rest
        assert "high-risk" in desc
        assert "and 1 others" in desc or "and 2 others" in desc


class TestFindCriticalChains:
    """Test the main find_critical_chains function."""

    def test_no_chains_below_threshold(self, simple_linear_graph):
        """No chains should be returned if all are below threshold."""
        assessments = {
            "a": {"risk": 0.1},
            "b": {"risk": 0.1},
            "c": {"risk": 0.1}
        }

        chains = find_critical_chains(simple_linear_graph, assessments, threshold=0.8)

        assert len(chains) == 0

    def test_single_critical_chain(self, simple_linear_graph):
        """Single chain above threshold should be returned."""
        assessments = {
            "a": {"risk": 0.5},
            "b": {"risk": 0.6},
            "c": {"risk": 0.7}
        }

        chains = find_critical_chains(simple_linear_graph, assessments, threshold=0.8)

        assert len(chains) == 1
        assert chains[0]["nodes"] == ["a", "b", "c"]
        assert chains[0]["risk"] > 0.8
        assert "Critical path" in chains[0]["description"]

    def test_multiple_chains_sorted_by_risk(self, branching_graph):
        """Multiple chains should be sorted by risk (descending)."""
        assessments = {
            "a": {"risk": 0.5},
            "b": {"risk": 0.9},  # High risk path
            "c": {"risk": 0.3},  # Low risk path
            "d": {"risk": 0.5}
        }

        chains = find_critical_chains(branching_graph, assessments, threshold=0.7, top_n=5)

        assert len(chains) == 2

        # First chain should have higher risk (goes through B)
        # Second chain should have lower risk (goes through C)
        assert chains[0]["risk"] > chains[1]["risk"]
        assert "b" in chains[0]["nodes"]  # High-risk path
        assert "c" in chains[1]["nodes"]  # Low-risk path

    def test_top_n_limiting(self, complex_graph):
        """Should return only top N chains."""
        assessments = {
            "a": {"risk": 0.8},
            "b": {"risk": 0.8},
            "c": {"risk": 0.7},
            "d": {"risk": 0.8},
            "e": {"risk": 0.8},
            "f": {"risk": 0.7},
            "g": {"risk": 0.7}
        }

        chains = find_critical_chains(complex_graph, assessments, threshold=0.5, top_n=2)

        assert len(chains) <= 2

    def test_chain_structure(self, simple_linear_graph):
        """Verify chain structure has required fields."""
        assessments = {
            "a": {"risk": 0.9},
            "b": {"risk": 0.9},
            "c": {"risk": 0.9}
        }

        chains = find_critical_chains(simple_linear_graph, assessments, threshold=0.8)

        assert len(chains) == 1
        chain = chains[0]

        # Check required fields
        assert "nodes" in chain
        assert "risk" in chain
        assert "description" in chain

        # Check types
        assert isinstance(chain["nodes"], list)
        assert isinstance(chain["risk"], float)
        assert isinstance(chain["description"], str)

        # Check values
        assert len(chain["nodes"]) == 3
        assert 0.0 <= chain["risk"] <= 1.0
        assert len(chain["description"]) > 0

    def test_realistic_scenario(self, complex_graph):
        """Test with realistic risk assessments."""
        assessments = {
            "a": {"risk": 0.1, "influence": 0.9},  # Entry point, low risk
            "b": {"risk": 0.8, "influence": 0.9},  # Auth, high risk
            "c": {"risk": 0.2, "influence": 0.5},  # Cache, low risk
            "d": {"risk": 0.7, "influence": 0.8},  # Process, medium-high risk
            "e": {"risk": 0.6, "influence": 0.7},  # Store, medium risk
            "f": {"risk": 0.1, "influence": 0.5},  # Exit, low risk
            "g": {"risk": 0.1, "influence": 0.5},  # Exit, low risk
        }

        chains = find_critical_chains(complex_graph, assessments, threshold=0.8, top_n=3)

        # Should find critical chains through Auth (b) and Process (d)
        assert len(chains) > 0

        # Highest risk chain should go through both b and d
        top_chain = chains[0]
        assert "b" in top_chain["nodes"]
        assert top_chain["risk"] > 0.8

        # Description should mention high-risk nodes
        assert "Auth" in top_chain["description"] or "Process" in top_chain["description"]

    def test_empty_graph_raises_error(self):
        """Empty graph should raise error when getting entry nodes."""
        graph = Graph(nodes=[])
        assessments = {}

        with pytest.raises(ValueError, match="Graph has no nodes"):
            find_critical_chains(graph, assessments)

    def test_threshold_edge_case(self, simple_linear_graph):
        """Chain exactly at threshold should be included."""
        # Set up risk to produce exactly 0.8 cumulative risk
        # We need: 1 - (1-r1)(1-r2)(1-r3) = 0.8
        # So: (1-r1)(1-r2)(1-r3) = 0.2
        # If all equal: (1-r)^3 = 0.2, so 1-r = 0.2^(1/3) ≈ 0.5848
        # So r ≈ 0.4152
        assessments = {
            "a": {"risk": 0.4152},
            "b": {"risk": 0.4152},
            "c": {"risk": 0.4152}
        }

        chains = find_critical_chains(simple_linear_graph, assessments, threshold=0.8)

        # Should find the chain (>= threshold)
        assert len(chains) == 1
        assert chains[0]["risk"] >= 0.8
