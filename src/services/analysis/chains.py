"""
Critical Chain Detection

Finds high-risk execution paths through the graph using DFS traversal.
Calculates cumulative risk for each path from entry to exit nodes.
"""

from typing import Dict, List
from src.models.graph import Graph, Node


def find_critical_chains(
    graph: Graph,
    node_assessments: Dict,
    threshold: float = 0.8,
    top_n: int = 5
) -> List[dict]:
    """
    Find critical paths through the graph with cumulative risk above threshold.

    Uses DFS traversal with NodeStack to explore all paths from entry nodes
    to exit nodes. Calculates cumulative risk using the formula:
    R_cumulative = 1 - ∏(1 - R_i) for each node i in the path.

    Args:
        graph: The DAG to analyze
        node_assessments: Dict mapping node_id to assessment data with 'risk' key
                         Example: {"node1": {"risk": 0.9, ...}, ...}
        threshold: Minimum cumulative risk to be considered critical (default: 0.8)
        top_n: Maximum number of chains to return (default: 5)

    Returns:
        List of critical chain dictionaries, sorted by risk (descending).
        Each dict contains:
            - nodes: List[str] of node IDs in path order
            - risk: float cumulative risk score (0.0 to 1.0)
            - description: str explaining why the chain is critical

    Example:
        >>> chains = find_critical_chains(graph, assessments, threshold=0.8, top_n=3)
        >>> chains[0]
        {
            "nodes": ["start", "auth", "payment", "end"],
            "risk": 0.92,
            "description": "Critical path with 4 nodes: high-risk authentication and payment processing"
        }
    """
    entry_nodes = graph.get_entry_nodes()
    exit_nodes = graph.get_exit_nodes()
    exit_ids = {node.id for node in exit_nodes}

    all_paths = []

    # Find all paths from each entry node to any exit node
    for entry_node in entry_nodes:
        paths = _find_all_paths_dfs(graph, entry_node, exit_ids)
        all_paths.extend(paths)

    # Calculate cumulative risk for each path
    chains_with_risk = []
    for path in all_paths:
        cumulative_risk = _calculate_cumulative_risk(path, node_assessments)

        # Only include paths above threshold
        if cumulative_risk >= threshold:
            chain = {
                "nodes": [node.id for node in path],
                "risk": cumulative_risk,
                "description": _generate_description(path, cumulative_risk, node_assessments)
            }
            chains_with_risk.append(chain)

    # Sort by risk (descending) and return top N
    chains_with_risk.sort(key=lambda x: x["risk"], reverse=True)
    return chains_with_risk[:top_n]


def _find_all_paths_dfs(graph: Graph, start_node: Node, exit_ids: set) -> List[List[Node]]:
    """
    Find all paths from start_node to any exit node using DFS with NodeStack.

    Args:
        graph: The graph to traverse
        start_node: Starting node for path search
        exit_ids: Set of exit node IDs to terminate paths

    Returns:
        List of paths, where each path is a list of Node objects
    """
    all_paths = []

    # Stack stores tuples of (current_node, path_so_far)
    # We use a regular list as a stack for tuples since NodeStack only handles Node objects
    stack = [(start_node, [start_node])]

    while stack:
        current_node, path = stack.pop()

        # If we've reached an exit node, save this path
        if current_node.id in exit_ids:
            all_paths.append(path)
            continue

        # Explore children
        children = graph.get_children(current_node)
        for child in children:
            # Avoid cycles (shouldn't happen in DAG, but defensive)
            if child not in path:
                new_path = path + [child]
                stack.append((child, new_path))

    return all_paths


def _calculate_cumulative_risk(path: List[Node], node_assessments: Dict) -> float:
    """
    Calculate cumulative risk for a path using the formula:
    R_cumulative = 1 - ∏(1 - R_i)

    This represents the probability that at least one node in the path fails.

    Args:
        path: List of Node objects in the path
        node_assessments: Dict with risk scores for each node

    Returns:
        Cumulative risk score (0.0 to 1.0)
    """
    # Start with probability of success = 1.0
    prob_success = 1.0

    for node in path:
        # Get node risk, default to 0.0 if not assessed
        node_risk = node_assessments.get(node.id, {}).get("risk", 0.0)

        # Probability this node succeeds = 1 - risk
        prob_node_success = 1.0 - node_risk

        # Multiply probabilities of success
        prob_success *= prob_node_success

    # Cumulative risk = 1 - probability all succeed
    cumulative_risk = 1.0 - prob_success

    return cumulative_risk


def _generate_description(path: List[Node], cumulative_risk: float, node_assessments: Dict) -> str:
    """
    Generate a human-readable description of why this chain is critical.

    Args:
        path: List of Node objects in the path
        cumulative_risk: Calculated cumulative risk
        node_assessments: Dict with risk and other data for each node

    Returns:
        String description of the critical chain
    """
    num_nodes = len(path)

    # Find high-risk nodes (risk > 0.7)
    high_risk_nodes = []
    for node in path:
        node_risk = node_assessments.get(node.id, {}).get("risk", 0.0)
        if node_risk > 0.7:
            high_risk_nodes.append(node.name)

    # Build description
    desc_parts = [f"Critical path with {num_nodes} nodes"]

    if high_risk_nodes:
        if len(high_risk_nodes) == 1:
            desc_parts.append(f"high-risk {high_risk_nodes[0]}")
        elif len(high_risk_nodes) == 2:
            desc_parts.append(f"high-risk {high_risk_nodes[0]} and {high_risk_nodes[1]}")
        else:
            # List first two and count the rest
            others = len(high_risk_nodes) - 2
            desc_parts.append(f"high-risk {high_risk_nodes[0]}, {high_risk_nodes[1]}, and {others} others")

    description = ": ".join(desc_parts)

    return description
