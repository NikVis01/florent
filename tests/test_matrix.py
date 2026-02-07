"""
Tests for 2x2 Action Matrix Classification
"""

import pytest
from src.services.analysis.matrix import classify_node, generate_matrix


class TestClassifyNode:
    """Test the classify_node function."""

    def test_mitigate_quadrant(self):
        """Test Q1: High Risk, High Influence -> Mitigate"""
        assert classify_node(influence=0.8, risk=0.8) == "mitigate"
        assert classify_node(influence=0.71, risk=0.71) == "mitigate"
        assert classify_node(influence=1.0, risk=1.0) == "mitigate"
        assert classify_node(influence=0.9, risk=0.75) == "mitigate"

    def test_automate_quadrant(self):
        """Test Q2: Low Risk, High Influence -> Automate"""
        assert classify_node(influence=0.8, risk=0.3) == "automate"
        assert classify_node(influence=0.71, risk=0.7) == "automate"
        assert classify_node(influence=1.0, risk=0.0) == "automate"
        assert classify_node(influence=0.9, risk=0.5) == "automate"

    def test_contingency_quadrant(self):
        """Test Q3: High Risk, Low Influence -> Contingency"""
        assert classify_node(influence=0.3, risk=0.8) == "contingency"
        assert classify_node(influence=0.7, risk=0.71) == "contingency"
        assert classify_node(influence=0.0, risk=1.0) == "contingency"
        assert classify_node(influence=0.5, risk=0.9) == "contingency"

    def test_delegate_quadrant(self):
        """Test Q4: Low Risk, Low Influence -> Delegate"""
        assert classify_node(influence=0.3, risk=0.3) == "delegate"
        assert classify_node(influence=0.7, risk=0.7) == "delegate"
        assert classify_node(influence=0.0, risk=0.0) == "delegate"
        assert classify_node(influence=0.5, risk=0.5) == "delegate"

    def test_boundary_conditions(self):
        """Test boundary conditions at threshold of 0.7"""
        # Exactly 0.7 should be considered low
        assert classify_node(influence=0.7, risk=0.7) == "delegate"
        assert classify_node(influence=0.7, risk=0.71) == "contingency"
        assert classify_node(influence=0.71, risk=0.7) == "automate"

    def test_edge_cases(self):
        """Test edge cases with extreme values"""
        assert classify_node(influence=0.0, risk=0.0) == "delegate"
        assert classify_node(influence=1.0, risk=1.0) == "mitigate"
        assert classify_node(influence=0.0, risk=1.0) == "contingency"
        assert classify_node(influence=1.0, risk=0.0) == "automate"


class TestGenerateMatrix:
    """Test the generate_matrix function."""

    def test_empty_assessments(self):
        """Test with no node assessments"""
        result = generate_matrix({})
        assert result == {
            "mitigate": [],
            "automate": [],
            "contingency": [],
            "delegate": []
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

        assert result["mitigate"] == ["node_mitigate"]
        assert result["automate"] == ["node_automate"]
        assert result["contingency"] == ["node_contingency"]
        assert result["delegate"] == ["node_delegate"]

    def test_multiple_nodes_same_quadrant(self):
        """Test with multiple nodes in the same quadrant"""
        assessments = {
            "node1": {"influence": 0.8, "risk": 0.8},
            "node2": {"influence": 0.9, "risk": 0.9},
            "node3": {"influence": 0.75, "risk": 0.85}
        }
        result = generate_matrix(assessments)

        assert len(result["mitigate"]) == 3
        assert set(result["mitigate"]) == {"node1", "node2", "node3"}
        assert result["automate"] == []
        assert result["contingency"] == []
        assert result["delegate"] == []

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

        assert set(result["mitigate"]) == {"critical_task", "another_critical"}
        assert result["automate"] == ["routine_task"]
        assert result["contingency"] == ["minor_risk"]
        assert result["delegate"] == ["low_priority"]

    def test_missing_influence_or_risk(self):
        """Test with missing influence or risk values (should default to 0.0)"""
        assessments = {
            "missing_influence": {"risk": 0.8},
            "missing_risk": {"influence": 0.8},
            "missing_both": {}
        }
        result = generate_matrix(assessments)

        # Missing influence (0.0) + high risk (0.8) -> contingency
        assert "missing_influence" in result["contingency"]
        # High influence (0.8) + missing risk (0.0) -> automate
        assert "missing_risk" in result["automate"]
        # Both missing (0.0, 0.0) -> delegate
        assert "missing_both" in result["delegate"]

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

        assert result["mitigate"] == ["node1"]

    def test_boundary_values_in_matrix(self):
        """Test boundary values across the matrix"""
        assessments = {
            "exactly_threshold": {"influence": 0.7, "risk": 0.7},
            "just_above": {"influence": 0.71, "risk": 0.71},
            "just_below": {"influence": 0.69, "risk": 0.69}
        }
        result = generate_matrix(assessments)

        assert "exactly_threshold" in result["delegate"]
        assert "just_above" in result["mitigate"]
        assert "just_below" in result["delegate"]

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
        assert "deploy_production" in result["mitigate"]

        # High impact, low risk - good candidates for automation
        assert "update_docs" in result["automate"]
        assert "ci_pipeline" in result["automate"]

        # Low impact, high risk - need contingency plans
        assert "security_patch" in result["contingency"]
        assert "dependency_update" in result["contingency"]

        # Low impact, low risk - can be delegated
        assert "refactor_old_code" in result["delegate"]
        assert "fix_typo" in result["delegate"]


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
        assert len(result["mitigate"]) == 1
        assert len(result["automate"]) == 1
        assert len(result["contingency"]) == 1
        assert len(result["delegate"]) == 1

        # Total nodes should equal input
        total_nodes = sum(len(nodes) for nodes in result.values())
        assert total_nodes == len(assessments)
