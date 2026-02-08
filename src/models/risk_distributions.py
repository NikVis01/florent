"""Risk distribution models for Monte Carlo simulation."""
from pydantic import BaseModel, Field
from typing import List, Tuple, Dict, Optional


class DistributionParameters(BaseModel):
    """Statistical distribution parameters."""
    mean: float
    std_dev: float = Field(description="Standard deviation / uncertainty")
    distribution: str = Field(description="Distribution type: beta, normal, uniform")
    alpha: Optional[float] = Field(default=None, description="Beta distribution alpha parameter")
    beta: Optional[float] = Field(default=None, description="Beta distribution beta parameter")
    confidence_interval_95: Tuple[float, float] = Field(
        description="95% confidence interval [lower, upper]"
    )


class RiskComponents(BaseModel):
    """Risk breakdown for a single node."""
    point_estimate: float = Field(ge=0.0, le=1.0, description="importance × (1 - influence)")
    propagated: float = Field(ge=0.0, le=1.0, description="After risk propagation")
    local: float = Field(ge=0.0, le=1.0, description="Before propagation")
    distribution: str = Field(default="derived", description="Calculated from importance/influence")
    samples_available: bool = Field(default=False, description="Are Monte Carlo samples available")


class NodeRiskDistribution(BaseModel):
    """Risk distribution for a single node."""
    importance: DistributionParameters
    influence: DistributionParameters
    risk: RiskComponents


class CorrelationPair(BaseModel):
    """Correlation between two nodes."""
    node_a: str
    node_b: str
    correlation: float = Field(ge=-1.0, le=1.0, description="Pearson correlation coefficient")


class RiskDistributions(BaseModel):
    """Complete risk distribution data for all nodes."""
    nodes: Dict[str, NodeRiskDistribution] = Field(
        description="Per-node risk distributions"
    )
    correlation_pairs: List[CorrelationPair] = Field(
        default_factory=list,
        description="Pairwise correlations between node risks"
    )
    correlation_method: str = Field(default="pearson")
