"""
Complete Analysis Pipeline for Florent

Orchestrates the end-to-end risk analysis workflow:
1. Build infrastructure graph from project requirements
2. Initialize agent orchestrator with AI evaluation
3. Run exploration within budget constraints
4. Propagate risk through dependency chains
5. Generate 2x2 strategic action matrix
6. Detect critical chains and pivotal nodes
7. Return comprehensive analysis output
"""

from typing import Dict, Any, List
from src.models.entities import Firm, Project
from src.models.graph import Graph, Node, Edge
from src.models.base import OperationType
from src.services.agent.core.orchestrator import AgentOrchestrator, NodeAssessment
from src.services.agent.analysis.matrix_classifier import classify_all_nodes, RiskQuadrant
from src.services.logging.logger import get_logger
from src.settings import settings

logger = get_logger(__name__)


def build_infrastructure_graph(project: Project) -> Graph:
    """
    Build a directed acyclic graph (DAG) representing project infrastructure.

    Creates nodes from project operations and establishes dependencies.
    For POC, creates a linear pipeline from entry to exit nodes.

    Args:
        project: Project entity with ops_requirements and entry/exit criteria

    Returns:
        Graph: Infrastructure DAG with nodes and edges

    Raises:
        ValueError: If project lacks required infrastructure data
    """
    logger.info(
        "building_infrastructure_graph",
        project_id=project.id,
        num_ops=len(project.ops_requirements)
    )

    if not project.ops_requirements:
        raise ValueError(f"Project {project.id} has no ops_requirements")

    if not project.entry_criteria or not project.success_criteria:
        raise ValueError(f"Project {project.id} lacks entry/exit criteria")

    # Load pipeline config
    config = settings.pipeline

    # Create nodes for each operational phase
    nodes = []

    # Entry node (site survey / initial assessment)
    first_category = project.ops_requirements[0].category if project.ops_requirements else "financing"
    entry_op = OperationType(
        name="Site Survey & Assessment",
        category=first_category,
        description="Initial feasibility study and site evaluation"
    )
    entry_node = Node(
        id=project.entry_criteria.entry_node_id,
        name="Site Survey",
        type=entry_op,
        embedding=[0.1, 0.2, 0.3]
    )
    nodes.append(entry_node)

    # Intermediate nodes from project ops_requirements
    for i, op in enumerate(project.ops_requirements):
        node = Node(
            id=f"node_{op.category}_{i}",
            name=op.name,
            type=op,
            embedding=[0.2 + i * 0.1, 0.3 + i * 0.1, 0.4 + i * 0.1]
        )
        nodes.append(node)

    # Exit node (operations handover / completion)
    last_category = project.ops_requirements[-1].category if project.ops_requirements else "financing"
    exit_op = OperationType(
        name="Operations Handover",
        category=last_category,
        description="Transfer to operations team and project closeout"
    )
    exit_node = Node(
        id=project.success_criteria.exit_node_id,
        name="Operations Handover",
        type=exit_op,
        embedding=[0.8, 0.9, 1.0]
    )
    nodes.append(exit_node)

    # Create linear dependency chain with configured weights
    edges = []
    for i in range(len(nodes) - 1):
        # Apply weight decay: initial_weight - (i * decay)
        weight = config.initial_edge_weight - (i * config.edge_weight_decay)
        edge = Edge(
            source=nodes[i],
            target=nodes[i + 1],
            weight=max(config.min_edge_weight, weight),
            relationship="prerequisite"
        )
        edges.append(edge)

    graph = Graph(nodes=nodes, edges=edges)

    logger.info(
        "graph_built",
        project_id=project.id,
        num_nodes=len(nodes),
        num_edges=len(edges),
        entry_node=entry_node.id,
        exit_node=exit_node.id
    )

    return graph


def propagate_risk(
    graph: Graph,
    node_assessments: Dict[str, NodeAssessment]
) -> Dict[str, float]:
    """
    Propagate risk scores through the graph from upstream to downstream.

    Simulates how failures cascade through dependencies. Each node's
    propagated risk is the product of its local risk and the maximum
    propagated risk from its parents.

    Args:
        graph: Infrastructure DAG
        node_assessments: Map of node_id to NodeAssessment

    Returns:
        Dict mapping node_id to propagated risk score (0.0 to 1.0)
    """
    logger.info("propagating_risk", num_nodes=len(node_assessments))

    # Load config
    config = settings.pipeline

    propagated_risk = {}

    # Topological sort for correct propagation order
    entry_nodes = graph.get_entry_nodes()
    visited = set()
    stack = []

    def dfs(node: Node):
        if node.id in visited:
            return
        visited.add(node.id)
        for child in graph.get_children(node):
            dfs(child)
        stack.append(node)

    for entry in entry_nodes:
        dfs(entry)

    # Process in reverse topological order
    for node in reversed(stack):
        assessment = node_assessments.get(node.id)
        if not assessment:
            logger.warning("missing_assessment", node_id=node.id)
            local_risk = config.default_failure_likelihood
        else:
            local_risk = assessment.risk_level

        # Get maximum propagated risk from parents
        parents = graph.get_parents(node)
        if not parents:
            # Entry node - no upstream risk
            propagated_risk[node.id] = local_risk
        else:
            # Compound risk from parents
            parent_risks = [propagated_risk.get(p.id, config.default_failure_likelihood) for p in parents]
            max_parent_risk = max(parent_risks)
            # Combined risk using configured propagation factor
            # Formula: local_risk + (max_parent_risk * local_risk * factor)
            propagated_risk[node.id] = min(
                1.0,
                local_risk + (max_parent_risk * local_risk * config.risk_propagation_factor)
            )

    logger.info(
        "risk_propagated",
        avg_risk=sum(propagated_risk.values()) / len(propagated_risk) if propagated_risk else 0
    )

    return propagated_risk


def detect_critical_chains(
    graph: Graph,
    propagated_risk: Dict[str, float],
    threshold: float = None
) -> List[Dict[str, Any]]:
    """
    Detect critical dependency chains with high aggregate risk.

    Identifies paths through the graph where cumulative risk exceeds
    the threshold, indicating vulnerable sequences that could derail
    the project.

    Args:
        graph: Infrastructure DAG
        propagated_risk: Map of node_id to propagated risk
        threshold: Minimum risk to consider chain critical (uses config if None)

    Returns:
        List of critical chain dictionaries with nodes and metrics
    """
    # Use config threshold if not provided
    if threshold is None:
        threshold = settings.pipeline.critical_chain_threshold

    logger.info("detecting_critical_chains", threshold=threshold)

    critical_chains = []
    entry_nodes = graph.get_entry_nodes()
    exit_nodes = graph.get_exit_nodes()

    # For each entry-to-exit path, calculate aggregate risk
    for entry in entry_nodes:
        for exit_node in exit_nodes:
            path = _find_path(graph, entry, exit_node)
            if path:
                # Calculate aggregate risk along path
                path_risks = [
                    propagated_risk.get(node_id, settings.pipeline.default_failure_likelihood)
                    for node_id in path
                ]
                aggregate_risk = sum(path_risks) / len(path_risks)

                if aggregate_risk >= threshold:
                    chain = {
                        "chain_id": f"chain_{entry.id}_to_{exit_node.id}",
                        "nodes": path,
                        "aggregate_risk": round(aggregate_risk, 3),
                        "impact_description": f"Critical path from {entry.name} to {exit_node.name}"
                    }
                    critical_chains.append(chain)
                    logger.info(
                        "critical_chain_detected",
                        chain_id=chain["chain_id"],
                        aggregate_risk=aggregate_risk,
                        path_length=len(path)
                    )

    if not critical_chains:
        logger.info("no_critical_chains_detected")

    return critical_chains


def _find_path(graph: Graph, start: Node, end: Node) -> List[str]:
    """BFS to find path from start to end node."""
    from collections import deque

    if start.id == end.id:
        return [start.id]

    queue = deque([(start, [start.id])])
    visited = {start.id}

    while queue:
        current, path = queue.popleft()

        for child in graph.get_children(current):
            if child.id == end.id:
                return path + [child.id]

            if child.id not in visited:
                visited.add(child.id)
                queue.append((child, path + [child.id]))

    return []


def run_analysis(
    firm: Firm,
    project: Project,
    budget: int = None
) -> Dict[str, Any]:
    """
    Execute complete analysis pipeline.

    Steps:
    1. Build infrastructure graph from project requirements
    2. Initialize AgentOrchestrator with AI evaluation
    3. Run exploration within budget constraints
    4. Propagate risk through dependency chains
    5. Classify nodes in Influence vs Importance matrix
    6. Detect critical chains and pivotal nodes
    7. Return comprehensive analysis output

    Args:
        firm: Firm entity with capabilities and context
        project: Project entity with requirements and infrastructure
        budget: Number of AI evaluation calls to make (uses config default if None)

    Returns:
        Dictionary containing:
        - node_assessments: Map of node_id to assessment data
        - matrix_classifications: Influence vs Importance mapping
        - critical_chains: List of high-risk dependency chains
        - summary: Overall metrics and recommendations

    Raises:
        ValueError: If inputs are invalid or pipeline fails
    """
    # Load config
    pipeline_config = settings.pipeline
    matrix_config = settings.matrix
    bidding_config = settings.bidding

    # Use default budget if not provided
    if budget is None:
        budget = pipeline_config.default_budget

    logger.info(
        "analysis_pipeline_started",
        firm_id=firm.id,
        project_id=project.id,
        budget=budget
    )

    try:
        # Step 1: Build infrastructure graph
        logger.info("step_1_building_graph")
        graph = build_infrastructure_graph(project)

        # Step 2: Initialize orchestrator
        logger.info("step_2_initializing_orchestrator")
        orchestrator = AgentOrchestrator(graph)

        # Step 3: Run exploration
        logger.info("step_3_running_exploration", budget=budget)
        node_assessments_raw = orchestrator.run_exploration(budget)

        logger.info(
            "exploration_complete",
            nodes_evaluated=len(node_assessments_raw)
        )

        # Step 4: Propagate risk
        logger.info("step_4_propagating_risk")
        propagated_risk = propagate_risk(graph, node_assessments_raw)

        # Step 5: Generate action matrix using configured thresholds
        logger.info("step_5_generating_matrix")
        node_names = {node.id: node.name for node in graph.nodes}

        matrix_classifications = classify_all_nodes(
            node_assessments_raw,
            node_names,
            influence_threshold=matrix_config.influence_threshold,
            importance_threshold=matrix_config.importance_threshold
        )

        logger.info(
            "matrix_generated",
            type_a=len(matrix_classifications.get(RiskQuadrant.TYPE_A, [])),
            type_b=len(matrix_classifications.get(RiskQuadrant.TYPE_B, [])),
            type_c=len(matrix_classifications.get(RiskQuadrant.TYPE_C, [])),
            type_d=len(matrix_classifications.get(RiskQuadrant.TYPE_D, []))
        )

        # Step 6: Detect critical chains
        logger.info("step_6_detecting_critical_chains")
        critical_chains = detect_critical_chains(graph, propagated_risk)

        # Step 6.1: Build final enriched node assessments
        node_assessments = {
            node_id: {
                "name": graph.get_node(node_id).name,
                "influence": assessment.influence_score,
                "risk": assessment.risk_level,
                "reasoning": assessment.reasoning,
                "is_on_critical_path": any(node_id in chain["nodes"] for chain in critical_chains)
            }
            for node_id, assessment in node_assessments_raw.items()
        }

        # Step 7: Generate summary
        avg_risk = sum(propagated_risk.values()) / len(propagated_risk) if propagated_risk else 0
        max_risk = max(propagated_risk.values()) if propagated_risk else 0

        # Calculate overall bankability (inverse of average risk)
        bankability = 1.0 - avg_risk

        # Convert matrix_classifications to legacy format for recommendations
        action_matrix = {
            "Type A": [n.node_id for n in matrix_classifications.get(RiskQuadrant.TYPE_A, [])],
            "Type B": [n.node_id for n in matrix_classifications.get(RiskQuadrant.TYPE_B, [])],
            "Type C": [n.node_id for n in matrix_classifications.get(RiskQuadrant.TYPE_C, [])],
            "Type D": [n.node_id for n in matrix_classifications.get(RiskQuadrant.TYPE_D, [])]
        }

        summary = {
            "firm_id": firm.id,
            "project_id": project.id,
            "nodes_analyzed": len(node_assessments),
            "budget_used": len(node_assessments),
            "aggregate_project_score": round(bankability, 3),
            "overall_bankability": round(bankability, 3),
            "average_risk": round(avg_risk, 3),
            "maximum_risk": round(max_risk, 3),
            "critical_chains_detected": len(critical_chains),
            "high_risk_nodes": len(action_matrix["Type A"]) + len(action_matrix["Type C"]),
            "recommendations": _generate_recommendations(action_matrix, critical_chains, bankability)
        }

        # Add explicit recommendation with configured threshold
        recommendation = {
            "should_bid": bankability >= bidding_config.min_bankability_threshold,
            "confidence": bankability,
            "key_risks": summary["recommendations"][:2],
            "key_opportunities": [r for r in summary["recommendations"] if "strong" in r.lower()][:2]
        }

        logger.info(
            "analysis_pipeline_complete",
            bankability=summary["overall_bankability"],
            critical_chains=len(critical_chains),
            high_risk_nodes=summary["high_risk_nodes"]
        )

        return {
            "node_assessments": node_assessments,
            "matrix_classifications": action_matrix,
            "critical_chains": critical_chains,
            "summary": summary,
            "recommendation": recommendation
        }

    except Exception as e:
        logger.error(
            "analysis_pipeline_failed",
            error=str(e),
            firm_id=firm.id,
            project_id=project.id
        )
        raise


def _generate_recommendations(
    action_matrix: Dict[str, List[str]],
    critical_chains: List[Dict[str, Any]],
    bankability: float
) -> List[str]:
    """Generate strategic recommendations based on analysis."""
    # Load bidding config for thresholds
    bidding_config = settings.bidding

    recommendations = []

    # Bankability assessment with configured thresholds
    if bankability >= bidding_config.bankability_high:
        recommendations.append("Project shows strong bankability - proceed with confidence")
    elif bankability >= bidding_config.bankability_medium:
        recommendations.append("Project is moderately bankable - implement risk controls")
    else:
        recommendations.append("Project has significant risk - consider restructuring or declining")

    # Action matrix recommendations
    if len(action_matrix["Type A"]) > 0:
        recommendations.append(
            f"Prioritize mitigation for {len(action_matrix['Type A'])} high-risk, high-influence nodes (Type A)"
        )

    if len(action_matrix["Type C"]) > 0:
        recommendations.append(
            f"Develop contingency plans for {len(action_matrix['Type C'])} high-risk, low-influence nodes (Type C)"
        )

    if len(action_matrix["Type B"]) > 0:
        recommendations.append(
            f"Optimize and automate {len(action_matrix['Type B'])} low-risk, high-influence operations (Type B)"
        )

    # Critical chains
    if len(critical_chains) > 0:
        recommendations.append(
            f"Monitor {len(critical_chains)} critical dependency chain(s) closely - single points of failure"
        )
    else:
        recommendations.append("No critical chains detected - project has good risk distribution")

    return recommendations
