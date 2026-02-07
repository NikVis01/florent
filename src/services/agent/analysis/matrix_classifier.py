"""2x2 Matrix Classification for Infrastructure Risk Analysis."""
from typing import Dict, List, TYPE_CHECKING
if TYPE_CHECKING:
    from src.models.analysis import NodeAssessment
from enum import Enum
from pydantic import BaseModel


class RiskQuadrant(str, Enum):
    """Quadrants derived from Influence (X) and Importance (Y)."""
    STRATEGIC_WIN = "High Influence / Low Importance"
    MANAGED_RISK = "High Influence / High Importance"
    BASELINE_SUPPORT = "Low Influence / Low Importance"
    CRITICAL_DEPENDENCY = "Low Influence / High Importance"


class NodeClassification(BaseModel):
    """Classification of a single node in the Influence vs Importance matrix."""
    node_id: str
    node_name: str
    influence_score: float
    importance_score: float
    quadrant: RiskQuadrant


def classify_node(
    node_id: str,
    node_name: str,
    influence_score: float,
    importance_score: float,
    influence_threshold: float = 0.6,
    importance_threshold: float = 0.6
) -> NodeClassification:
    """Classify a single node into a quadrant using absolute thresholds.

    Args:
        node_id: Node identifier
        node_name: Node name
        influence_score: Influence score (0.0 - 1.0)
        importance_score: Importance score (0.0 - 1.0)
        influence_threshold: Threshold for high vs low influence
        importance_threshold: Threshold for high vs low importance

    Returns:
        NodeClassification with assigned quadrant
    """
    high_influence = influence_score > influence_threshold
    high_importance = importance_score > importance_threshold

    if high_influence and not high_importance:
        quadrant = RiskQuadrant.STRATEGIC_WIN
    elif high_influence and high_importance:
        quadrant = RiskQuadrant.MANAGED_RISK
    elif not high_influence and not high_importance:
        quadrant = RiskQuadrant.BASELINE_SUPPORT
    else:  # Low influence, high importance
        quadrant = RiskQuadrant.CRITICAL_DEPENDENCY

    return NodeClassification(
        node_id=node_id,
        node_name=node_name,
        influence_score=influence_score,
        importance_score=importance_score,
        quadrant=quadrant
    )


def classify_all_nodes(
    node_assessments: Dict[str, "NodeAssessment"],  # type: ignore
    node_names: Dict[str, str],
    influence_threshold: float = 0.6,
    importance_threshold: float = 0.6
) -> Dict[RiskQuadrant, List[NodeClassification]]:
    """Classify all nodes into Influence vs Importance quadrants.

    Args:
        node_assessments: Dict of {node_id: NodeAssessment}
        node_names: Dict of {node_id: node_name}
        influence_threshold: Threshold for high influence
        importance_threshold: Threshold for high importance

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
            importance_score=assessment.importance_score,
            influence_threshold=influence_threshold,
            importance_threshold=importance_threshold
        )
        classifications[classification.quadrant].append(classification)

    return classifications


def should_bid(
    classifications: Dict[RiskQuadrant, List[NodeClassification]],
    critical_chain_node_ids: List[str]
) -> bool:
    """Determine if firm should bid based on critical dependency analysis.

    Decision Rule: If the critical chain is dominated by "Critical Dependency" nodes
    (Low Influence / High Importance), the firm should NOT bid.
    """
    critical_deps = classifications.get(RiskQuadrant.CRITICAL_DEPENDENCY, [])
    critical_dep_ids = {node.node_id for node in critical_deps}

    if len(critical_chain_node_ids) == 0:
        return True

    critical_dep_on_path_count = sum(
        1 for node_id in critical_chain_node_ids
        if node_id in critical_dep_ids
    )

    # If more than 50% of critical chain consists of unmanaged critical dependencies, don't bid
    critical_dep_percentage = critical_dep_on_path_count / len(critical_chain_node_ids)

    return critical_dep_percentage <= 0.5
