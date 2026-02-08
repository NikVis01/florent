"""
Integration test for risk propagation with the full workflow.

This demonstrates end-to-end usage of the risk propagation system.
"""

import pytest
from src.models.graph import Node, Edge, Graph
from src.models.base import OperationType
from src.services.analysis.propagation import propagate_risk
from src.services.analysis.matrix import generate_matrix


@pytest.mark.integration
class TestRiskPropagationIntegration:
    """Integration tests for risk propagation with matrix classification."""

    def test_full_workflow_with_matrix_classification(self, sample_operation_type):
        """
        Test complete workflow: propagate risk -> classify into action matrix.

        Simulates a supply chain scenario:
        - Supplier (A) -> Manufacturer (B) -> Distributor (C) -> Retailer (D)
        """
        # Build supply chain graph
        nodes = [
            Node(id="supplier", name="Raw Materials Supplier", type=sample_operation_type),
            Node(id="manufacturer", name="Product Manufacturer", type=sample_operation_type),
            Node(id="distributor", name="Distribution Center", type=sample_operation_type),
            Node(id="retailer", name="Retail Outlet", type=sample_operation_type)
        ]

        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=0.9, relationship="supplies"),
            Edge(source=nodes[1], target=nodes[2], weight=0.85, relationship="ships_to"),
            Edge(source=nodes[2], target=nodes[3], weight=0.8, relationship="delivers_to")
        ]

        graph = Graph(nodes=nodes, edges=edges)

        # Initial assessments with local risk and influence scores
        assessments = {
            "supplier": {
                "local_risk": 0.2,  # Low risk - stable supplier
                "influence": 0.9     # High influence - critical dependency
            },
            "manufacturer": {
                "local_risk": 0.3,  # Moderate risk - production issues
                "influence": 0.85    # High influence - core operation
            },
            "distributor": {
                "local_risk": 0.15, # Low risk - reliable logistics
                "influence": 0.7     # Moderate influence
            },
            "retailer": {
                "local_risk": 0.1,  # Low risk - stable retail
                "influence": 0.5     # Lower influence - customer facing
            }
        }

        # Propagate risk through the supply chain
        result = propagate_risk(graph, assessments, multiplier=1.2)

        # Verify risk propagation
        assert "risk" in result["supplier"]
        assert "risk" in result["manufacturer"]
        assert "risk" in result["distributor"]
        assert "risk" in result["retailer"]

        # Risk should increase downstream
        assert result["supplier"]["risk"] < result["manufacturer"]["risk"]
        assert result["manufacturer"]["risk"] < result["distributor"]["risk"]
        assert result["distributor"]["risk"] < result["retailer"]["risk"]

        # Generate strategic action matrix
        matrix = generate_matrix(result)

        # Verify all quadrants exist
        assert "Type A" in matrix
        assert "Type B" in matrix
        assert "Type C" in matrix
        assert "Type D" in matrix

        # With high influence and increasing risk, we should see nodes in Type A or Type B
        high_influence_nodes = matrix["Type A"] + matrix["Type B"]
        assert "supplier" in high_influence_nodes or "manufacturer" in high_influence_nodes

        print("\n=== Risk Propagation Results ===")
        for node_id, assessment in result.items():
            print(f"{node_id:15} | Local: {assessment['local_risk']:.3f} | "
                  f"Propagated: {assessment['risk']:.3f} | "
                  f"Influence: {assessment['influence']:.3f}")

        print("\n=== Strategic Action Matrix ===")
        for quadrant, node_list in matrix.items():
            print(f"{quadrant.upper():15} | {', '.join(node_list) if node_list else 'None'}")

    def test_parallel_paths_risk_amplification(self, sample_operation_type):
        r"""
        Test risk amplification when multiple risky parents converge.

        Structure:
            A (risky)
           / \
          B   C (both inherit from A)
           \ /
            D (gets risk from both B and C)
        """
        nodes = [
            Node(id="A", name="Root Node", type=sample_operation_type),
            Node(id="B", name="Path 1", type=sample_operation_type),
            Node(id="C", name="Path 2", type=sample_operation_type),
            Node(id="D", name="Converge", type=sample_operation_type)
        ]

        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to"),
            Edge(source=nodes[0], target=nodes[2], weight=1.0, relationship="to"),
            Edge(source=nodes[1], target=nodes[3], weight=1.0, relationship="to"),
            Edge(source=nodes[2], target=nodes[3], weight=1.0, relationship="to")
        ]

        graph = Graph(nodes=nodes, edges=edges)

        assessments = {
            "A": {"local_risk": 0.5, "influence": 0.9},
            "B": {"local_risk": 0.2, "influence": 0.7},
            "C": {"local_risk": 0.2, "influence": 0.7},
            "D": {"local_risk": 0.1, "influence": 0.8}
        }

        result = propagate_risk(graph, assessments, multiplier=1.2)

        # D should have very high risk due to convergence
        # Even though its local risk is low (0.1)
        assert result["D"]["risk"] > 0.8, \
            f"Expected D to have high risk from convergence, got {result['D']['risk']}"

        # D's risk should be higher than B or C individually
        assert result["D"]["risk"] > result["B"]["risk"]
        assert result["D"]["risk"] > result["C"]["risk"]

    def test_risk_with_zero_influence_nodes(self, sample_operation_type):
        """Test that risk propagates independently of influence scores."""
        nodes = [
            Node(id="A", name="A", type=sample_operation_type),
            Node(id="B", name="B", type=sample_operation_type)
        ]

        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=1.0, relationship="to")
        ]

        graph = Graph(nodes=nodes, edges=edges)

        # High risk but zero influence
        assessments = {
            "A": {"local_risk": 0.8, "influence": 0.0},
            "B": {"local_risk": 0.2, "influence": 0.0}
        }

        result = propagate_risk(graph, assessments)

        # Risk should still propagate (influence doesn't affect risk calculation)
        assert result["A"]["risk"] == pytest.approx(0.96, abs=1e-6)  # 0.8 * 1.2
        assert result["B"]["risk"] > result["B"]["local_risk"]

        # Both should end up in "Type C" quadrant (high risk, low influence)
        # A has risk 0.96, influence 0.0 -> contingency
        matrix = generate_matrix(result)
        assert "A" in matrix["Type C"]
        assert "B" in matrix["Type C"]


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
