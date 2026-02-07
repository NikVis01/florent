"""Critical chain detection for infrastructure project risk analysis."""
from typing import List, Dict, Tuple, Optional
from collections import deque
from src.models.graph import Graph, Node


def find_all_paths(graph: Graph, start: Node, end: Node) -> List[List[Node]]:
    """Find all paths from start to end node using DFS."""
    all_paths = []
    stack = [(start, [start])]

    while stack:
        current, path = stack.pop()

        if current.id == end.id:
            all_paths.append(path)
            continue

        for child in graph.get_children(current):
            if child.id not in {n.id for n in path}:  # Avoid cycles
                stack.append((child, path + [child]))

    return all_paths


def calculate_path_risk(path: List[Node], risk_scores: Dict[str, float]) -> float:
    """Calculate cumulative risk probability for a path.

    Uses the formula: P(path_failure) = 1 - ∏(1 - P(node_failure))
    """
    cumulative_success_prob = 1.0

    for node in path:
        node_risk = risk_scores.get(node.id, 0.5)  # Default 0.5 if not evaluated yet
        node_success_prob = 1.0 - node_risk
        cumulative_success_prob *= node_success_prob

    path_failure_prob = 1.0 - cumulative_success_prob
    return path_failure_prob


def detect_critical_chains(
    graph: Graph,
    entry_node: Node,
    exit_node: Node,
    risk_scores: Dict[str, float],
    top_n: Optional[int] = 3
) -> List[Tuple[List[Node], float]]:
    """Detect critical chains (paths with highest cumulative risk).

    Args:
        graph: The infrastructure DAG
        entry_node: Starting node
        exit_node: Ending node
        risk_scores: Dict mapping node_id -> derived_risk (0-1)
        top_n: Number of chains to return. If None, returns all possible paths.

    Returns:
        List of (path, cumulative_risk) tuples, sorted by risk (highest first)
    """
    all_paths = find_all_paths(graph, entry_node, exit_node)

    if not all_paths:
        raise ValueError(f"No path exists from {entry_node.id} to {exit_node.id}")

    # Calculate risk for each path
    path_risks = [
        (path, calculate_path_risk(path, risk_scores))
        for path in all_paths
    ]

    # Sort by risk (descending)
    path_risks.sort(key=lambda x: x[1], reverse=True)
    
    if top_n is None:
        return path_risks
    return path_risks[:top_n]


def calculate_blast_radius(
    graph: Graph,
    node: Node,
    technical_feasibility: Dict[str, float]
) -> float:
    """Calculate blast radius: number of downstream nodes affected × their feasibility weights.

    Args:
        graph: The infrastructure DAG
        node: Node to calculate blast radius for
        technical_feasibility: Dict mapping node_id -> feasibility_score (0-1)

    Returns:
        Weighted count of affected downstream nodes
    """
    # BFS to find all downstream nodes
    visited = set()
    queue = deque([node])
    visited.add(node.id)
    downstream_nodes = []

    while queue:
        current = queue.popleft()

        for child in graph.get_children(current):
            if child.id not in visited:
                visited.add(child.id)
                downstream_nodes.append(child)
                queue.append(child)

    # Calculate weighted impact
    blast_radius = sum(
        technical_feasibility.get(n.id, 1.0)
        for n in downstream_nodes
    )

    return blast_radius


def mark_critical_path_nodes(
    graph: Graph,
    critical_chain: List[Node]
) -> Dict[str, bool]:
    """Mark which nodes are on the critical chain.

    Returns:
        Dict mapping node_id -> is_on_critical_path
    """
    critical_node_ids = {node.id for node in critical_chain}

    return {
        node.id: (node.id in critical_node_ids)
        for node in graph.nodes
    }
