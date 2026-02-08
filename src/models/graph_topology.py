"""Graph topology models for enhanced output."""
from pydantic import BaseModel, Field
from typing import List


class EdgeTopology(BaseModel):
    """Enhanced edge with topology metadata."""
    source: str
    target: str
    weight: float = Field(ge=0.0, le=1.0, description="Cross-encoder similarity score")
    relationship: str
    distance_from_entry: int = Field(description="Topological distance from entry node")
    is_critical_path: bool = Field(default=False, description="Is this edge on critical path")
    was_discovered: bool = Field(default=False, description="Was this edge discovered by AI")


class NodeTopology(BaseModel):
    """Enhanced node with topology metadata."""
    id: str
    name: str
    type: str
    index: int = Field(description="Position in adjacency matrix (0-indexed)")
    depth: int = Field(description="Layers from entry node")
    parents: List[str] = Field(default_factory=list)
    children: List[str] = Field(default_factory=list)
    degree_in: int = Field(ge=0, description="Number of incoming edges")
    degree_out: int = Field(ge=0, description="Number of outgoing edges")
    was_discovered: bool = Field(default=False, description="Was this node discovered by AI")


class TopologyStatistics(BaseModel):
    """Graph topology statistics."""
    total_nodes: int
    total_edges: int
    max_depth: int
    average_degree: float
    density: float = Field(description="Edge density = edges / (nodes * (nodes-1))")
    longest_path_length: int


class GraphTopology(BaseModel):
    """Complete graph topology representation."""
    adjacency_matrix: List[List[float]] = Field(
        description="NxN adjacency matrix with edge weights"
    )
    node_index: List[str] = Field(
        description="Node ID to matrix index mapping"
    )
    edges: List[EdgeTopology]
    nodes: List[NodeTopology]
    statistics: TopologyStatistics
