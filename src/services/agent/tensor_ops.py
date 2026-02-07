import numpy as np
from typing import List, Union

def cosine_similarity(v1: np.ndarray, v2: np.ndarray) -> float:
    """Calculates cosine similarity between two vectors."""
    dot_product = np.dot(v1, v2)
    norm_v1 = np.linalg.norm(v1)
    norm_v2 = np.linalg.norm(v2)
    if norm_v1 == 0 or norm_v2 == 0:
        return 0.0
    return dot_product / (norm_v1 * norm_v2)

def calculate_influence_tensor(firm_tensor: np.ndarray, node_tensor: np.ndarray, centrality: float) -> float:
    """
    I_n = (F . R / |F||R|) * Centrality
    As described in the mathematical framework of the README.
    """
    similarity = cosine_similarity(firm_tensor, node_tensor)
    return similarity * centrality

def propagate_risk(local_failure_prob: float, multiplier: float, parent_probs: List[float]) -> float:
    """
    P(Success_n) = (1 - P(Failure_local) * mu) * Product(P(Success_i))
    """
    local_p_success = 1.0 - min(1.0, local_failure_prob * multiplier)
    parent_p_success = np.prod(parent_probs) if parent_probs else 1.0
    return local_p_success * parent_p_success
