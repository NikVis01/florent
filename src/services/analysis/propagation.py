"""
Risk Propagation Logic

Implements cascading risk propagation through a DAG using topological sort.
Risk flows from parent nodes to children, accumulating through the graph.
"""

from typing import Dict, List, Set
from collections import deque
import logging

from src.models.graph import Graph, Node
from src.services.math.risk import calculate_topological_risk

logger = logging.getLogger(__name__)


def _topological_sort(graph: Graph) -> List[Node]:
    """
    Perform topological sort on graph nodes using Kahn's algorithm.

    Args:
        graph: DAG to sort

    Returns:
        List of nodes in topological order (parents before children)

    Raises:
        ValueError: If graph contains a cycle or is empty
    """
    if not graph.nodes:
        raise ValueError("Cannot perform topological sort on empty graph")

    # Calculate in-degree for each node
    in_degree: Dict[str, int] = {node.id: 0 for node in graph.nodes}
    for edge in graph.edges:
        in_degree[edge.target.id] += 1

    # Initialize queue with nodes that have no incoming edges
    queue = deque([node for node in graph.nodes if in_degree[node.id] == 0])
    sorted_nodes: List[Node] = []

    while queue:
        # Process node with zero in-degree
        current = queue.popleft()
        sorted_nodes.append(current)

        # Update in-degrees of children
        children = graph.get_children(current)
        for child in children:
            in_degree[child.id] -= 1
            if in_degree[child.id] == 0:
                queue.append(child)

    # Verify all nodes were sorted
    if len(sorted_nodes) != len(graph.nodes):
        raise ValueError(
            f"Topological sort failed: only {len(sorted_nodes)}/{len(graph.nodes)} "
            f"nodes sorted. Graph may contain cycles or disconnected components."
        )

    return sorted_nodes


def propagate_risk(
    graph: Graph,
    node_assessments: Dict,
    multiplier: float = 1.2
) -> Dict:
    """
    Propagate risk scores through the graph using topological ordering.

    Processes nodes in dependency order, calculating cascading risk based on:
    R_n = 1 - [(1 - P_local × μ) × ∏(1 - R_parent)]

    Args:
        graph: Directed acyclic graph of operations
        node_assessments: Dictionary mapping node_id to assessment data.
                         Must contain 'local_risk' key with failure probability.
                         Will be updated with 'risk' key containing propagated score.
        multiplier: Critical path multiplier (μ), default 1.2

    Returns:
        Updated node_assessments dictionary with 'risk' scores added

    Raises:
        ValueError: If graph is invalid or node_assessments missing required data

    Example:
        >>> assessments = {
        ...     "A": {"local_risk": 0.2},
        ...     "B": {"local_risk": 0.3},
        ...     "C": {"local_risk": 0.1}
        ... }
        >>> result = propagate_risk(graph, assessments)
        >>> print(result["C"]["risk"])  # Will include cascading risk from A and B
    """
    if not graph.nodes:
        logger.warning("Empty graph provided to propagate_risk")
        return node_assessments

    # Validate that all nodes have assessments with local_risk
    for node in graph.nodes:
        if node.id not in node_assessments:
            raise ValueError(f"Node {node.id} missing from node_assessments")
        if "local_risk" not in node_assessments[node.id]:
            raise ValueError(f"Node {node.id} assessment missing 'local_risk' field")

    # Sort nodes in topological order
    try:
        sorted_nodes = _topological_sort(graph)
    except ValueError as e:
        logger.error(f"Failed to topologically sort graph: {e}")
        raise

    logger.info(f"Processing {len(sorted_nodes)} nodes in topological order")

    # Process nodes in order, calculating cascading risk
    for node in sorted_nodes:
        # Get local failure probability
        local_risk = node_assessments[node.id]["local_risk"]

        # Validate local_risk is in valid range
        if not (0.0 <= local_risk <= 1.0):
            raise ValueError(
                f"Node {node.id} has invalid local_risk {local_risk}. "
                f"Must be in range [0, 1]."
            )

        # Get parent nodes and their risk scores
        parents = graph.get_parents(node)
        parent_risks = []

        for parent in parents:
            # Parents should already be processed due to topological order
            if "risk" not in node_assessments[parent.id]:
                raise ValueError(
                    f"Parent node {parent.id} not yet processed. "
                    f"Topological sort may be incorrect."
                )
            parent_risks.append(node_assessments[parent.id]["risk"])

        # Calculate cascading risk using the topological risk formula
        cascading_risk = calculate_topological_risk(
            local_failure_prob=local_risk,
            multiplier=multiplier,
            parent_risk_scores=parent_risks
        )

        # Store the propagated risk score
        node_assessments[node.id]["risk"] = cascading_risk

        logger.debug(
            f"Node {node.id}: local_risk={local_risk:.3f}, "
            f"parents={len(parent_risks)}, cascading_risk={cascading_risk:.3f}"
        )

    logger.info("Risk propagation completed successfully")
    return node_assessments
