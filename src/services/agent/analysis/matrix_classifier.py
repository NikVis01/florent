"""2x2 Matrix Classification for Infrastructure Risk Analysis."""
from typing import Dict, List, TYPE_CHECKING
if TYPE_CHECKING:
    from src.models.analysis import NodeAssessment
from enum import Enum
from pydantic import BaseModel


class RiskQuadrant(str, Enum):
    """Risk matrix quadrants for bid decision-making."""
    SAFE_WINS = "Safe Wins"              # High Influence, Low Risk
    MANAGED_RISKS = "Managed Risks"      # High Influence, High Risk (Firm's value-add zone)
    BASELINE_UTILITY = "Baseline/Utility"  # Low Influence, Low Risk
    COOKED_ZONE = "The Cooked Zone"      # Low Influence, High Risk (Potential Blockers)


class NodeClassification(BaseModel):
    """Classification of a single node in the risk matrix."""
    node_id: str
    node_name: str
    influence_score: float
    risk_level: float
    quadrant: RiskQuadrant


def classify_node(
    node_id: str,
    node_name: str,
    influence_score: float,
    risk_level: float,
    influence_threshold: float = 0.6,
    risk_threshold: float = 0.7
) -> NodeClassification:
    """Classify a single node into a risk quadrant using absolute thresholds.

    Args:
        node_id: Node identifier
        node_name: Node name for reporting
        influence_score: Influence score (0.0 - 1.0)
        risk_level: Risk level (0.0 - 1.0)
        influence_threshold: Threshold for high vs low influence (default 0.6)
        risk_threshold: Threshold for high vs low risk (default 0.7)

    Returns:
        NodeClassification with assigned quadrant
    """
    high_influence = influence_score > influence_threshold
    high_risk = risk_level > risk_threshold

    if high_influence and not high_risk:
        quadrant = RiskQuadrant.SAFE_WINS
    elif high_influence and high_risk:
        quadrant = RiskQuadrant.MANAGED_RISKS
    elif not high_influence and not high_risk:
        quadrant = RiskQuadrant.BASELINE_UTILITY
    else:  # Low influence, high risk
        quadrant = RiskQuadrant.COOKED_ZONE

    return NodeClassification(
        node_id=node_id,
        node_name=node_name,
        influence_score=influence_score,
        risk_level=risk_level,
        quadrant=quadrant
    )


def classify_all_nodes(
    node_assessments: Dict[str, "NodeAssessment"],  # type: ignore
    node_names: Dict[str, str],
    influence_threshold: float = 0.6,
    risk_threshold: float = 0.7
) -> Dict[RiskQuadrant, List[NodeClassification]]:
    """Classify all evaluated nodes into risk quadrants.

    Args:
        node_assessments: Dict of {node_id: NodeAssessment}
        node_names: Dict of {node_id: node_name}
        influence_threshold: Threshold for high influence (default 0.6)
        risk_threshold: Threshold for high risk (default 0.7)

    Returns:
        Dict mapping each RiskQuadrant to list of nodes in that quadrant
    """
    classifications = {quadrant: [] for quadrant in RiskQuadrant}

    for node_id, assessment in node_assessments.items():
        node_name = node_names.get(node_id, node_id)
        classification = classify_node(
            node_id=node_id,
            node_name=node_name,
            influence_score=assessment.influence_score,
            risk_level=assessment.risk_level,
            influence_threshold=influence_threshold,
            risk_threshold=risk_threshold
        )
        classifications[classification.quadrant].append(classification)

    return classifications


def should_bid(
    classifications: Dict[RiskQuadrant, List[NodeClassification]],
    critical_chain_node_ids: List[str]
) -> bool:
    """Determine if firm should bid on project based on critical chain analysis.

    Decision Rule: If the critical chain is dominated by "Cooked Zone" nodes
    (Low Influence / High Risk), the firm should NOT bid.

    Args:
        classifications: Node classifications by quadrant
        critical_chain_node_ids: List of node IDs on the critical chain

    Returns:
        True if firm should bid, False otherwise
    """
    cooked_nodes = classifications.get(RiskQuadrant.COOKED_ZONE, [])
    cooked_node_ids = {node.node_id for node in cooked_nodes}

    # Count how many critical chain nodes are in the "Cooked Zone"
    critical_cooked_count = sum(
        1 for node_id in critical_chain_node_ids
        if node_id in cooked_node_ids
    )

    # If more than 50% of critical chain is "Cooked", don't bid
    if len(critical_chain_node_ids) == 0:
        return True  # No critical chain evaluated, proceed cautiously

    cooked_percentage = critical_cooked_count / len(critical_chain_node_ids)

    return cooked_percentage <= 0.5
