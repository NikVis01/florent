"""Monte Carlo simulation parameters."""
from pydantic import BaseModel, Field
from typing import Dict, List, Tuple


class SamplingDistribution(BaseModel):
    """Sampling distribution for a parameter."""
    type: str = Field(description="Distribution type: beta, normal, uniform")
    params: Dict[str, float] = Field(description="Distribution parameters")
    bounds: Tuple[float, float] = Field(description="Valid range [min, max]")


class NodeSamplingDistributions(BaseModel):
    """Sampling distributions for node parameters."""
    importance: SamplingDistribution
    influence: SamplingDistribution


class SimulationConfig(BaseModel):
    """Recommended simulation configuration."""
    recommended_samples: int = Field(default=10000)
    warmup_samples: int = Field(default=1000)
    parallel_chains: int = Field(default=4)
    convergence_diagnostic: str = Field(default="rhat")
    seed: int = Field(default=42)


class ConditionalDependency(BaseModel):
    """Conditional dependency between nodes."""
    node: str
    depends_on: List[str]
    relationship: str = Field(default="conditional_probability")


class MonteCarloParameters(BaseModel):
    """Complete Monte Carlo simulation parameters."""
    sampling_distributions: Dict[str, NodeSamplingDistributions] = Field(
        description="Per-node sampling distributions"
    )
    simulation_config: SimulationConfig
    covariance_matrix: List[List[float]] = Field(
        description="NxN covariance matrix for correlated sampling"
    )
    dependencies: List[ConditionalDependency] = Field(
        default_factory=list,
        description="Conditional dependencies between nodes"
    )


class NodeCentrality(BaseModel):
    """Centrality measures for a node."""
    betweenness: float = Field(ge=0.0, description="Betweenness centrality")
    closeness: float = Field(ge=0.0, le=1.0, description="Closeness centrality")
    degree: int = Field(ge=0, description="Degree centrality")
    eigenvector: float = Field(ge=0.0, le=1.0, description="Eigenvector centrality")
    pagerank: float = Field(ge=0.0, le=1.0, description="PageRank score")


class PathAnalysis(BaseModel):
    """Path analysis statistics."""
    total_paths: int
    critical_paths_count: int
    average_path_length: float
    longest_path: int
    shortest_path: int
    bottleneck_nodes: List[str] = Field(description="Nodes with high betweenness")


class ClusteringCoefficients(BaseModel):
    """Clustering coefficient data."""
    global_coefficient: float = Field(ge=0.0, le=1.0)
    per_node: Dict[str, float] = Field(description="Local clustering per node")


class GraphStatistics(BaseModel):
    """Network analysis statistics."""
    centrality: Dict[str, NodeCentrality] = Field(
        description="Centrality measures per node"
    )
    paths: PathAnalysis
    clustering: ClusteringCoefficients
