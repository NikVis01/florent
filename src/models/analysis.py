"""Analysis output models for Florent risk assessment."""
from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from enum import Enum

from src.models.base import Firm
from src.models.entities import Project
from src.services.agent.analysis.matrix_classifier import RiskQuadrant, NodeClassification


class TraversalStatus(str, Enum):
    """Status of graph traversal."""
    COMPLETE = "COMPLETE"
    INCOMPLETE = "INCOMPLETE"  # Budget exhausted before full traversal
    ERROR = "ERROR"


class NodeAssessment(BaseModel):
    """Assessment of a single node."""
    node_id: str
    node_name: str
    influence_score: float = Field(ge=0.0, le=1.0, description="Influence score 0-1")
    risk_level: float = Field(ge=0.0, le=1.0, description="Risk level 0-1")
    reasoning: str
    is_on_critical_path: bool = False


class CriticalChain(BaseModel):
    """A critical chain (high-risk path) through the graph."""
    node_ids: List[str]
    node_names: List[str]
    cumulative_risk: float = Field(ge=0.0, le=1.0)
    length: int


class SummaryMetrics(BaseModel):
    """Aggregate project-level metrics."""
    aggregate_project_score: float = Field(
        description="Overall project viability score (0-1, higher is better)"
    )
    total_token_cost: int = Field(
        description="Total OpenAI API tokens consumed"
    )
    critical_failure_likelihood: float = Field(
        ge=0.0, le=1.0,
        description="Probability of critical path failure"
    )
    nodes_evaluated: int
    total_nodes: int
    cooked_zone_percentage: float = Field(
        ge=0.0, le=1.0,
        description="Percentage of nodes in 'Cooked Zone' (Low I / High R)"
    )


class BidRecommendation(BaseModel):
    """Go/No-Go bid recommendation."""
    should_bid: bool
    confidence: float = Field(ge=0.0, le=1.0)
    reasoning: str
    key_risks: List[str]
    key_opportunities: List[str]


class AnalysisOutput(BaseModel):
    """Complete analysis output for infrastructure project risk assessment."""

    # Input context
    firm: Firm
    project: Project

    # Traversal status
    traversal_status: TraversalStatus
    traversal_message: Optional[str] = None

    # Node assessments
    node_assessments: Dict[str, NodeAssessment] = Field(
        description="Map of node_id to assessment"
    )

    # Critical chain analysis
    critical_chains: List[CriticalChain] = Field(
        description="Top-3 critical chains (highest risk paths)"
    )

    # 2x2 Matrix classification
    matrix_classifications: Dict[RiskQuadrant, List[NodeClassification]] = Field(
        description="Nodes grouped by risk quadrant"
    )

    # Summary metrics
    summary: SummaryMetrics

    # Bid recommendation
    recommendation: BidRecommendation

    class Config:
        """Pydantic config."""
        use_enum_values = True
