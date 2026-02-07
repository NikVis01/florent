"""Vector operations for embeddings and similarity calculations."""
import logging
import math
from typing import List, Tuple, Dict, Any
import numpy as np

logger = logging.getLogger(__name__)


class VectorOperationsError(Exception):
    """Base exception for vector operations errors."""
    pass


def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
    """
    Calculate cosine similarity between two vectors.

    Args:
        vec1: First vector
        vec2: Second vector

    Returns:
        Cosine similarity score between -1 and 1

    Raises:
        VectorOperationsError: If vectors have different dimensions
    """
    if len(vec1) != len(vec2):
        raise VectorOperationsError(
            f"Vector dimension mismatch: {len(vec1)} != {len(vec2)}"
        )

    if len(vec1) == 0:
        raise VectorOperationsError("Cannot compute similarity of empty vectors")

    try:
        # Convert to numpy for efficient computation
        v1 = np.array(vec1)
        v2 = np.array(vec2)

        # Compute dot product and magnitudes
        dot_product = np.dot(v1, v2)
        magnitude1 = np.linalg.norm(v1)
        magnitude2 = np.linalg.norm(v2)

        # Handle zero vectors
        if magnitude1 == 0 or magnitude2 == 0:
            logger.warning("Zero magnitude vector encountered")
            return 0.0

        similarity = dot_product / (magnitude1 * magnitude2)

        logger.debug(f"Cosine similarity: {similarity:.4f}")
        return float(similarity)

    except Exception as e:
        logger.error(f"Error computing cosine similarity: {e}")
        raise VectorOperationsError(f"Failed to compute cosine similarity: {e}")


def euclidean_distance(vec1: List[float], vec2: List[float]) -> float:
    """
    Calculate Euclidean distance between two vectors.

    Args:
        vec1: First vector
        vec2: Second vector

    Returns:
        Euclidean distance (non-negative)
    """
    if len(vec1) != len(vec2):
        raise VectorOperationsError(
            f"Vector dimension mismatch: {len(vec1)} != {len(vec2)}"
        )

    try:
        v1 = np.array(vec1)
        v2 = np.array(vec2)
        distance = np.linalg.norm(v1 - v2)

        logger.debug(f"Euclidean distance: {distance:.4f}")
        return float(distance)

    except Exception as e:
        logger.error(f"Error computing euclidean distance: {e}")
        raise VectorOperationsError(f"Failed to compute euclidean distance: {e}")


def normalize_vector(vec: List[float]) -> List[float]:
    """
    Normalize a vector to unit length.

    Args:
        vec: Input vector

    Returns:
        Normalized vector
    """
    try:
        v = np.array(vec)
        magnitude = np.linalg.norm(v)

        if magnitude == 0:
            logger.warning("Cannot normalize zero vector, returning original")
            return vec

        normalized = v / magnitude
        return normalized.tolist()

    except Exception as e:
        logger.error(f"Error normalizing vector: {e}")
        raise VectorOperationsError(f"Failed to normalize vector: {e}")


def weighted_average_embedding(
    embeddings: List[List[float]],
    weights: List[float]
) -> List[float]:
    """
    Compute weighted average of multiple embeddings.

    Args:
        embeddings: List of embedding vectors
        weights: List of weights (will be normalized)

    Returns:
        Weighted average embedding
    """
    if len(embeddings) != len(weights):
        raise VectorOperationsError(
            f"Embedding count ({len(embeddings)}) doesn't match weight count ({len(weights)})"
        )

    if not embeddings:
        raise VectorOperationsError("Cannot average empty embedding list")

    try:
        # Normalize weights
        total_weight = sum(weights)
        if total_weight == 0:
            raise VectorOperationsError("Total weight is zero")

        norm_weights = [w / total_weight for w in weights]

        # Compute weighted average
        emb_array = np.array(embeddings)
        weight_array = np.array(norm_weights).reshape(-1, 1)
        weighted_avg = np.sum(emb_array * weight_array, axis=0)

        logger.debug(f"Computed weighted average of {len(embeddings)} embeddings")
        return weighted_avg.tolist()

    except Exception as e:
        logger.error(f"Error computing weighted average: {e}")
        raise VectorOperationsError(f"Failed to compute weighted average: {e}")


def batch_cosine_similarity(
    query_embedding: List[float],
    candidate_embeddings: List[List[float]]
) -> List[float]:
    """
    Compute cosine similarity between a query and multiple candidates efficiently.

    Args:
        query_embedding: Query vector
        candidate_embeddings: List of candidate vectors

    Returns:
        List of similarity scores
    """
    if not candidate_embeddings:
        return []

    try:
        query = np.array(query_embedding).reshape(1, -1)
        candidates = np.array(candidate_embeddings)

        # Normalize vectors
        query_norm = query / np.linalg.norm(query)
        candidates_norm = candidates / np.linalg.norm(candidates, axis=1, keepdims=True)

        # Compute all similarities at once
        similarities = np.dot(candidates_norm, query_norm.T).flatten()

        logger.debug(f"Computed {len(similarities)} similarities")
        return similarities.tolist()

    except Exception as e:
        logger.error(f"Error in batch cosine similarity: {e}")
        raise VectorOperationsError(f"Failed to compute batch similarities: {e}")
