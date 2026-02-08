"""Analysis output models for Florent risk assessment."""
from pydantic import BaseModel, Field
from typing import Dict, List, Optional
from enum import Enum

from src.models.entities import Firm, Project
from src.services.agent.analysis.matrix_classifier import RiskQuadrant, NodeClassification
from src.models.graph_topology import GraphTopology
from src.models.risk_distributions import RiskDistributions
from src.models.propagation_trace import PropagationTrace
from src.models.discovery_metadata import DiscoveryMetadata
from src.models.evaluation_metadata import EvaluationMetadata
from src.models.config_snapshot import ConfigurationSnapshot
from src.models.monte_carlo import MonteCarloParameters, GraphStatistics


class TraversalStatus(str, Enum):
    """Status of graph traversal."""
    COMPLETE = "COMPLETE"
    INCOMPLETE = "INCOMPLETE"  # Budget exhausted before full traversal
    ERROR = "ERROR"


class NodeAssessment(BaseModel):
    """Assessment of a single node based on Influence vs Importance."""
    node_id: str
    node_name: str
    importance_score: float = Field(ge=0.0, le=1.0, description="Criticality of node to project success")
    influence_score: float = Field(ge=0.0, le=1.0, description="Firm control/influence over node")
    risk_level: float = Field(ge=0.0, le=1.0, description="Derived risk: Importance * (1.0 - Influence)")
    reasoning: str
    is_on_critical_path: bool = False


class CriticalChain(BaseModel):
    """A prioritized sequence of dependencies with its cumulative derived risk."""
    node_ids: List[str]
    node_names: List[str]
    cumulative_risk: float = Field(ge=0.0, le=1.0, description="Path failure probability")
    length: int


class SummaryMetrics(BaseModel):
    """Aggregate project-level metrics."""
    aggregate_project_score: float = Field(
        description="Overall project viability score (inverse of average risk)"
    )
    total_token_cost: int = Field(
        description="Total OpenAI API tokens consumed"
    )
    critical_failure_likelihood: float = Field(
        ge=0.0, le=1.0,
        description="Derived probability of critical path failure"
    )
    nodes_evaluated: int
    total_nodes: int
    critical_dependency_count: int = Field(
        description="Count of nodes in High Importance / Low Influence quadrant"
    )


class BidRecommendation(BaseModel):
    """Go/No-Go bid recommendation based on structural risk."""
    should_bid: bool
    confidence: float = Field(ge=0.0, le=1.0)
    reasoning: str
    key_risks: List[str]
    key_opportunities: List[str]


class AnalysisOutput(BaseModel):
    """Complete analysis output for infrastructure project risk assessment."""

    # ========== EXISTING CORE OUTPUT (unchanged) ==========
    # Input context
    firm: Firm
    project: Project

    # Traversal status
    traversal_status: TraversalStatus
    traversal_message: Optional[str] = None

    # Node assessments (Full Detail)
    node_assessments: Dict[str, NodeAssessment] = Field(
        description="Full detailed assessment for every node in the graph"
    )

    # All dependency chains (Ranked)
    all_chains: List[CriticalChain] = Field(
        description="Every possible path through the graph, ranked by risk"
    )

    # Influence vs Importance Matrix
    matrix_classifications: Dict[RiskQuadrant, List[NodeClassification]] = Field(
        description="Nodes mapped to Influence vs Importance quadrants"
    )

    # Summary metrics
    summary: SummaryMetrics

    # Bid recommendation
    recommendation: BidRecommendation

    # ========== ENHANCED OUTPUT FOR MATLAB/MONTE CARLO ==========
    # Graph topology - reconstruct graph structure
    graph_topology: Optional[GraphTopology] = Field(
        default=None,
        description="Complete graph structure with adjacency matrix and topology metrics"
    )

    # Risk distributions - Monte Carlo sampling parameters
    risk_distributions: Optional[RiskDistributions] = Field(
        default=None,
        description="Statistical distributions for Monte Carlo simulation"
    )

    # Propagation trace - how risk flowed through graph
    propagation_trace: Optional[PropagationTrace] = Field(
        default=None,
        description="Detailed risk propagation trace per node"
    )

    # Discovery metadata - AI-generated nodes
    discovery_metadata: Optional[DiscoveryMetadata] = Field(
        default=None,
        description="Metadata about AI-discovered nodes and gaps"
    )

    # Evaluation metadata - performance and cost tracking
    evaluation_metadata: Optional[EvaluationMetadata] = Field(
        default=None,
        description="Performance metrics and token costs per node"
    )

    # Configuration snapshot - reproducibility
    configuration_snapshot: Optional[ConfigurationSnapshot] = Field(
        default=None,
        description="Complete configuration used for this analysis"
    )

    # Graph statistics - network analysis
    graph_statistics: Optional[GraphStatistics] = Field(
        default=None,
        description="Network centrality and path analysis metrics"
    )

    # Monte Carlo parameters - simulation-ready data
    monte_carlo_parameters: Optional[MonteCarloParameters] = Field(
        default=None,
        description="Pre-computed parameters for Monte Carlo simulation"
    )

    class Config:
        """Pydantic config."""
        use_enum_values = True
