"""
Firm-contextual graph builder using cross-encoder edge weighting.
"""
import hashlib
import dspy

from src.models.entities import Firm, Project
from src.models.graph import Graph, Node, Edge
from src.models.base import OperationType
from src.services.clients.cross_encoder_client import CrossEncoderClient
from src.services.agent.models.signatures import DiscoverySignature
from src.services.logging import get_logger
from src.settings import settings

logger = get_logger(__name__)


class FirmContextualGraphBuilder:
    """
    Builds a firm-specific weighted graph using cross-encoder similarity
    and agent-driven node discovery for capability gaps.
    """

    def __init__(
        self,
        firm: Firm,
        project: Project,
        use_cross_encoder: bool = True,
        gap_threshold: float = settings.GRAPH_GAP_THRESHOLD,
        max_iterations: int = settings.GRAPH_MAX_ITERATIONS,
        max_discovered_nodes: int = settings.GRAPH_MAX_DISCOVERED_NODES,
    ):
        self.firm = firm
        self.project = project
        self.use_cross_encoder = use_cross_encoder and settings.USE_CROSS_ENCODER
        self.gap_threshold = gap_threshold
        self.max_iterations = max_iterations
        self.max_discovered_nodes = max_discovered_nodes

        self.discovered_count = 0
        self.cross_encoder = None
        self.discovery_agent = dspy.Predict(DiscoverySignature)

        if self.use_cross_encoder:
            try:
                self.cross_encoder = CrossEncoderClient(settings.CROSS_ENCODER_ENDPOINT)
                logger.info("cross_encoder_enabled", endpoint=settings.CROSS_ENCODER_ENDPOINT)
            except Exception as e:
                logger.warning("cross_encoder_disabled", error=str(e))
                self.use_cross_encoder = False

    def _build_initial_graph(self) -> Graph:
        """Build initial graph from project requirements."""
        if not self.project.ops_requirements:
            raise ValueError("Project has no ops_requirements")

        node_map = {}

        # Entry node
        if self.project.entry_criteria:
            entry_id = self.project.entry_criteria.entry_node_id
            node_map[entry_id] = Node(
                id=entry_id,
                name="Entry Point",
                type=self.project.ops_requirements[0],
                embedding=[0.1, 0.1, 0.1]
            )

        # Ops nodes
        for i, op in enumerate(self.project.ops_requirements):
            op_id = f"op_{i}"
            if op_id not in node_map:
                node_map[op_id] = Node(
                    id=op_id,
                    name=op.name,
                    type=op,
                    embedding=[0.2, 0.2, 0.2]
                )

        # Exit node
        if self.project.success_criteria:
            exit_id = self.project.success_criteria.exit_node_id
            if exit_id not in node_map:
                node_map[exit_id] = Node(
                    id=exit_id,
                    name="Exit Point",
                    type=self.project.ops_requirements[-1],
                    embedding=[0.9, 0.9, 0.9]
                )

        # Sequential edges (will be weighted by cross-encoder)
        nodes_ordered = list(node_map.values())
        edges = []

        for i in range(len(nodes_ordered) - 1):
            if nodes_ordered[i].id != nodes_ordered[i + 1].id:
                # Placeholder weight, will be scored by cross-encoder
                edges.append(Edge(
                    source=nodes_ordered[i],
                    target=nodes_ordered[i + 1],
                    weight=0.8,  # Default, will be replaced
                    relationship="sequence"
                ))

        return Graph(nodes=nodes_ordered, edges=edges)

    def _apply_cross_encoder_weights(self, graph: Graph):
        """Score all edges using cross-encoder and apply firm-specific weights."""
        if not self.cross_encoder:
            logger.warning("cross_encoder_unavailable", msg="Using default weights")
            return

        entry_node = graph.get_entry_nodes()[0]
        decay_factor = 0.9

        for edge in graph.edges:
            # Get cross-encoder similarity
            similarity = self.cross_encoder.score_firm_node(self.firm, edge.target)

            # Apply distance decay
            try:
                distance = graph.get_distance(entry_node, edge.target)
            except ValueError:
                distance = 1

            # Calculate edge weight
            edge_weight = similarity * (decay_factor ** distance)
            edge.weight = max(0.0, min(1.0, edge_weight))

            logger.debug(
                "edge_weighted",
                source=edge.source.id,
                target=edge.target.id,
                similarity=similarity,
                distance=distance,
                weight=edge.weight
            )

    def _find_gaps(self, graph: Graph) -> list[Edge]:
        """Find edges with weight below gap threshold (capability gaps)."""
        return [e for e in graph.edges if e.weight < self.gap_threshold]

    async def _discover_nodes_for_gap(
        self,
        graph: Graph,
        source: Node,
        target: Node,
        gap_size: float
    ) -> list[Node]:
        """Use agent to discover missing nodes for a capability gap."""
        if self.discovered_count >= self.max_discovered_nodes:
            logger.info("discovery_limit_reached", limit=self.max_discovered_nodes)
            return []

        # Build context
        existing_nodes = ", ".join([n.name for n in graph.nodes])
        firm_context = (
            f"Firm: {self.firm.name}. "
            f"Sectors: {', '.join(s.name for s in self.firm.sectors)}. "
            f"Services: {', '.join(s.name for s in self.firm.services)}. "
            f"Countries: {', '.join(c.a3 for c in self.firm.countries_active)}."
        )
        gap_context = (
            f"Gap detected between '{source.name}' and '{target.name}'. "
            f"Firm-node similarity: {self.gap_threshold - gap_size:.2f}. "
            f"Gap size: {gap_size:.2f}"
        )

        # Get valid categories from registry
        from src.models.base import get_categories
        valid_categories = list(get_categories())

        try:
            result = self.discovery_agent(
                node_requirements=f"{gap_context}. Target node: {target.name} ({target.type.description})",
                existing_graph_context=f"Firm capabilities: {firm_context}. Existing nodes: {existing_nodes}",
                persona="Infrastructure Risk Analyst",
                valid_types=f"Valid categories: {', '.join(valid_categories)}"
            )

            # Parse discovered nodes (expecting: Name, Category, Type, Description)
            lines = [line.strip() for line in result.hidden_dependencies.split('\n') if ',' in line]
            new_nodes = []

            for line in lines[:3]:  # Max 3 nodes per gap
                if self.discovered_count >= self.max_discovered_nodes:
                    break

                parts = [p.strip() for p in line.split(',')]
                if len(parts) >= 4:
                    name, category, type_name, desc = parts[0], parts[1], parts[2], parts[3]
                elif len(parts) >= 3:
                    # Fallback: if agent only returns 3 parts, use 'other' as category
                    name, type_name, desc = parts[0], parts[1], parts[2]
                    category = "other"
                else:
                    continue

                node_id = f"disc_{hashlib.md5(name.encode()).hexdigest()[:8]}"

                if any(n.id == node_id for n in graph.nodes):
                    continue

                # Validate category
                if category.lower() not in valid_categories:
                    logger.warning(
                        "invalid_category",
                        category=category,
                        node=name,
                        msg="Using 'other' instead"
                    )
                    category = "other"

                new_node = Node(
                    id=node_id,
                    name=name,
                    type=OperationType(
                        name=type_name,
                        category=category.lower(),
                        description=desc
                    )
                )
                new_nodes.append(new_node)
                self.discovered_count += 1

                logger.info(
                    "node_discovered",
                    node=name,
                    category=category,
                    gap_between=f"{source.name}->{target.name}",
                    total_discovered=self.discovered_count
                )

            return new_nodes

        except Exception as e:
            logger.warning("discovery_failed", gap=f"{source.id}->{target.id}", error=str(e))
            return []

    async def _inject_nodes_for_gap(
        self,
        graph: Graph,
        source: Node,
        target: Node,
        new_nodes: list[Node]
    ):
        """Inject discovered nodes between source and target."""
        if not new_nodes:
            return

        # Remove original edge
        graph.edges = [e for e in graph.edges if not (e.source.id == source.id and e.target.id == target.id)]

        # Add new nodes
        for node in new_nodes:
            graph.add_node(node)

        # Create chain: source -> new_node_1 -> new_node_2 -> ... -> target
        prev_node = source
        for i, new_node in enumerate(new_nodes):
            # Edge from previous to new
            weight = 0.6  # Default weight for discovered edges
            if self.cross_encoder:
                similarity = self.cross_encoder.score_firm_node(self.firm, new_node)
                weight = max(0.4, similarity)  # Minimum 0.4 for discovered nodes

            graph.add_edge(prev_node, new_node, weight=weight, relationship="discovered", validate=False)
            prev_node = new_node

        # Final edge to target
        final_weight = 0.7
        if self.cross_encoder:
            similarity = self.cross_encoder.score_firm_node(self.firm, target)
            final_weight = max(0.5, similarity)

        graph.add_edge(prev_node, target, weight=final_weight, relationship="bridges_gap", validate=False)

        # Validate graph after all injections
        try:
            graph.validate_graph()
        except ValueError as e:
            logger.error("graph_validation_failed", error=str(e))
            raise

    async def build(self) -> Graph:
        """
        Build firm-contextual graph with cross-encoder weighting
        and iterative gap-filling.

        Returns:
            Graph with firm-specific edge weights and discovered nodes
        """
        logger.info(
            "graph_building_started",
            firm=self.firm.name,
            project=self.project.name,
            use_cross_encoder=self.use_cross_encoder
        )

        # Phase 1: Build initial graph
        graph = self._build_initial_graph()
        logger.info("initial_graph_built", nodes=len(graph.nodes), edges=len(graph.edges))

        # Phase 2: Apply cross-encoder weights
        if self.use_cross_encoder:
            self._apply_cross_encoder_weights(graph)
            logger.info("cross_encoder_weights_applied")
        else:
            logger.info("using_default_weights", msg="Cross-encoder disabled")

        # Phase 3: Iterative gap-filling
        for iteration in range(self.max_iterations):
            gaps = self._find_gaps(graph)

            if not gaps:
                logger.info("no_gaps_found", iteration=iteration)
                break

            logger.info(
                "gaps_detected",
                iteration=iteration,
                count=len(gaps),
                threshold=self.gap_threshold
            )

            # Discover nodes for each gap
            for gap_edge in gaps[:5]:  # Limit to 5 gaps per iteration
                gap_size = self.gap_threshold - gap_edge.weight

                new_nodes = await self._discover_nodes_for_gap(
                    graph,
                    gap_edge.source,
                    gap_edge.target,
                    gap_size
                )

                if new_nodes:
                    await self._inject_nodes_for_gap(
                        graph,
                        gap_edge.source,
                        gap_edge.target,
                        new_nodes
                    )

        final_gaps = self._find_gaps(graph)
        logger.info(
            "graph_building_complete",
            nodes=len(graph.nodes),
            edges=len(graph.edges),
            discovered_nodes=self.discovered_count,
            remaining_gaps=len(final_gaps)
        )

        return graph


async def build_firm_contextual_graph(firm: Firm, project: Project) -> Graph:
    """
    Convenience function to build firm-contextual graph.

    Args:
        firm: Firm object with capabilities
        project: Project object with requirements

    Returns:
        Graph with firm-specific weighting and discovered nodes
    """
    builder = FirmContextualGraphBuilder(firm, project)
    return await builder.build()
