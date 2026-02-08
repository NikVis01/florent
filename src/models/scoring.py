"""
Dataclasses for cross-encoder scoring outputs.

Provides structured types for firm-node similarity scoring results from BGE-M3.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import Dict, Any, Tuple

from src.models.entities import Firm
from src.models.graph import Node


@dataclass
class CrossEncoderScore:
    """
    Structured result from a single cross-encoder scoring operation.

    Attributes:
        query_text: The query text (firm capabilities)
        passage_text: The passage text (node requirements)
        similarity_score: Normalized similarity score (0-1 range)
        raw_cosine: Raw cosine similarity before normalization (-1 to 1)
        timestamp: When the score was computed
        metadata: Optional metadata for debugging/auditing
    """
    query_text: str
    passage_text: str
    similarity_score: float  # 0-1 range
    raw_cosine: float  # -1 to 1 before normalization
    timestamp: datetime = field(default_factory=datetime.now)
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        """Validate score ranges."""
        assert 0.0 <= self.similarity_score <= 1.0, f"Similarity score must be 0-1, got {self.similarity_score}"
        assert -1.0 <= self.raw_cosine <= 1.0, f"Raw cosine must be -1 to 1, got {self.raw_cosine}"


@dataclass
class FirmNodeScore:
    """
    Firm-to-node compatibility score with full context.

    Attributes:
        firm: Firm object being evaluated
        node: Node object being scored
        cross_encoder_score: Similarity score (0-1)
        firm_text: Text representation of firm used for scoring
        node_text: Text representation of node used for scoring
        timestamp: When the score was computed
        metadata: Optional metadata (e.g., model version, endpoint)
    """
    firm: Firm
    node: Node
    cross_encoder_score: float
    firm_text: str
    node_text: str
    timestamp: datetime = field(default_factory=datetime.now)
    metadata: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        """Validate score range."""
        assert 0.0 <= self.cross_encoder_score <= 1.0, \
            f"Cross-encoder score must be 0-1, got {self.cross_encoder_score}"

    def to_tuple(self) -> Tuple[Node, float]:
        """Convert to legacy (node, score) tuple format."""
        return (self.node, self.cross_encoder_score)


# Note: Batch scoring features intentionally omitted - focus on individual scoring only
