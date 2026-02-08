"""
Tests for Influence vs Importance Matrix Classification (2x2 Matrix)

Tests the matrix_classifier module which classifies nodes based on:
- Importance (Y-axis): How critical the node is to project success
- Influence (X-axis): How much control the firm has over the node

Quadrants:
- Type A: High Influence, High Importance (Strategic Wins - leverage these)
- Type B: High Influence, Low Importance (Quick Wins - optimize/automate)
- Type C: Low Influence, High Importance (Critical Dependencies - mitigate risk)
- Type D: Low Influence, Low Importance (Monitor - low priority)
"""

from src.services.agent.analysis.matrix_classifier import (
    classify_node,
    classify_all_nodes,
    should_bid,
    RiskQuadrant,
    NodeClassification
)
from src.models.analysis import NodeAssessment


class TestClassifyNode:
    """Test the classify_node function."""

    def test_type_a_strategic_wins(self):
        """Test Type A: High Influence, High Importance (Strategic Wins)"""
        result = classify_node("node1", "Strategic Task", influence_score=0.8, importance_score=0.8)
        assert result.quadrant == RiskQuadrant.TYPE_A

        result = classify_node("node2", "Core Competency", influence_score=0.9, importance_score=0.7)
        assert result.quadrant == RiskQuadrant.TYPE_A

    def test_type_b_quick_wins(self):
        """Test Type B: High Influence, Low Importance (Quick Wins)"""
        result = classify_node("node1", "Automate This", influence_score=0.8, importance_score=0.3)
        assert result.quadrant == RiskQuadrant.TYPE_B

        result = classify_node("node2", "Nice to Have", influence_score=0.9, importance_score=0.5)
        assert result.quadrant == RiskQuadrant.TYPE_B

    def test_type_c_critical_dependencies(self):
        """Test Type C: Low Influence, High Importance (Critical Dependencies)"""
        result = classify_node("node1", "External Dependency", influence_score=0.3, importance_score=0.8)
        assert result.quadrant == RiskQuadrant.TYPE_C

        result = classify_node("node2", "Regulatory Approval", influence_score=0.2, importance_score=0.9)
        assert result.quadrant == RiskQuadrant.TYPE_C

    def test_type_d_monitor(self):
        """Test Type D: Low Influence, Low Importance (Monitor)"""
        result = classify_node("node1", "Minor Task", influence_score=0.3, importance_score=0.3)
        assert result.quadrant == RiskQuadrant.TYPE_D

        result = classify_node("node2", "Low Priority", influence_score=0.5, importance_score=0.4)
        assert result.quadrant == RiskQuadrant.TYPE_D

    def test_boundary_conditions(self):
        """Test boundary conditions at default threshold of 0.6"""
        # Exactly 0.6 should be considered low (not greater than)
        result = classify_node("boundary", "Boundary Test",
                              influence_score=0.6, importance_score=0.6,
                              influence_threshold=0.6, importance_threshold=0.6)
        assert result.quadrant == RiskQuadrant.TYPE_D

        # Just above 0.6
        result = classify_node("above", "Above Threshold",
                              influence_score=0.61, importance_score=0.61,
                              influence_threshold=0.6, importance_threshold=0.6)
        assert result.quadrant == RiskQuadrant.TYPE_A

    def test_custom_thresholds(self):
        """Test classification with custom thresholds"""
        # With 0.7 thresholds
        result = classify_node("node1", "Test",
                              influence_score=0.65, importance_score=0.65,
                              influence_threshold=0.7, importance_threshold=0.7)
        assert result.quadrant == RiskQuadrant.TYPE_D

        result = classify_node("node2", "Test",
                              influence_score=0.75, importance_score=0.75,
                              influence_threshold=0.7, importance_threshold=0.7)
        assert result.quadrant == RiskQuadrant.TYPE_A

    def test_node_classification_structure(self):
        """Test that NodeClassification contains expected fields"""
        result = classify_node("test_id", "Test Node",
                              influence_score=0.8, importance_score=0.7)

        assert result.node_id == "test_id"
        assert result.node_name == "Test Node"
        assert result.influence_score == 0.8
        assert result.importance_score == 0.7
        assert isinstance(result.quadrant, RiskQuadrant)


class TestClassifyAllNodes:
    """Test the classify_all_nodes function."""

    def test_empty_assessments(self):
        """Test with no node assessments"""
        result = classify_all_nodes({}, {})

        assert result[RiskQuadrant.TYPE_A] == []
        assert result[RiskQuadrant.TYPE_B] == []
        assert result[RiskQuadrant.TYPE_C] == []
        assert result[RiskQuadrant.TYPE_D] == []

    def test_single_node_per_quadrant(self):
        """Test with one node in each quadrant"""
        node_assessments = {
            "strategic": NodeAssessment(
                node_id="strategic", node_name="Strategic Win",
                importance_score=0.8, influence_score=0.8, risk_level=0.16, reasoning="Test"
            ),
            "quick": NodeAssessment(
                node_id="quick", node_name="Quick Win",
                importance_score=0.3, influence_score=0.8, risk_level=0.21, reasoning="Test"
            ),
            "critical": NodeAssessment(
                node_id="critical", node_name="Critical Dependency",
                importance_score=0.8, influence_score=0.3, risk_level=0.56, reasoning="Test"
            ),
            "monitor": NodeAssessment(
                node_id="monitor", node_name="Monitor",
                importance_score=0.3, influence_score=0.3, risk_level=0.21, reasoning="Test"
            )
        }
        node_names = {k: v.node_name for k, v in node_assessments.items()}

        result = classify_all_nodes(node_assessments, node_names)

        assert len(result[RiskQuadrant.TYPE_A]) == 1
        assert result[RiskQuadrant.TYPE_A][0].node_id == "strategic"

        assert len(result[RiskQuadrant.TYPE_B]) == 1
        assert result[RiskQuadrant.TYPE_B][0].node_id == "quick"

        assert len(result[RiskQuadrant.TYPE_C]) == 1
        assert result[RiskQuadrant.TYPE_C][0].node_id == "critical"

        assert len(result[RiskQuadrant.TYPE_D]) == 1
        assert result[RiskQuadrant.TYPE_D][0].node_id == "monitor"

    def test_multiple_nodes_same_quadrant(self):
        """Test with multiple nodes in the same quadrant"""
        node_assessments = {
            f"strategic_{i}": NodeAssessment(
                node_id=f"strategic_{i}", node_name=f"Strategic {i}",
                importance_score=0.7 + i*0.05, influence_score=0.7 + i*0.05,
                risk_level=0.2, reasoning="Test"
            )
            for i in range(3)
        }
        node_names = {k: v.node_name for k, v in node_assessments.items()}

        result = classify_all_nodes(node_assessments, node_names)

        assert len(result[RiskQuadrant.TYPE_A]) == 3
        assert all(n.node_id.startswith("strategic_") for n in result[RiskQuadrant.TYPE_A])

    def test_custom_thresholds(self):
        """Test classification with custom thresholds"""
        node_assessments = {
            "node1": NodeAssessment(
                node_id="node1", node_name="Node 1",
                importance_score=0.65, influence_score=0.65, risk_level=0.23, reasoning="Test"
            )
        }
        node_names = {"node1": "Node 1"}

        # With 0.6 threshold, should be Type A
        result = classify_all_nodes(node_assessments, node_names,
                                   influence_threshold=0.6, importance_threshold=0.6)
        assert len(result[RiskQuadrant.TYPE_A]) == 1

        # With 0.7 threshold, should be Type D
        result = classify_all_nodes(node_assessments, node_names,
                                   influence_threshold=0.7, importance_threshold=0.7)
        assert len(result[RiskQuadrant.TYPE_D]) == 1


class TestShouldBid:
    """Test the bidding decision logic."""

    def test_no_critical_chain(self):
        """Test with empty critical chain"""
        classifications = {
            RiskQuadrant.TYPE_A: [],
            RiskQuadrant.TYPE_B: [],
            RiskQuadrant.TYPE_C: [
                NodeClassification(
                    node_id="crit1", node_name="Critical 1",
                    influence_score=0.3, importance_score=0.8,
                    quadrant=RiskQuadrant.TYPE_C
                )
            ],
            RiskQuadrant.TYPE_D: []
        }

        result = should_bid(classifications, [])
        assert result is True  # Should bid if no chain to evaluate

    def test_no_critical_dependencies(self):
        """Test when critical chain has no Type C nodes"""
        classifications = {
            RiskQuadrant.TYPE_A: [],
            RiskQuadrant.TYPE_B: [],
            RiskQuadrant.TYPE_C: [],
            RiskQuadrant.TYPE_D: []
        }

        result = should_bid(classifications, ["node1", "node2", "node3"])
        assert result is True  # No critical deps, should bid

    def test_acceptable_critical_dep_ratio(self):
        """Test when critical dep ratio is <= 50%"""
        classifications = {
            RiskQuadrant.TYPE_A: [],
            RiskQuadrant.TYPE_B: [],
            RiskQuadrant.TYPE_C: [
                NodeClassification(
                    node_id="crit1", node_name="Critical 1",
                    influence_score=0.3, importance_score=0.8,
                    quadrant=RiskQuadrant.TYPE_C
                )
            ],
            RiskQuadrant.TYPE_D: []
        }

        # 1 critical dep out of 4 nodes = 25% (acceptable)
        result = should_bid(classifications, ["node1", "crit1", "node2", "node3"])
        assert result is True

        # 2 critical deps out of 4 nodes = 50% (acceptable, at threshold)
        classifications[RiskQuadrant.TYPE_C].append(
            NodeClassification(
                node_id="crit2", node_name="Critical 2",
                influence_score=0.2, importance_score=0.9,
                quadrant=RiskQuadrant.TYPE_C
            )
        )
        result = should_bid(classifications, ["crit1", "node1", "crit2", "node2"])
        assert result is True

    def test_excessive_critical_dep_ratio(self):
        """Test when critical dep ratio > 50%"""
        classifications = {
            RiskQuadrant.TYPE_A: [],
            RiskQuadrant.TYPE_B: [],
            RiskQuadrant.TYPE_C: [
                NodeClassification(
                    node_id=f"crit{i}", node_name=f"Critical {i}",
                    influence_score=0.3, importance_score=0.8,
                    quadrant=RiskQuadrant.TYPE_C
                )
                for i in range(3)
            ],
            RiskQuadrant.TYPE_D: []
        }

        # 3 critical deps out of 4 nodes = 75% (too high)
        result = should_bid(classifications, ["crit0", "crit1", "node1", "crit2"])
        assert result is False

    def test_all_critical_path_is_critical_deps(self):
        """Test when entire critical path is Type C nodes"""
        classifications = {
            RiskQuadrant.TYPE_A: [],
            RiskQuadrant.TYPE_B: [],
            RiskQuadrant.TYPE_C: [
                NodeClassification(
                    node_id=f"crit{i}", node_name=f"Critical {i}",
                    influence_score=0.2, importance_score=0.9,
                    quadrant=RiskQuadrant.TYPE_C
                )
                for i in range(5)
            ],
            RiskQuadrant.TYPE_D: []
        }

        # 100% critical deps - should not bid
        result = should_bid(classifications, ["crit0", "crit1", "crit2", "crit3", "crit4"])
        assert result is False


class TestIntegration:
    """Integration tests for the matrix classifier module."""

    def test_end_to_end_classification_and_bidding(self):
        """Test complete workflow from assessments to bid decision"""
        # Create realistic node assessments
        node_assessments = {
            "entry": NodeAssessment(
                node_id="entry", node_name="Site Survey",
                importance_score=0.9, influence_score=0.8, risk_level=0.18, reasoning="Entry point"
            ),
            "design": NodeAssessment(
                node_id="design", node_name="Engineering Design",
                importance_score=0.8, influence_score=0.9, risk_level=0.08, reasoning="Core competency"
            ),
            "permit": NodeAssessment(
                node_id="permit", node_name="Regulatory Permit",
                importance_score=0.9, influence_score=0.2, risk_level=0.72, reasoning="External dependency"
            ),
            "construct": NodeAssessment(
                node_id="construct", node_name="Construction",
                importance_score=0.8, influence_score=0.7, risk_level=0.24, reasoning="Partner work"
            ),
            "handover": NodeAssessment(
                node_id="handover", node_name="Handover",
                importance_score=0.7, influence_score=0.9, risk_level=0.07, reasoning="Final step"
            )
        }
        node_names = {k: v.node_name for k, v in node_assessments.items()}

        # Classify all nodes
        classifications = classify_all_nodes(node_assessments, node_names)

        # Check classifications
        type_a_ids = {n.node_id for n in classifications[RiskQuadrant.TYPE_A]}
        type_c_ids = {n.node_id for n in classifications[RiskQuadrant.TYPE_C]}

        assert "entry" in type_a_ids  # High importance + high influence
        assert "design" in type_a_ids  # High importance + high influence
        assert "permit" in type_c_ids  # High importance + LOW influence (critical dep!)

        # Test bidding decision
        critical_chain = ["entry", "permit", "construct", "handover"]  # 1/4 = 25% critical deps
        result = should_bid(classifications, critical_chain)
        assert result is True  # Should bid - only 25% critical deps

        # Now test with mostly critical deps
        critical_chain_bad = ["permit", "entry", "permit", "permit"]  # 3/4 = 75% critical deps
        result = should_bid(classifications, critical_chain_bad)
        assert result is False  # Should not bid - too many critical deps

    def test_matrix_with_all_quadrants(self):
        """Verify all four quadrants can be populated simultaneously"""
        node_assessments = {
            "strategic": NodeAssessment(
                node_id="strategic", node_name="Strategic",
                importance_score=0.9, influence_score=0.9, risk_level=0.09, reasoning="A"
            ),
            "quick": NodeAssessment(
                node_id="quick", node_name="Quick",
                importance_score=0.2, influence_score=0.9, risk_level=0.16, reasoning="B"
            ),
            "critical": NodeAssessment(
                node_id="critical", node_name="Critical",
                importance_score=0.9, influence_score=0.2, risk_level=0.72, reasoning="C"
            ),
            "monitor": NodeAssessment(
                node_id="monitor", node_name="Monitor",
                importance_score=0.2, influence_score=0.2, risk_level=0.16, reasoning="D"
            )
        }
        node_names = {k: v.node_name for k, v in node_assessments.items()}

        result = classify_all_nodes(node_assessments, node_names)

        # Each quadrant should have exactly 1 node
        assert len(result[RiskQuadrant.TYPE_A]) == 1
        assert len(result[RiskQuadrant.TYPE_B]) == 1
        assert len(result[RiskQuadrant.TYPE_C]) == 1
        assert len(result[RiskQuadrant.TYPE_D]) == 1

        # Total should equal input
        total = sum(len(nodes) for nodes in result.values())
        assert total == len(node_assessments)
