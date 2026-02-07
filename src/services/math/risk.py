import math
from typing import List, Dict

def sigmoid(x: float) -> float:
    """Standard sigmoid function for mapping raw scores to (0, 1)."""
    return 1 / (1 + math.exp(-x))

def calculate_influence_score(ce_score: float, distance: int, attenuation_factor: float) -> float:
    """
    Calculates the influence score using Cross-Encoder interaction and graph distance.
    I_n = sigma(CE) * delta^(-d)
    """
    # Assuming ce_score might be a raw logit or a probability. 
    # Applying sigmoid to be safe if it's not already bounded.
    influence_base = sigmoid(ce_score)
    damping = math.pow(attenuation_factor, -distance)
    return influence_base * damping

def calculate_topological_risk(local_failure_prob: float, multiplier: float, parent_success_probs: List[float]) -> float:
    """
    Calculates the cascading probability of success for a node.
    P(S_n) = (1 - P(f_local) * mu) * Product(P(S_i) for i in parents)
    """
    # Local probability of success
    # Note: mu is the risk multiplier. Failure prob is scaled by mu.
    # We must ensure result is clipped within [0, 1].
    local_p_failure = min(1.0, local_failure_prob * multiplier)
    local_p_success = 1.0 - local_p_failure
    
    # Cumulative parent success
    parent_success_total = 1.0
    for p_success in parent_success_probs:
        parent_success_total *= p_success
        
    return local_p_success * parent_success_total

def calculate_weighted_alignment(agent_scores: Dict[str, float], weights: Dict[str, float]) -> float:
    """
    Calculates the final weighted alignment score based on static metrics.
    Score = Sum(AgentAttribute_i * Weight_i)
    """
    total_score = 0.0
    for attr, score in agent_scores.items():
        weight = weights.get(attr, 0.0)
        total_score += score * weight
    return total_score