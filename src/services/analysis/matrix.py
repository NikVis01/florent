"""
2x2 Action Matrix Classification

Classifies nodes into strategic quadrants based on influence and risk scores.
"""

from typing import Dict


def classify_node(influence: float, risk: float) -> str:
    """
    Classify a node into one of four strategic quadrants.

    Args:
        influence: Influence score (0.0 to 1.0)
        risk: Risk score (0.0 to 1.0)

    Returns:
        Quadrant classification: "mitigate", "automate", "contingency", or "delegate"

    Quadrant Rules:
        - Q1 Mitigate: High Risk (>0.7), High Influence (>0.7)
        - Q2 Automate: Low Risk (≤0.7), High Influence (>0.7)
        - Q3 Contingency: High Risk (>0.7), Low Influence (≤0.7)
        - Q4 Delegate: Low Risk (≤0.7), Low Influence (≤0.7)
    """
    high_risk = risk > 0.7
    high_influence = influence > 0.7

    if high_risk and high_influence:
        return "mitigate"
    elif not high_risk and high_influence:
        return "automate"
    elif high_risk and not high_influence:
        return "contingency"
    else:  # not high_risk and not high_influence
        return "delegate"


def generate_matrix(node_assessments: Dict) -> dict:
    """
    Group all nodes by their strategic quadrant.

    Args:
        node_assessments: Dictionary mapping node_id to assessment data.
                         Each assessment must have 'influence' and 'risk' keys.
                         Example: {
                             "node1": {"influence": 0.8, "risk": 0.9, ...},
                             "node2": {"influence": 0.5, "risk": 0.3, ...}
                         }

    Returns:
        Dictionary with quadrants as keys and lists of node_ids as values.
        Example: {
            "mitigate": ["node1"],
            "automate": ["node2"],
            "contingency": [],
            "delegate": ["node3"]
        }
    """
    matrix = {
        "mitigate": [],
        "automate": [],
        "contingency": [],
        "delegate": []
    }

    for node_id, assessment in node_assessments.items():
        influence = assessment.get("influence", 0.0)
        risk = assessment.get("risk", 0.0)

        quadrant = classify_node(influence, risk)
        matrix[quadrant].append(node_id)

    return matrix
