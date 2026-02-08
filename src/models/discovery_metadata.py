"""Discovery metadata models for AI-generated nodes."""
from pydantic import BaseModel, Field
from typing import List, Dict


class GapTrigger(BaseModel):
    """Gap that triggered node discovery."""
    source: str
    target: str
    gap_weight: float = Field(ge=0.0, le=1.0, description="Edge weight that triggered discovery")
    gap_threshold: float = Field(description="Threshold for gap detection")


class DiscoveredNode(BaseModel):
    """Metadata for an AI-discovered node."""
    node_id: str
    name: str
    discovered_at_iteration: int
    triggered_by_gap: GapTrigger
    persona_used: str = Field(description="AI persona that discovered this node")
    confidence: float = Field(ge=0.0, le=1.0, description="Discovery confidence score")
    discovery_reasoning: str = Field(description="Why this node was discovered")
    insertion_point: str = Field(description="Where in graph this node was inserted")


class DiscoverySummary(BaseModel):
    """Summary of discovery process."""
    total_discovered: int
    iterations_run: int
    gaps_filled: int
    personas_used: Dict[str, int] = Field(
        description="Count of nodes discovered by each persona"
    )


class DiscoveryMetadata(BaseModel):
    """Complete discovery metadata."""
    discovered_nodes: List[DiscoveredNode] = Field(default_factory=list)
    summary: DiscoverySummary
