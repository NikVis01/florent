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
        Quadrant classification: "Type A", "Type B", "Type C", or "Type D"

    Quadrant Rules:
        - Type A: High Risk (>0.7), High Influence (>0.7)
        - Type B: Low Risk (≤0.7), High Influence (>0.7)
        - Type C: High Risk (>0.7), Low Influence (≤0.7)
        - Type D: Low Risk (≤0.7), Low Influence (≤0.7)
    """
    high_risk = risk > 0.7
    high_influence = influence > 0.7

    if high_risk and high_influence:
        return "Type A"
    elif not high_risk and high_influence:
        return "Type B"
    elif high_risk and not high_influence:
        return "Type C"
    else:  # not high_risk and not high_influence
        return "Type D"


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
            "Type A": ["node1"],
            "Type B": ["node2"],
            "Type C": [],
            "Type D": ["node3"]
        }
    """
    matrix = {
        "Type A": [],
        "Type B": [],
        "Type C": [],
        "Type D": []
    }

    for node_id, assessment in node_assessments.items():
        influence = assessment.get("influence", 0.0)
        risk = assessment.get("risk", 0.0)

        quadrant = classify_node(influence, risk)
        matrix[quadrant].append(node_id)

    return matrix
