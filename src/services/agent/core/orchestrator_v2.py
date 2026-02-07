"""Enhanced Agent Orchestrator with critical chain analysis and async execution."""
import asyncio
import json
import hashlib
from pathlib import Path
from typing import Set, Dict, List, Optional

import dspy
from src.models.base import Firm
from src.models.entities import Project
from src.models.graph import Graph, Node
from src.models.analysis import (
    AnalysisOutput,
    NodeAssessment,
    TraversalStatus,
    CriticalChain,
    SummaryMetrics,
    BidRecommendation,
)
from src.services.agent.core.traversal import NodeHeap
from src.services.agent.models.signatures import NodeSignature
from src.services.agent.analysis.critical_chain import (
    detect_critical_chains,
    mark_critical_path_nodes,
)
from src.services.agent.analysis.matrix_classifier import (
    classify_all_nodes,
    should_bid,
    RiskQuadrant,
)
from src.services.logging import get_logger

logger = get_logger(__name__)

# Cache directory for DSPy results
CACHE_DIR = Path.home() / ".cache" / "florent" / "dspy_cache"
CACHE_DIR.mkdir(parents=True, exist_ok=True)


class RiskOrchestrator:
    """
    Enhanced orchestrator implementing:
    - Critical chain-based prioritization
    - Exponential backoff retry logic
    - Disk-based caching
    - Async parallel execution
    - 2x2 matrix classification
    """

    def __init__(
        self,
        firm: Firm,
        project: Project,
        graph: Graph,
        max_retries: int = 3,
        cache_enabled: bool = True,
    ):
        self.firm = firm
        self.project = project
        self.graph = graph
        self.max_retries = max_retries
        self.cache_enabled = cache_enabled

        self.heap = NodeHeap(max_heap=True)
        self.visited: Set[str] = set()
        self.evaluator = dspy.Predict(NodeSignature)

        # Will be populated during analysis
        self.node_assessments: Dict[str, NodeAssessment] = {}
        self.critical_path_markers: Dict[str, bool] = {}
        self.token_count = 0

    def _cache_key(self, node: Node, firm_id: str, project_id: str) -> str:
        """Generate cache key for a node evaluation."""
        key_str = f"{firm_id}:{project_id}:{node.id}:{node.name}:{node.type.name}"
        return hashlib.sha256(key_str.encode()).hexdigest()

    def _load_from_cache(self, cache_key: str) -> Optional[NodeAssessment]:
        """Load cached assessment if available."""
        if not self.cache_enabled:
            return None

        cache_file = CACHE_DIR / f"{cache_key}.json"
        if cache_file.exists():
            try:
                with open(cache_file, "r") as f:
                    data = json.load(f)
                    logger.debug("cache_hit", node_id=data.get("node_id"))
                    return NodeAssessment(**data)
            except Exception as e:
                logger.warning("cache_load_error", error=str(e))
                return None
        return None

    def _save_to_cache(self, cache_key: str, assessment: NodeAssessment):
        """Save assessment to disk cache."""
        if not self.cache_enabled:
            return

        cache_file = CACHE_DIR / f"{cache_key}.json"
        try:
            with open(cache_file, "w") as f:
                json.dump(assessment.model_dump(), f)
            logger.debug("cache_saved", node_id=assessment.node_id)
        except Exception as e:
            logger.warning("cache_save_error", error=str(e))

    async def _evaluate_node_with_retry(self, node: Node) -> NodeAssessment:
        """Evaluate node with exponential backoff retry logic."""
        # Check cache first
        cache_key = self._cache_key(node, self.firm.id, self.project.id)
        cached = self._load_from_cache(cache_key)
        if cached:
            return cached

        # Build context for DSPy
        firm_context = self._build_firm_context()
        node_requirements = self._build_node_requirements(node)

        # Retry loop with exponential backoff
        for attempt in range(self.max_retries):
            try:
                result = self.evaluator(
                    firm_context=firm_context,
                    node_requirements=node_requirements,
                )

                # Parse result
                influence = float(result.influence_score) if hasattr(result, "influence_score") else 0.5
                risk = float(result.risk_assessment) if hasattr(result, "risk_assessment") else 0.5
                reasoning = result.reasoning if hasattr(result, "reasoning") else "No reasoning provided"

                # Estimate token usage (rough approximation)
                self.token_count += len(firm_context.split()) + len(node_requirements.split()) + 200

                assessment = NodeAssessment(
                    node_id=node.id,
                    node_name=node.name,
                    influence_score=max(0.0, min(1.0, influence)),
                    risk_level=max(0.0, min(1.0, risk)),
                    reasoning=reasoning,
                    is_on_critical_path=self.critical_path_markers.get(node.id, False),
                )

                # Save to cache
                self._save_to_cache(cache_key, assessment)

                logger.info(
                    "node_evaluated",
                    node_id=node.id,
                    influence=assessment.influence_score,
                    risk=assessment.risk_level,
                    attempt=attempt + 1,
                )

                return assessment

            except Exception as e:
                wait_time = 2 ** attempt  # Exponential backoff: 1s, 2s, 4s
                logger.warning(
                    "dspy_call_failed",
                    node_id=node.id,
                    attempt=attempt + 1,
                    error=str(e),
                    retry_in=wait_time,
                )

                if attempt < self.max_retries - 1:
                    await asyncio.sleep(wait_time)
                else:
                    # All retries exhausted - crash as specified
                    logger.error("dspy_call_exhausted", node_id=node.id)
                    raise RuntimeError(
                        f"Failed to evaluate node {node.id} after {self.max_retries} attempts: {e}"
                    )

    def _build_firm_context(self) -> str:
        """Build firm capability context for DSPy."""
        sectors = ", ".join(s.name for s in self.firm.sectors)
        services = ", ".join(s.name for s in self.firm.services)
        countries = ", ".join(c.a3 for c in self.firm.countries_active)
        focuses = ", ".join(f.name for f in self.firm.strategic_focuses)

        return f"""Firm: {self.firm.name}
Sectors: {sectors}
Services: {services}
Active Countries: {countries}
Strategic Focuses: {focuses}
Project Timeline Preference: {self.firm.preferred_project_timeline} months"""

    def _build_node_requirements(self, node: Node) -> str:
        """Build node requirements context for DSPy."""
        return f"""Node: {node.name} (ID: {node.id})
Type: {node.type.name}
Category: {node.type.category}
Description: {node.type.description}"""

    async def run_analysis(self, budget: int) -> AnalysisOutput:
        """Main analysis loop with critical chain prioritization."""
        logger.info(
            "analysis_started",
            firm=self.firm.name,
            project=self.project.name,
            budget=budget,
        )

        # Step 1: Get entry/exit nodes (hybrid approach)
        try:
            entry_nodes = self.graph.get_entry_nodes()
            entry_node = next(
                (n for n in entry_nodes if n.id == self.project.entry_criteria.entry_node_id),
                entry_nodes[0],
            )
        except ValueError:
            # Fallback to project-specified entry
            entry_node = next(
                n for n in self.graph.nodes
                if n.id == self.project.entry_criteria.entry_node_id
            )

        try:
            exit_nodes = self.graph.get_exit_nodes()
            exit_node = next(
                (n for n in exit_nodes if n.id == self.project.success_criteria.exit_node_id),
                exit_nodes[0],
            )
        except ValueError:
            exit_node = next(
                n for n in self.graph.nodes
                if n.id == self.project.success_criteria.exit_node_id
            )

        logger.info("entry_exit_identified", entry=entry_node.id, exit=exit_node.id)

        # Step 2: Identify initial critical path (using default risks)
        default_risks = {n.id: 0.5 for n in self.graph.nodes}
        try:
            critical_chains = detect_critical_chains(
                self.graph, entry_node, exit_node, default_risks, top_n=1
            )
            initial_critical_chain = critical_chains[0][0] if critical_chains else []
            self.critical_path_markers = mark_critical_path_nodes(self.graph, initial_critical_chain)
            logger.info("initial_critical_path", length=len(initial_critical_chain))
        except ValueError as e:
            logger.warning("no_critical_path", error=str(e))
            self.critical_path_markers = {n.id: False for n in self.graph.nodes}

        # Step 3: Initialize heap with entry node
        self.heap.push(entry_node, priority=1.0)

        # Step 4: Parallel node evaluation with priority-based traversal
        traversal_status = TraversalStatus.COMPLETE
        traversal_message = None

        while not self.heap.is_empty() and budget > 0:
            node = self.heap.pop()

            if node.id in self.visited:
                continue

            self.visited.add(node.id)

            # Evaluate node (async with retry)
            assessment = await self._evaluate_node_with_retry(node)
            self.node_assessments[node.id] = assessment

            # Calculate priority for children: Risk × is_critical_path_multiplier
            is_critical_multiplier = 2.0 if assessment.is_on_critical_path else 1.0
            priority = assessment.risk_level * is_critical_multiplier

            # Push children
            for child in self.graph.get_children(node):
                if child.id not in self.visited:
                    self.heap.push(child, priority=priority)

            budget -= 1

        # Check if we exhausted budget
        if not self.heap.is_empty():
            traversal_status = TraversalStatus.INCOMPLETE
            traversal_message = f"Budget exhausted. {len(self.visited)}/{len(self.graph.nodes)} nodes evaluated."
            logger.warning("budget_exhausted", nodes_evaluated=len(self.visited))

        # Step 5: Detect final critical chains with real risk scores
        risk_scores = {aid: a.risk_level for aid, a in self.node_assessments.items()}
        try:
            final_critical_chains = detect_critical_chains(
                self.graph, entry_node, exit_node, risk_scores, top_n=3
            )
            critical_chains_output = [
                CriticalChain(
                    node_ids=[n.id for n in chain],
                    node_names=[n.name for n in chain],
                    cumulative_risk=risk,
                    length=len(chain),
                )
                for chain, risk in final_critical_chains
            ]
        except ValueError:
            critical_chains_output = []

        # Step 6: 2x2 Matrix classification
        node_names = {n.id: n.name for n in self.graph.nodes}
        matrix_classifications = classify_all_nodes(
            self.node_assessments,
            node_names,
            influence_threshold=0.6,
            risk_threshold=0.7,
        )

        # Step 7: Bid recommendation
        critical_chain_ids = critical_chains_output[0].node_ids if critical_chains_output else []
        should_bid_result = should_bid(matrix_classifications, critical_chain_ids)

        cooked_count = len(matrix_classifications.get(RiskQuadrant.COOKED_ZONE, []))
        cooked_percentage = cooked_count / len(self.node_assessments) if self.node_assessments else 0.0

        recommendation = BidRecommendation(
            should_bid=should_bid_result,
            confidence=0.8 if len(self.node_assessments) > 10 else 0.5,
            reasoning=self._generate_bid_reasoning(
                should_bid_result, cooked_percentage, critical_chains_output
            ),
            key_risks=self._extract_key_risks(matrix_classifications),
            key_opportunities=self._extract_key_opportunities(matrix_classifications),
        )

        # Step 8: Summary metrics
        critical_failure_likelihood = (
            critical_chains_output[0].cumulative_risk if critical_chains_output else 0.5
        )
        aggregate_score = 1.0 - critical_failure_likelihood

        summary = SummaryMetrics(
            aggregate_project_score=aggregate_score,
            total_token_cost=self.token_count,
            critical_failure_likelihood=critical_failure_likelihood,
            nodes_evaluated=len(self.node_assessments),
            total_nodes=len(self.graph.nodes),
            cooked_zone_percentage=cooked_percentage,
        )

        logger.info(
            "analysis_complete",
            nodes_evaluated=len(self.node_assessments),
            should_bid=should_bid_result,
            aggregate_score=aggregate_score,
        )

        return AnalysisOutput(
            firm=self.firm,
            project=self.project,
            traversal_status=traversal_status,
            traversal_message=traversal_message,
            node_assessments=self.node_assessments,
            critical_chains=critical_chains_output,
            matrix_classifications=matrix_classifications,
            summary=summary,
            recommendation=recommendation,
        )

    def _generate_bid_reasoning(
        self, should_bid: bool, cooked_pct: float, chains: List[CriticalChain]
    ) -> str:
        """Generate natural language bid reasoning."""
        if should_bid:
            return (
                f"Recommendation: PROCEED WITH BID. "
                f"Critical chain risk: {chains[0].cumulative_risk:.1%}. "
                f"Only {cooked_pct:.1%} of nodes in 'Cooked Zone'. "
                f"Project aligns with firm capabilities."
            )
        else:
            return (
                f"Recommendation: DO NOT BID. "
                f"Critical chain dominated by high-risk, low-influence nodes. "
                f"{cooked_pct:.1%} of nodes in 'Cooked Zone'. "
                f"Risk exceeds firm's capability envelope."
            )

    def _extract_key_risks(self, classifications: Dict) -> List[str]:
        """Extract top 3 key risks from Cooked Zone."""
        cooked_nodes = classifications.get(RiskQuadrant.COOKED_ZONE, [])
        return [f"{n.node_name} (Risk: {n.risk_level:.2f})" for n in cooked_nodes[:3]]

    def _extract_key_opportunities(self, classifications: Dict) -> List[str]:
        """Extract top 3 opportunities from Safe Wins."""
        safe_wins = classifications.get(RiskQuadrant.SAFE_WINS, [])
        return [f"{n.node_name} (Influence: {n.influence_score:.2f})" for n in safe_wins[:3]]
