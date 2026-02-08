"""
Tests for risk propagation logic.

Tests both the topological risk calculation and full graph propagation.
"""

import pytest
from src.models.graph import Node, Edge, Graph
from src.services.math.risk import calculate_topological_risk
from src.services.analysis.propagation import propagate_risk, _topological_sort


class TestTopologicalRiskCalculation:
    """Test the calculate_topological_risk function."""

    def test_no_parents_zero_local_risk(self):
        """Node with no parents and no local risk should have zero risk."""
        risk = calculate_topological_risk(
            local_failure_prob=0.0,
            multiplier=1.2,
            parent_risk_scores=[]
        )
        assert risk == 0.0

    def test_no_parents_with_local_risk(self):
        """Node with no parents should have risk = local_risk * multiplier."""
        risk = calculate_topological_risk(
            local_failure_prob=0.3,
            multiplier=1.2,
            parent_risk_scores=[]
        )
        # R = 1 - (1 - 0.3 * 1.2) = 1 - 0.64 = 0.36
        assert risk == pytest.approx(0.36, abs=1e-6)

    def test_multiplier_capping(self):
        """High local risk * multiplier should cap at 1.0."""
        risk = calculate_topological_risk(
            local_failure_prob=0.9,
            multiplier=1.5,
            parent_risk_scores=[]
        )
        # 0.9 * 1.5 = 1.35, capped to 1.0
        # R = 1 - (1 - 1.0) = 1.0
        assert risk == 1.0

    def test_one_parent_zero_risk(self):
        """Parent with zero risk should not increase child risk beyond local."""
        risk = calculate_topological_risk(
            local_failure_prob=0.2,
            multiplier=1.2,
            parent_risk_scores=[0.0]
        )
        # R = 1 - [(1 - 0.24) * (1 - 0)] = 1 - 0.76 = 0.24
        assert risk == pytest.approx(0.24, abs=1e-6)

    def test_one_parent_with_risk(self):
        """Parent risk should cascade to child."""
        risk = calculate_topological_risk(
            local_failure_prob=0.3,
            multiplier=1.2,
            parent_risk_scores=[0.5]
        )
        # Local: 0.3 * 1.2 = 0.36, success = 0.64
        # Parent success: 1 - 0.5 = 0.5
        # Total success: 0.64 * 0.5 = 0.32
        # R = 1 - 0.32 = 0.68
        assert risk == pytest.approx(0.68, abs=1e-6)

    def test_multiple_parents(self):
        """Multiple parent risks should compound."""
        risk = calculate_topological_risk(
            local_failure_prob=0.2,
            multiplier=1.2,
            parent_risk_scores=[0.3, 0.4, 0.5]
        )
        # Local: 0.2 * 1.2 = 0.24, success = 0.76
        # Parent successes: 0.7, 0.6, 0.5
        # Product: 0.7 * 0.6 * 0.5 = 0.21
        # Total success: 0.76 * 0.21 = 0.1596
        # R = 1 - 0.1596 = 0.8404
        assert risk == pytest.approx(0.8404, abs=1e-6)

    def test_all_parents_failed(self):
        """If all parents fail (risk=1.0), child should also fail."""
        risk = calculate_topological_risk(
            local_failure_prob=0.1,
            multiplier=1.2,
            parent_risk_scores=[1.0, 1.0]
        )
        # Parent success product = 0 * 0 = 0
        # Total success = 0.88 * 0 = 0
        # R = 1 - 0 = 1.0
        assert risk == 1.0

    def test_edge_case_all_zeros(self):
        """All zeros should result in zero risk."""
        risk = calculate_topological_risk(
            local_failure_prob=0.0,
            multiplier=1.0,
            parent_risk_scores=[0.0, 0.0, 0.0]
        )
        assert risk == 0.0

    def test_result_clamped_to_range(self):
        """Result should always be in [0, 1] range."""
        # Test various combinations
        for local in [0.0, 0.5, 1.0]:
            for mult in [0.5, 1.0, 2.0]:
                for parents in [[], [0.5], [0.9, 0.9]]:
                    risk = calculate_topological_risk(local, mult, parents)
                    assert 0.0 <= risk <= 1.0, f"Risk {risk} out of bounds"


class TestTopologicalSort:
    """Test the topological sort implementation."""

    def test_simple_linear_graph(self, sample_operation_type):
        """Linear graph should sort in order A -> B -> C."""
        nodes = [
            Node(id="A", name="A", type=sample_operation_type),
            Node(id="B", name="B", type=sample_operation_type),
            Node(id="C", name="C", type=sample_operation_type)
        ]
        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to"),
            Edge(source=nodes[1], target=nodes[2], weight=1.0, relationship="to")
        ]
        graph = Graph(nodes=nodes, edges=edges)

        sorted_nodes = _topological_sort(graph)
        sorted_ids = [n.id for n in sorted_nodes]

        assert sorted_ids == ["A", "B", "C"]

    def test_diamond_graph(self, sample_operation_type):
        """Diamond graph (A -> B,C -> D) should have valid topological order."""
        nodes = [
            Node(id="A", name="A", type=sample_operation_type),
            Node(id="B", name="B", type=sample_operation_type),
            Node(id="C", name="C", type=sample_operation_type),
            Node(id="D", name="D", type=sample_operation_type)
        ]
        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to"),
            Edge(source=nodes[0], target=nodes[2], weight=1.0, relationship="to"),
            Edge(source=nodes[1], target=nodes[3], weight=1.0, relationship="to"),
            Edge(source=nodes[2], target=nodes[3], weight=1.0, relationship="to")
        ]
        graph = Graph(nodes=nodes, edges=edges)

        sorted_nodes = _topological_sort(graph)
        sorted_ids = [n.id for n in sorted_nodes]

        # A must be first, D must be last, B and C can be in either order
        assert sorted_ids[0] == "A"
        assert sorted_ids[3] == "D"
        assert set(sorted_ids[1:3]) == {"B", "C"}

    def test_empty_graph_raises_error(self):
        """Empty graph should raise ValueError."""
        graph = Graph(nodes=[], edges=[])
        with pytest.raises(ValueError, match="Cannot perform topological sort on empty graph"):
            _topological_sort(graph)

    def test_single_node(self, sample_operation_type):
        """Single node graph should work."""
        node = Node(id="A", name="A", type=sample_operation_type)
        graph = Graph(nodes=[node], edges=[])

        sorted_nodes = _topological_sort(graph)
        assert len(sorted_nodes) == 1
        assert sorted_nodes[0].id == "A"


class TestRiskPropagation:
    """Test full risk propagation through graphs."""

    def test_linear_propagation(self, sample_operation_type):
        """Test risk propagates through linear chain A -> B -> C."""
        nodes = [
            Node(id="A", name="A", type=sample_operation_type),
            Node(id="B", name="B", type=sample_operation_type),
            Node(id="C", name="C", type=sample_operation_type)
        ]
        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to"),
            Edge(source=nodes[1], target=nodes[2], weight=1.0, relationship="to")
        ]
        graph = Graph(nodes=nodes, edges=edges)

        assessments = {
            "A": {"local_risk": 0.2},
            "B": {"local_risk": 0.3},
            "C": {"local_risk": 0.1}
        }

        result = propagate_risk(graph, assessments, multiplier=1.2)

        # A: no parents, risk = 0.2 * 1.2 = 0.24
        assert result["A"]["risk"] == pytest.approx(0.24, abs=1e-6)

        # B: parent A has risk 0.24
        # Local: 0.3 * 1.2 = 0.36, success = 0.64
        # Parent success: 1 - 0.24 = 0.76
        # Total success: 0.64 * 0.76 = 0.4864
        # Risk: 1 - 0.4864 = 0.5136
        assert result["B"]["risk"] == pytest.approx(0.5136, abs=1e-6)

        # C should have higher risk due to cascading
        assert result["C"]["risk"] > result["C"]["local_risk"]

    def test_diamond_propagation(self, sample_operation_type):
        """Test risk propagates through diamond structure."""
        nodes = [
            Node(id="A", name="A", type=sample_operation_type),
            Node(id="B", name="B", type=sample_operation_type),
            Node(id="C", name="C", type=sample_operation_type),
            Node(id="D", name="D", type=sample_operation_type)
        ]
        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to"),
            Edge(source=nodes[0], target=nodes[2], weight=1.0, relationship="to"),
            Edge(source=nodes[1], target=nodes[3], weight=1.0, relationship="to"),
            Edge(source=nodes[2], target=nodes[3], weight=1.0, relationship="to")
        ]
        graph = Graph(nodes=nodes, edges=edges)

        assessments = {
            "A": {"local_risk": 0.3},
            "B": {"local_risk": 0.2},
            "C": {"local_risk": 0.2},
            "D": {"local_risk": 0.1}
        }

        result = propagate_risk(graph, assessments, multiplier=1.2)

        # A: entry node
        assert result["A"]["risk"] == pytest.approx(0.36, abs=1e-6)

        # B and C should both cascade from A
        assert result["B"]["risk"] > result["B"]["local_risk"]
        assert result["C"]["risk"] > result["C"]["local_risk"]

        # D should cascade from both B and C
        assert result["D"]["risk"] > result["D"]["local_risk"]
        assert result["D"]["risk"] > result["B"]["risk"]
        assert result["D"]["risk"] > result["C"]["risk"]

    def test_zero_risk_nodes(self, sample_operation_type):
        """Test propagation with zero-risk nodes."""
        nodes = [
            Node(id="A", name="A", type=sample_operation_type),
            Node(id="B", name="B", type=sample_operation_type)
        ]
        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to")
        ]
        graph = Graph(nodes=nodes, edges=edges)

        assessments = {
            "A": {"local_risk": 0.0},
            "B": {"local_risk": 0.0}
        }

        result = propagate_risk(graph, assessments)

        assert result["A"]["risk"] == 0.0
        assert result["B"]["risk"] == 0.0

    def test_high_risk_propagation(self, sample_operation_type):
        """Test that high parent risk significantly increases child risk."""
        nodes = [
            Node(id="A", name="A", type=sample_operation_type),
            Node(id="B", name="B", type=sample_operation_type)
        ]
        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to")
        ]
        graph = Graph(nodes=nodes, edges=edges)

        assessments = {
            "A": {"local_risk": 0.9},
            "B": {"local_risk": 0.1}
        }

        result = propagate_risk(graph, assessments, multiplier=1.2)

        # A has very high risk (capped at 1.0 due to multiplier)
        assert result["A"]["risk"] == 1.0

        # B should have very high risk despite low local risk
        assert result["B"]["risk"] > 0.9

    def test_custom_multiplier(self, sample_operation_type):
        """Test that multiplier affects risk calculation."""
        node = Node(id="A", name="A", type=sample_operation_type)
        graph = Graph(nodes=[node], edges=[])

        # Test with multiplier 1.0
        assessments_low = {"A": {"local_risk": 0.5}}
        result_low = propagate_risk(graph, assessments_low, multiplier=1.0)

        # Test with multiplier 2.0
        assessments_high = {"A": {"local_risk": 0.5}}
        result_high = propagate_risk(graph, assessments_high, multiplier=2.0)

        assert result_low["A"]["risk"] == 0.5
        assert result_high["A"]["risk"] == 1.0  # Capped

    def test_empty_graph(self):
        """Empty graph should return assessments unchanged."""
        graph = Graph(nodes=[], edges=[])
        assessments = {}

        result = propagate_risk(graph, assessments)
        assert result == {}

    def test_missing_node_assessment_raises_error(self, sample_operation_type):
        """Missing node assessment should raise ValueError."""
        node = Node(id="A", name="A", type=sample_operation_type)
        graph = Graph(nodes=[node], edges=[])
        assessments = {}  # Missing "A"

        with pytest.raises(ValueError, match="Node A missing from node_assessments"):
            propagate_risk(graph, assessments)

    def test_missing_local_risk_raises_error(self, sample_operation_type):
        """Missing local_risk field should raise ValueError."""
        node = Node(id="A", name="A", type=sample_operation_type)
        graph = Graph(nodes=[node], edges=[])
        assessments = {"A": {}}  # Missing "local_risk"

        with pytest.raises(ValueError, match="assessment missing 'local_risk' field"):
            propagate_risk(graph, assessments)

    def test_invalid_local_risk_range_raises_error(self, sample_operation_type):
        """local_risk outside [0, 1] should raise ValueError."""
        node = Node(id="A", name="A", type=sample_operation_type)
        graph = Graph(nodes=[node], edges=[])

        # Test negative risk
        assessments = {"A": {"local_risk": -0.1}}
        with pytest.raises(ValueError, match="invalid local_risk"):
            propagate_risk(graph, assessments)

        # Test risk > 1
        assessments = {"A": {"local_risk": 1.5}}
        with pytest.raises(ValueError, match="invalid local_risk"):
            propagate_risk(graph, assessments)

    def test_all_risks_in_valid_range(self, sample_operation_type):
        """All computed risks should stay in [0, 1] range."""
        # Create a complex graph
        nodes = [Node(id=f"N{i}", name=f"Node{i}", type=sample_operation_type) for i in range(10)]
        edges = [
            Edge(source=nodes[i], target=nodes[i+1], weight=1.0, relationship="to")
            for i in range(9)
        ]
        graph = Graph(nodes=nodes, edges=edges)

        # Test with various risk levels
        assessments = {f"N{i}": {"local_risk": i / 10.0} for i in range(10)}

        result = propagate_risk(graph, assessments, multiplier=1.5)

        for node_id, assessment in result.items():
            assert 0.0 <= assessment["risk"] <= 1.0, \
                f"Node {node_id} risk {assessment['risk']} out of range"

    def test_preserves_other_assessment_data(self, sample_operation_type):
        """Propagation should preserve other fields in assessments."""
        node = Node(id="A", name="A", type=sample_operation_type)
        graph = Graph(nodes=[node], edges=[])

        assessments = {
            "A": {
                "local_risk": 0.3,
                "influence": 0.8,
                "other_data": "preserved"
            }
        }

        result = propagate_risk(graph, assessments)

        assert result["A"]["local_risk"] == 0.3
        assert result["A"]["influence"] == 0.8
        assert result["A"]["other_data"] == "preserved"
        assert "risk" in result["A"]

    def test_complex_multi_level_graph(self, sample_operation_type):
        """Test propagation through a complex multi-level graph."""
        # Create tree structure:
        #       A
        #      / \
        #     B   C
        #    / \ / \
        #   D   E   F
        nodes = {id: Node(id=id, name=id, type=sample_operation_type)
                 for id in ["A", "B", "C", "D", "E", "F"]}

        edges = [
            Edge(source=nodes["A"], target=nodes["B"], weight=1.0, relationship="to"),
            Edge(source=nodes["A"], target=nodes["C"], weight=1.0, relationship="to"),
            Edge(source=nodes["B"], target=nodes["D"], weight=1.0, relationship="to"),
            Edge(source=nodes["B"], target=nodes["E"], weight=1.0, relationship="to"),
            Edge(source=nodes["C"], target=nodes["E"], weight=1.0, relationship="to"),
            Edge(source=nodes["C"], target=nodes["F"], weight=1.0, relationship="to"),
        ]
        graph = Graph(nodes=list(nodes.values()), edges=edges)

        assessments = {
            "A": {"local_risk": 0.2},
            "B": {"local_risk": 0.15},
            "C": {"local_risk": 0.15},
            "D": {"local_risk": 0.1},
            "E": {"local_risk": 0.1},
            "F": {"local_risk": 0.1}
        }

        result = propagate_risk(graph, assessments, multiplier=1.2)

        # Verify hierarchical risk propagation
        # A is root
        assert result["A"]["risk"] == pytest.approx(0.24, abs=1e-6)

        # B and C depend on A
        assert result["B"]["risk"] > result["A"]["risk"]
        assert result["C"]["risk"] > result["A"]["risk"]

        # D depends only on B
        assert result["D"]["risk"] > result["B"]["risk"]

        # E depends on both B and C (highest risk)
        assert result["E"]["risk"] > result["B"]["risk"]
        assert result["E"]["risk"] > result["C"]["risk"]
        assert result["E"]["risk"] > result["D"]["risk"]

        # F depends only on C
        assert result["F"]["risk"] > result["C"]["risk"]


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
