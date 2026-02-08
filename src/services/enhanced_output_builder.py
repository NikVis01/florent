"""Builder for enhanced analysis output with all metadata."""
import numpy as np
from typing import Dict, List, Set, Tuple, Optional
from datetime import datetime
from collections import defaultdict, deque

from src.models.graph import Graph, Node, Edge
from src.models.analysis import NodeAssessment
from src.models.graph_topology import (
    GraphTopology, EdgeTopology, NodeTopology, TopologyStatistics
)
from src.models.risk_distributions import (
    RiskDistributions, NodeRiskDistribution, DistributionParameters,
    RiskComponents, CorrelationPair
)
from src.models.propagation_trace import (
    PropagationTrace, NodePropagation, IncomingRisk, OutgoingRisk, PropagationConfig
)
from src.models.config_snapshot import ConfigurationSnapshot, ModelVersions
from src.models.monte_carlo import (
    MonteCarloParameters, NodeSamplingDistributions, SamplingDistribution,
    SimulationConfig, ConditionalDependency, GraphStatistics,
    NodeCentrality, PathAnalysis, ClusteringCoefficients
)
from src.settings import settings


class EnhancedOutputBuilder:
    """Builds enhanced output sections for MATLAB integration."""

    def __init__(self, graph: Graph):
        self.graph = graph
        self.node_index_map = {node.id: idx for idx, node in enumerate(graph.nodes)}

    def build_graph_topology(
        self,
        critical_path_nodes: Set[str],
        discovered_nodes: Set[str]
    ) -> GraphTopology:
        """Build complete graph topology representation."""
        # Build adjacency matrix
        n = len(self.graph.nodes)
        adj_matrix = [[0.0] * n for _ in range(n)]

        # Fill adjacency matrix with edge weights
        for edge in self.graph.edges:
            i = self.node_index_map[edge.source.id]
            j = self.node_index_map[edge.target.id]
            adj_matrix[i][j] = edge.weight

        # Calculate distances from entry
        entry_nodes = self.graph.get_entry_nodes()
        distances = self._calculate_distances_from_entry(entry_nodes)

        # Build edge topology list
        edges = []
        for edge in self.graph.edges:
            edges.append(EdgeTopology(
                source=edge.source.id,
                target=edge.target.id,
                weight=edge.weight,
                relationship=edge.relationship,
                distance_from_entry=distances.get(edge.target.id, 0),
                is_critical_path=(
                    edge.source.id in critical_path_nodes and
                    edge.target.id in critical_path_nodes
                ),
                was_discovered=edge.source.id in discovered_nodes or edge.target.id in discovered_nodes
            ))

        # Build node topology list
        nodes = []
        for node in self.graph.nodes:
            parents = self.graph.get_parents(node)
            children = self.graph.get_children(node)

            nodes.append(NodeTopology(
                id=node.id,
                name=node.name,
                type=str(node.type),
                index=self.node_index_map[node.id],
                depth=distances.get(node.id, 0),
                parents=[p.id for p in parents],
                children=[c.id for c in children],
                degree_in=len(parents),
                degree_out=len(children),
                was_discovered=node.id in discovered_nodes
            ))

        # Calculate statistics
        total_edges = len(self.graph.edges)
        max_depth = max(distances.values()) if distances else 0
        avg_degree = (2 * total_edges) / n if n > 0 else 0
        density = total_edges / (n * (n - 1)) if n > 1 else 0
        longest_path = self._find_longest_path()

        statistics = TopologyStatistics(
            total_nodes=n,
            total_edges=total_edges,
            max_depth=max_depth,
            average_degree=avg_degree,
            density=density,
            longest_path_length=longest_path
        )

        return GraphTopology(
            adjacency_matrix=adj_matrix,
            node_index=[node.id for node in self.graph.nodes],
            edges=edges,
            nodes=nodes,
            statistics=statistics
        )

    def build_risk_distributions(
        self,
        node_assessments: Dict[str, NodeAssessment],
        propagated_risks: Optional[Dict[str, float]] = None
    ) -> RiskDistributions:
        """Build risk distribution data for Monte Carlo."""
        node_distributions = {}

        for node_id, assessment in node_assessments.items():
            # Estimate uncertainty (std dev) based on confidence
            # Using 15% uncertainty as reasonable default
            importance_std = 0.15
            influence_std = 0.15

            # Calculate Beta distribution parameters
            # Using method of moments for Beta(alpha, beta)
            importance_mean = assessment.importance_score
            importance_alpha, importance_beta = self._moments_to_beta(
                importance_mean, importance_std
            )

            influence_mean = assessment.influence_score
            influence_alpha, influence_beta = self._moments_to_beta(
                influence_mean, influence_std
            )

            node_distributions[node_id] = NodeRiskDistribution(
                importance=DistributionParameters(
                    mean=importance_mean,
                    std_dev=importance_std,
                    distribution="beta",
                    alpha=importance_alpha,
                    beta=importance_beta,
                    confidence_interval_95=(
                        max(0.0, importance_mean - 1.96 * importance_std),
                        min(1.0, importance_mean + 1.96 * importance_std)
                    )
                ),
                influence=DistributionParameters(
                    mean=influence_mean,
                    std_dev=influence_std,
                    distribution="beta",
                    alpha=influence_alpha,
                    beta=influence_beta,
                    confidence_interval_95=(
                        max(0.0, influence_mean - 1.96 * influence_std),
                        min(1.0, influence_mean + 1.96 * influence_std)
                    )
                ),
                risk=RiskComponents(
                    point_estimate=assessment.risk_level,
                    propagated=propagated_risks.get(node_id, assessment.risk_level) if propagated_risks else assessment.risk_level,
                    local=assessment.risk_level,
                    distribution="derived",
                    samples_available=False
                )
            )

        # Calculate correlations between adjacent nodes
        correlations = self._calculate_risk_correlations()

        return RiskDistributions(
            nodes=node_distributions,
            correlation_pairs=correlations,
            correlation_method="pearson"
        )

    def build_propagation_trace(
        self,
        node_assessments: Dict[str, NodeAssessment],
        propagated_risks: Dict[str, float]
    ) -> PropagationTrace:
        """Build detailed propagation trace."""
        pipeline_config = settings.pipeline

        node_traces = {}

        # Topological sort to process in order
        sorted_nodes = self._topological_sort()

        for node in sorted_nodes:
            parents = self.graph.get_parents(node)
            children = self.graph.get_children(node)

            # Get local risk
            assessment = node_assessments.get(node.id)
            local_risk = assessment.risk_level if assessment else 0.5

            # Calculate incoming risk from parents
            incoming = []
            for parent in parents:
                parent_risk = propagated_risks.get(parent.id, 0.0)
                edge = self._get_edge(parent.id, node.id)

                incoming.append(IncomingRisk(
                    from_node=parent.id,
                    contributed=parent_risk * edge.weight if edge else 0.0,
                    edge_weight=edge.weight if edge else 0.0,
                    attenuation=pipeline_config.edge_weight_decay
                ))

            # Calculate outgoing risk to children
            outgoing = []
            propagated_risk = propagated_risks.get(node.id, local_risk)
            for child in children:
                outgoing.append(OutgoingRisk(
                    to_node=child.id,
                    transmitted=propagated_risk,
                    multiplier=1.2  # Default multiplier
                ))

            node_traces[node.id] = NodePropagation(
                local_risk=local_risk,
                incoming_risk=incoming,
                propagated_risk=propagated_risk,
                outgoing_risk=outgoing,
                propagation_multiplier=1.2,
                formula="risk = local + (max_parent * local * propagation_factor)"
            )

        config = PropagationConfig(
            propagation_factor=pipeline_config.risk_propagation_factor,
            multiplier=1.2,
            attenuation_factor=pipeline_config.edge_weight_decay,
            method="topological_sort"
        )

        return PropagationTrace(nodes=node_traces, config=config)

    def build_configuration_snapshot(self) -> ConfigurationSnapshot:
        """Build complete configuration snapshot."""
        # Export all configs
        config_dict = settings.export_config_dict()

        return ConfigurationSnapshot(
            timestamp=datetime.now(),
            version="1.2.0",  # Update this with actual version
            parameters=config_dict,
            models=ModelVersions(
                llm=settings.LLM_MODEL,
                cross_encoder=settings.BGE_M3_MODEL,
                dspy_version="3.1.3"  # Get from package
            )
        )

    def build_monte_carlo_parameters(
        self,
        risk_distributions: RiskDistributions
    ) -> MonteCarloParameters:
        """Build Monte Carlo simulation parameters."""
        sampling_dists = {}

        for node_id, dist in risk_distributions.nodes.items():
            sampling_dists[node_id] = NodeSamplingDistributions(
                importance=SamplingDistribution(
                    type=dist.importance.distribution,
                    params={
                        "alpha": dist.importance.alpha,
                        "beta": dist.importance.beta
                    },
                    bounds=(0.0, 1.0)
                ),
                influence=SamplingDistribution(
                    type=dist.influence.distribution,
                    params={
                        "alpha": dist.influence.alpha,
                        "beta": dist.influence.beta
                    },
                    bounds=(0.0, 1.0)
                )
            )

        # Build covariance matrix
        n = len(self.graph.nodes)
        cov_matrix = [[0.0] * n for _ in range(n)]
        for i in range(n):
            cov_matrix[i][i] = 1.0  # Variance = 1 (normalized)

        # Add correlations
        for corr_pair in risk_distributions.correlation_pairs:
            i = self.node_index_map.get(corr_pair.node_a)
            j = self.node_index_map.get(corr_pair.node_b)
            if i is not None and j is not None:
                cov_matrix[i][j] = corr_pair.correlation
                cov_matrix[j][i] = corr_pair.correlation

        # Build dependencies
        dependencies = []
        for node in self.graph.nodes:
            parents = self.graph.get_parents(node)
            if parents:
                dependencies.append(ConditionalDependency(
                    node=node.id,
                    depends_on=[p.id for p in parents],
                    relationship="conditional_probability"
                ))

        return MonteCarloParameters(
            sampling_distributions=sampling_dists,
            simulation_config=SimulationConfig(),
            covariance_matrix=cov_matrix,
            dependencies=dependencies
        )

    def build_graph_statistics(
        self,
        critical_path_nodes: Set[str]
    ) -> GraphStatistics:
        """Build network analysis statistics."""
        # Calculate centrality measures
        centrality_data = {}
        betweenness = self._calculate_betweenness_centrality()
        closeness = self._calculate_closeness_centrality()

        for node in self.graph.nodes:
            centrality_data[node.id] = NodeCentrality(
                betweenness=betweenness.get(node.id, 0.0),
                closeness=closeness.get(node.id, 0.0),
                degree=len(self.graph.get_parents(node)) + len(self.graph.get_children(node)),
                eigenvector=0.5,  # Placeholder - would need iterative calculation
                pagerank=0.5  # Placeholder - would need iterative calculation
            )

        # Find bottleneck nodes (high betweenness)
        bottlenecks = sorted(betweenness.items(), key=lambda x: x[1], reverse=True)[:5]
        bottleneck_ids = [node_id for node_id, _ in bottlenecks]

        # Path analysis
        all_paths = self._find_all_paths()
        paths = PathAnalysis(
            total_paths=len(all_paths),
            critical_paths_count=len([p for p in all_paths if set(p).issubset(critical_path_nodes)]),
            average_path_length=np.mean([len(p) for p in all_paths]) if all_paths else 0,
            longest_path=max([len(p) for p in all_paths]) if all_paths else 0,
            shortest_path=min([len(p) for p in all_paths]) if all_paths else 0,
            bottleneck_nodes=bottleneck_ids
        )

        # Clustering coefficients
        clustering_coeffs = self._calculate_clustering_coefficients()
        clustering = ClusteringCoefficients(
            global_coefficient=np.mean(list(clustering_coeffs.values())) if clustering_coeffs else 0.0,
            per_node=clustering_coeffs
        )

        return GraphStatistics(
            centrality=centrality_data,
            paths=paths,
            clustering=clustering
        )

    # ========== Helper Methods ==========

    def _calculate_distances_from_entry(self, entry_nodes: List[Node]) -> Dict[str, int]:
        """Calculate shortest distance from entry nodes using BFS."""
        distances = {}
        queue = deque([(node, 0) for node in entry_nodes])
        visited = set()

        while queue:
            node, dist = queue.popleft()
            if node.id in visited:
                continue

            visited.add(node.id)
            distances[node.id] = dist

            for child in self.graph.get_children(node):
                if child.id not in visited:
                    queue.append((child, dist + 1))

        return distances

    def _find_longest_path(self) -> int:
        """Find length of longest path in DAG."""
        memo = {}

        def dfs(node: Node) -> int:
            if node.id in memo:
                return memo[node.id]

            children = self.graph.get_children(node)
            if not children:
                memo[node.id] = 1
                return 1

            max_length = 1 + max(dfs(child) for child in children)
            memo[node.id] = max_length
            return max_length

        entry_nodes = self.graph.get_entry_nodes()
        if not entry_nodes:
            return 0

        return max(dfs(node) for node in entry_nodes)

    def _moments_to_beta(self, mean: float, std: float) -> Tuple[float, float]:
        """Convert mean and std dev to Beta distribution parameters."""
        # Ensure valid range
        mean = max(0.01, min(0.99, mean))
        std = min(std, 0.25)  # Cap std dev

        # Calculate alpha and beta using method of moments
        variance = std ** 2
        alpha = mean * ((mean * (1 - mean) / variance) - 1)
        beta = (1 - mean) * ((mean * (1 - mean) / variance) - 1)

        # Ensure positive parameters
        alpha = max(0.5, alpha)
        beta = max(0.5, beta)

        return alpha, beta

    def _calculate_risk_correlations(self) -> List[CorrelationPair]:
        """Calculate pairwise risk correlations for adjacent nodes."""
        correlations = []

        for edge in self.graph.edges:
            # Adjacent nodes have positive correlation based on edge weight
            correlation = 0.3 + (0.4 * edge.weight)  # Range [0.3, 0.7]

            correlations.append(CorrelationPair(
                node_a=edge.source.id,
                node_b=edge.target.id,
                correlation=correlation
            ))

        return correlations

    def _topological_sort(self) -> List[Node]:
        """Perform topological sort on graph."""
        in_degree = {node.id: 0 for node in self.graph.nodes}
        for edge in self.graph.edges:
            in_degree[edge.target.id] += 1

        queue = deque([node for node in self.graph.nodes if in_degree[node.id] == 0])
        sorted_nodes = []

        while queue:
            node = queue.popleft()
            sorted_nodes.append(node)

            for child in self.graph.get_children(node):
                in_degree[child.id] -= 1
                if in_degree[child.id] == 0:
                    queue.append(child)

        return sorted_nodes

    def _get_edge(self, source_id: str, target_id: str) -> Optional[Edge]:
        """Get edge between two nodes."""
        for edge in self.graph.edges:
            if edge.source.id == source_id and edge.target.id == target_id:
                return edge
        return None

    def _calculate_betweenness_centrality(self) -> Dict[str, float]:
        """Calculate betweenness centrality for all nodes."""
        # Simplified implementation - for full accuracy use NetworkX
        betweenness = defaultdict(float)
        all_paths = self._find_all_paths()

        for path in all_paths:
            for node_id in path[1:-1]:  # Exclude endpoints
                betweenness[node_id] += 1.0

        # Normalize
        n = len(all_paths)
        if n > 0:
            betweenness = {k: v / n for k, v in betweenness.items()}

        return dict(betweenness)

    def _calculate_closeness_centrality(self) -> Dict[str, float]:
        """Calculate closeness centrality for all nodes."""
        closeness = {}

        for node in self.graph.nodes:
            distances = self._calculate_distances_from_node(node)
            if distances:
                avg_dist = np.mean(list(distances.values()))
                closeness[node.id] = 1.0 / (1.0 + avg_dist) if avg_dist > 0 else 0.0
            else:
                closeness[node.id] = 0.0

        return closeness

    def _calculate_distances_from_node(self, start_node: Node) -> Dict[str, int]:
        """Calculate distances from a specific node using BFS."""
        distances = {}
        queue = deque([(start_node, 0)])
        visited = set()

        while queue:
            node, dist = queue.popleft()
            if node.id in visited:
                continue

            visited.add(node.id)
            distances[node.id] = dist

            # Consider both children and parents (undirected distance)
            neighbors = self.graph.get_children(node) + self.graph.get_parents(node)
            for neighbor in neighbors:
                if neighbor.id not in visited:
                    queue.append((neighbor, dist + 1))

        return distances

    def _find_all_paths(self) -> List[List[str]]:
        """Find all paths from entry to exit nodes."""
        entry_nodes = self.graph.get_entry_nodes()
        exit_nodes = self.graph.get_exit_nodes()

        all_paths = []

        def dfs(node: Node, path: List[str], visited: Set[str]):
            path.append(node.id)
            visited.add(node.id)

            if node in exit_nodes:
                all_paths.append(path.copy())
            else:
                for child in self.graph.get_children(node):
                    if child.id not in visited:
                        dfs(child, path, visited)

            path.pop()
            visited.remove(node.id)

        for entry in entry_nodes:
            dfs(entry, [], set())

        return all_paths

    def _calculate_clustering_coefficients(self) -> Dict[str, float]:
        """Calculate local clustering coefficient for each node."""
        clustering = {}

        for node in self.graph.nodes:
            neighbors = set()
            for child in self.graph.get_children(node):
                neighbors.add(child.id)
            for parent in self.graph.get_parents(node):
                neighbors.add(parent.id)

            if len(neighbors) < 2:
                clustering[node.id] = 0.0
                continue

            # Count edges between neighbors
            edges_between = 0
            neighbor_list = list(neighbors)
            for i, n1 in enumerate(neighbor_list):
                for n2 in neighbor_list[i+1:]:
                    if self._get_edge(n1, n2) or self._get_edge(n2, n1):
                        edges_between += 1

            # Clustering coefficient = actual edges / possible edges
            possible_edges = len(neighbors) * (len(neighbors) - 1) / 2
            clustering[node.id] = edges_between / possible_edges if possible_edges > 0 else 0.0

        return clustering
