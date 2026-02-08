"""
Tests for Type A-D Matrix Classification
"""

import pytest
from src.services.analysis.matrix import classify_node, generate_matrix


class TestClassifyNode:
    """Test the classify_node function."""

    def test_type_a_quadrant(self):
        """Test Type A: High Risk, High Influence"""
        assert classify_node(influence=0.8, risk=0.8) == "Type A"
        assert classify_node(influence=0.71, risk=0.71) == "Type A"
        assert classify_node(influence=1.0, risk=1.0) == "Type A"
        assert classify_node(influence=0.9, risk=0.75) == "Type A"

    def test_type_b_quadrant(self):
        """Test Type B: Low Risk, High Influence"""
        assert classify_node(influence=0.8, risk=0.3) == "Type B"
        assert classify_node(influence=0.71, risk=0.7) == "Type B"
        assert classify_node(influence=1.0, risk=0.0) == "Type B"
        assert classify_node(influence=0.9, risk=0.5) == "Type B"

    def test_type_c_quadrant(self):
        """Test Type C: High Risk, Low Influence"""
        assert classify_node(influence=0.3, risk=0.8) == "Type C"
        assert classify_node(influence=0.7, risk=0.71) == "Type C"
        assert classify_node(influence=0.0, risk=1.0) == "Type C"
        assert classify_node(influence=0.5, risk=0.9) == "Type C"

    def test_type_d_quadrant(self):
        """Test Type D: Low Risk, Low Influence"""
        assert classify_node(influence=0.3, risk=0.3) == "Type D"
        assert classify_node(influence=0.7, risk=0.7) == "Type D"
        assert classify_node(influence=0.0, risk=0.0) == "Type D"
        assert classify_node(influence=0.5, risk=0.5) == "Type D"

    def test_boundary_conditions(self):
        """Test boundary conditions at threshold of 0.7"""
        # Exactly 0.7 should be considered low
        assert classify_node(influence=0.7, risk=0.7) == "Type D"
        assert classify_node(influence=0.7, risk=0.71) == "Type C"
        assert classify_node(influence=0.71, risk=0.7) == "Type B"

    def test_edge_cases(self):
        """Test edge cases with extreme values"""
        assert classify_node(influence=0.0, risk=0.0) == "Type D"
        assert classify_node(influence=1.0, risk=1.0) == "Type A"
        assert classify_node(influence=0.0, risk=1.0) == "Type C"
        assert classify_node(influence=1.0, risk=0.0) == "Type B"


class TestGenerateMatrix:
    """Test the generate_matrix function."""

    def test_empty_assessments(self):
        """Test with no node assessments"""
        result = generate_matrix({})
        assert result == {
            "Type A": [],
            "Type B": [],
            "Type C": [],
            "Type D": []
        }

    def test_single_node_per_quadrant(self):
        """Test with one node in each quadrant"""
        assessments = {
            "node_mitigate": {"influence": 0.8, "risk": 0.8},
            "node_automate": {"influence": 0.8, "risk": 0.3},
            "node_contingency": {"influence": 0.3, "risk": 0.8},
            "node_delegate": {"influence": 0.3, "risk": 0.3}
        }
        result = generate_matrix(assessments)

        assert result["Type A"] == ["node_mitigate"]
        assert result["Type B"] == ["node_automate"]
        assert result["Type C"] == ["node_contingency"]
        assert result["Type D"] == ["node_delegate"]

    def test_multiple_nodes_same_quadrant(self):
        """Test with multiple nodes in the same quadrant"""
        assessments = {
            "node1": {"influence": 0.8, "risk": 0.8},
            "node2": {"influence": 0.9, "risk": 0.9},
            "node3": {"influence": 0.75, "risk": 0.85}
        }
        result = generate_matrix(assessments)

        assert len(result["Type A"]) == 3
        assert set(result["Type A"]) == {"node1", "node2", "node3"}
        assert result["Type B"] == []
        assert result["Type C"] == []
        assert result["Type D"] == []

    def test_mixed_quadrants(self):
        """Test with nodes distributed across quadrants"""
        assessments = {
            "critical_task": {"influence": 0.95, "risk": 0.9},
            "routine_task": {"influence": 0.85, "risk": 0.2},
            "minor_risk": {"influence": 0.4, "risk": 0.8},
            "low_priority": {"influence": 0.3, "risk": 0.4},
            "another_critical": {"influence": 0.8, "risk": 0.75}
        }
        result = generate_matrix(assessments)

        assert set(result["Type A"]) == {"critical_task", "another_critical"}
        assert result["Type B"] == ["routine_task"]
        assert result["Type C"] == ["minor_risk"]
        assert result["Type D"] == ["low_priority"]

    def test_missing_influence_or_risk(self):
        """Test with missing influence or risk values (should default to 0.0)"""
        assessments = {
            "missing_influence": {"risk": 0.8},
            "missing_risk": {"influence": 0.8},
            "missing_both": {}
        }
        result = generate_matrix(assessments)

        # Missing influence (0.0) + high risk (0.8) -> contingency
        assert "missing_influence" in result["Type C"]
        # High influence (0.8) + missing risk (0.0) -> automate
        assert "missing_risk" in result["Type B"]
        # Both missing (0.0, 0.0) -> delegate
        assert "missing_both" in result["Type D"]

    def test_additional_assessment_fields(self):
        """Test that additional fields in assessments don't affect classification"""
        assessments = {
            "node1": {
                "influence": 0.8,
                "risk": 0.9,
                "description": "Important task",
                "priority": 1,
                "extra_data": {"foo": "bar"}
            }
        }
        result = generate_matrix(assessments)

        assert result["Type A"] == ["node1"]

    def test_boundary_values_in_matrix(self):
        """Test boundary values across the matrix"""
        assessments = {
            "exactly_threshold": {"influence": 0.7, "risk": 0.7},
            "just_above": {"influence": 0.71, "risk": 0.71},
            "just_below": {"influence": 0.69, "risk": 0.69}
        }
        result = generate_matrix(assessments)

        result = generate_matrix(assessments)
        
        assert "exactly_threshold" in result["Type D"]
        assert "just_above" in result["Type A"]
        assert "just_below" in result["Type D"]

    def test_real_world_scenario(self):
        """Test with a realistic project scenario"""
        assessments = {
            "deploy_production": {"influence": 0.95, "risk": 0.85},
            "update_docs": {"influence": 0.75, "risk": 0.1},
            "security_patch": {"influence": 0.6, "risk": 0.9},
            "refactor_old_code": {"influence": 0.4, "risk": 0.3},
            "ci_pipeline": {"influence": 0.8, "risk": 0.4},
            "dependency_update": {"influence": 0.5, "risk": 0.75},
            "fix_typo": {"influence": 0.2, "risk": 0.1}
        }
        result = generate_matrix(assessments)

        # High impact, high risk - needs immediate mitigation
        assert "deploy_production" in result["Type A"]

        # High impact, low risk - good candidates for automation
        assert "update_docs" in result["Type B"]
        assert "ci_pipeline" in result["Type B"]

        # Low impact, high risk - need contingency plans
        assert "security_patch" in result["Type C"]
        assert "dependency_update" in result["Type C"]

        # Low impact, low risk - can be delegated
        assert "refactor_old_code" in result["Type D"]
        assert "fix_typo" in result["Type D"]


class TestIntegration:
    """Integration tests for the matrix module."""

    def test_classify_and_generate_consistency(self):
        """Ensure classify_node and generate_matrix produce consistent results"""
        assessments = {
            "task1": {"influence": 0.8, "risk": 0.9},
            "task2": {"influence": 0.5, "risk": 0.3}
        }

        # Get matrix results
        matrix = generate_matrix(assessments)

        # Verify individual classifications match
        for node_id, assessment in assessments.items():
            expected_quadrant = classify_node(
                assessment["influence"],
                assessment["risk"]
            )
            assert node_id in matrix[expected_quadrant]

    def test_all_quadrants_represented(self):
        """Verify all four quadrants can be populated"""
        assessments = {
            "q1": {"influence": 0.9, "risk": 0.9},
            "q2": {"influence": 0.9, "risk": 0.1},
            "q3": {"influence": 0.1, "risk": 0.9},
            "q4": {"influence": 0.1, "risk": 0.1}
        }
        result = generate_matrix(assessments)

        # All quadrants should have exactly one node
        result = generate_matrix(assessments)
        
        # All quadrants should have exactly one node
        assert len(result["Type A"]) == 1
        assert len(result["Type B"]) == 1
        assert len(result["Type C"]) == 1
        assert len(result["Type D"]) == 1

        # Total nodes should equal input
        total_nodes = sum(len(nodes) for nodes in result.values())
        assert total_nodes == len(assessments)
