"""
Risk calculation functions for topological risk propagation.

Based on the cascading failure probability model:
R_n = 1 - [(1 - P_local × μ) × ∏(1 - R_parent)]

Where:
- R_n: Risk score for node n
- P_local: Local failure probability
- μ: Risk multiplier (critical path multiplier)
- R_parent: Risk scores of parent nodes
"""

from typing import List


def calculate_topological_risk(
    local_failure_prob: float,
    multiplier: float,
    parent_risk_scores: List[float]
) -> float:
    """
    Calculate cascading risk for a node based on local probability and parent risks.

    This implements the formula:
    R_n = 1 - [(1 - P_local × μ) × ∏(1 - R_parent)]

    Which is equivalent to calculating the probability of success and converting back:
    P(Success_n) = (1 - P_local × μ) × ∏(1 - R_parent)
    R_n = 1 - P(Success_n)

    Args:
        local_failure_prob: Local failure probability in [0, 1]
        multiplier: Risk multiplier (μ), typically 1.2 for critical paths
        parent_risk_scores: List of parent node risk scores in [0, 1]

    Returns:
        Risk score in [0, 1] representing probability of failure

    Examples:
        >>> # Node with no parents
        >>> calculate_topological_risk(0.3, 1.2, [])
        0.36

        >>> # Node with one parent at 50% risk
        >>> calculate_topological_risk(0.3, 1.2, [0.5])
        0.68
    """
    # Scale local failure probability by multiplier and clip to [0, 1]
    local_failure = min(1.0, local_failure_prob * multiplier)
    local_success = 1.0 - local_failure

    # Calculate cumulative parent success probability
    # Parent success = 1 - parent_risk
    # Product of all parent successes
    parent_success_product = 1.0
    for parent_risk in parent_risk_scores:
        parent_success = 1.0 - parent_risk
        parent_success_product *= parent_success

    # Total success probability
    total_success = local_success * parent_success_product

    # Risk is complement of success
    risk = 1.0 - total_success

    # Ensure result stays in [0, 1] range
    return max(0.0, min(1.0, risk))
