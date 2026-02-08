"""Enhanced Agent Orchestrator with critical chain analysis and async execution."""
import asyncio
import json
import hashlib
from pathlib import Path
from typing import Set, Dict, List, Optional

import dspy
from src.models.entities import Firm, Project
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
from src.services.agent.models.signatures import NodeSignature, DiscoverySignature
from src.services.agent.analysis.critical_chain import (
    detect_critical_chains,
)
from src.services.agent.analysis.matrix_classifier import (
    classify_all_nodes,
    should_bid,
    RiskQuadrant,
)
from src.models.base import OperationType
from src.settings import settings
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
        self.node_evaluator = dspy.Predict(NodeSignature)
        self.discovery_evaluator = dspy.Predict(DiscoverySignature)
        self.discovered_nodes_count = 0
        self.DISCOVERY_LIMIT = int(getattr(settings, "GRAPH_MAX_DISCOVERED_NODES", 250))
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
            # We still trigger discovery for cached nodes to ensure graph expansion
            # especially when discovery logic or personas have changed!
            if self.discovered_nodes_count < self.DISCOVERY_LIMIT:
                await self._discover_and_inject_nodes(node, self._build_node_requirements(node))
            return cached

        # Build context for DSPy
        firm_context = self._build_firm_context()
        node_requirements = self._build_node_requirements(node)

        # Retry loop with exponential backoff
        for attempt in range(self.max_retries):
            try:
                result = self.node_evaluator(
                    firm_context=firm_context,
                    node_requirements=node_requirements,
                )

                # Parse result
                importance = float(result.importance_score) if hasattr(result, "importance_score") else 0.5
                influence = float(result.influence_score) if hasattr(result, "influence_score") else 0.5
                reasoning = result.reasoning if hasattr(result, "reasoning") else "No reasoning provided"

                # Derived Risk Calculation
                derived_risk = importance * (1.0 - influence)

                # Update token usage
                self.token_count += 300

                assessment = NodeAssessment(
                    node_id=node.id,
                    node_name=node.name,
                    importance_score=max(0.0, min(1.0, importance)),
                    influence_score=max(0.0, min(1.0, influence)),
                    risk_level=max(0.0, min(1.0, derived_risk)),
                    reasoning=reasoning,
                    is_on_critical_path=self.critical_path_markers.get(node.id, False),
                )

                # TRIGGER RECURSIVE DISCOVERY
                # Bumping: Every node now triggers discovery to maximize data density
                if self.discovered_nodes_count < self.DISCOVERY_LIMIT:
                    await self._discover_and_inject_nodes(node, node_requirements)

                # Save to cache
                self._save_to_cache(cache_key, assessment)

                return assessment

            except Exception as e:
                wait_time = 2 ** attempt  # Exponential backoff
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
                    logger.error("dspy_call_exhausted", node_id=node.id)
                    raise RuntimeError(
                        f"Failed to evaluate node {node.id} after {self.max_retries} attempts: {e}"
                    )

    async def _discover_and_inject_nodes(self, node: Node, requirements: str):
        """Generatively discover hidden infrastructure dependencies across multiple personas concurrently."""
        if self.discovered_nodes_count >= self.DISCOVERY_LIMIT:
            return

        logger.info("recursive_discovery_triggered", node_id=node.id)
        
        # Load taxonomy for strict adherence
        try:
            taxonomy_path = Path(__file__).parent.parent.parent.parent / "data" / "taxonomy" / "services.json"
            with open(taxonomy_path, "r") as f:
                taxonomy = json.load(f)
                valid_types = ", ".join([s["name"] for s in taxonomy])
        except Exception as e:
            logger.warning("taxonomy_load_failed", error=str(e))
            valid_types = "Infrastructure, Logistics, Financing, Regulatory, Technical"

        # Perspectives to simulate for diverse data generation
        personas = [
            "Technical Infrastructure Expert",
            "Financial Risk & Compliance Auditor",
            "Geopolitical & Regulatory Consultant"
        ]
        
        # Build context of existing graph to avoid duplicates
        existing_nodes = ", ".join([n.name for n in self.graph.nodes])

        async def _run_persona_discovery(persona: str):
            """Internal helper to run DSPy in a thread to avoid blocking the event loop."""
            try:
                # dspy.Predict is typically synchronous, so we run it in a thread
                discovery = await asyncio.to_thread(
                    self.discovery_evaluator,
                    node_requirements=requirements,
                    existing_graph_context=existing_nodes,
                    persona=persona,
                    valid_types=valid_types
                )
                return persona, discovery
            except Exception as e:
                logger.warning("discovery_failed", node_id=node.id, persona=persona, error=str(e))
                return persona, None

        # Run all persona discoveries in parallel
        tasks = [_run_persona_discovery(p) for p in personas]
        results = await asyncio.gather(*tasks)
        
        for persona, discovery in results:
            if not discovery:
                continue
                
            if self.discovered_nodes_count >= self.DISCOVERY_LIMIT:
                break
                
            # Parser for "Name, Category, Type, Description" format
            lines = [line.strip() for line in discovery.hidden_dependencies.split('\n') if ',' in line]

            # Get valid categories from registry
            from src.models.base import get_categories
            valid_categories_set = get_categories()

            for line in lines:
                parts = [p.strip() for p in line.split(',')]
                if len(parts) >= 4:
                    name, category, type_name, desc = parts[0], parts[1], parts[2], parts[3]
                elif len(parts) >= 3:
                    # Fallback: if agent only returns 3 parts, use 'other' as category
                    name, type_name, desc = parts[0], parts[1], parts[2]
                    category = "other"
                else:
                    continue

                new_id = f"gen_{hashlib.md5(name.encode()).hexdigest()[:8]}"

                if any(n.id == new_id for n in self.graph.nodes):
                    continue

                if self.discovered_nodes_count >= self.DISCOVERY_LIMIT:
                    break

                # Validate category
                if category.lower() not in valid_categories_set:
                    logger.warning(
                        "invalid_category",
                        category=category,
                        node=name,
                        persona=persona,
                        msg="Using 'other' instead"
                    )
                    category = "other"

                # Create new node
                new_node = Node(
                    id=new_id,
                    name=name,
                    type=OperationType(
                        name=type_name,
                        category=category.lower(),
                        description=f"[{persona}] {desc}"
                    )
                )

                # Inject into graph
                self.graph.add_node(new_node)
                self.graph.add_edge(node, new_node, weight=0.8, relationship=f"discovered by {persona}", validate=False)

                self.discovered_nodes_count += 1
                logger.info("new_node_discovered", persona=persona, parent=node.id, new_node=new_node.name, total=self.discovered_nodes_count)
                    
            self.token_count += 500

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
Project Timeline Preference: {self.firm.prefered_project_timeline} months"""

    def _build_node_requirements(self, node: Node) -> str:
        """Build node requirements context for DSPy."""
        return f"""Node: {node.name} (ID: {node.id})
Type: {node.type.name}
Category: {node.type.category}
Description: {node.type.description}"""

    async def run_analysis(self, budget: int) -> AnalysisOutput:
        """Main analysis loop with full graph and chain transparency."""
        logger.info(
            "analysis_started_v2",
            firm=self.firm.name,
            project=self.project.name,
            budget=budget,
        )

        # Step 1: Get entry/exit nodes
        try:
            entry_nodes = self.graph.get_entry_nodes()
            entry_node = next(
                (n for n in entry_nodes if n.id == self.project.entry_criteria.entry_node_id),
                entry_nodes[0],
            )
        except (ValueError, IndexError):
            entry_node = next(n for n in self.graph.nodes if n.id == self.project.entry_criteria.entry_node_id)

        try:
            exit_nodes = self.graph.get_exit_nodes()
            exit_node = next(
                (n for n in exit_nodes if n.id == self.project.success_criteria.exit_node_id),
                exit_nodes[0],
            )
        except (ValueError, IndexError):
            exit_node = next(n for n in self.graph.nodes if n.id == self.project.success_criteria.exit_node_id)

        # Step 2: Initialize heap and visited
        self.heap.push(entry_node, priority=1.0)
        
        # Step 3: Progressive traversal within budget
        while not self.heap.is_empty() and budget > 0:
            node = self.heap.pop()
            if node.id in self.visited:
                continue

            self.visited.add(node.id)
            assessment = await self._evaluate_node_with_retry(node)
            self.node_assessments[node.id] = assessment

            # Children of unmanaged importance get priority
            # Priority = Importance * (1 - Influence)
            priority = assessment.risk_level
            for child in self.graph.get_children(node):
                if child.id not in self.visited:
                    self.heap.push(child, priority=priority)
            
            budget -= 1

        # Step 4: Ensure ALL nodes are present in output (at least with default values)
        for node in self.graph.nodes:
            if node.id not in self.node_assessments:
                self.node_assessments[node.id] = NodeAssessment(
                    node_id=node.id,
                    node_name=node.name,
                    importance_score=0.5,
                    influence_score=0.5,
                    risk_level=0.25,  # 0.5 * (1 - 0.5)
                    reasoning="Node not reached within analysis budget.",
                    is_on_critical_path=False
                )

        # Step 5: Detect ALL critical chains (top_n=None)
        risk_scores = {aid: a.risk_level for aid, a in self.node_assessments.items()}
        try:
            final_chains = detect_critical_chains(
                self.graph, entry_node, exit_node, risk_scores, top_n=None
            )
            all_chains_output = [
                CriticalChain(
                    node_ids=[n.id for n in chain],
                    node_names=[n.name for n in chain],
                    cumulative_risk=risk,
                    length=len(chain),
                )
                for chain, risk in final_chains
            ]
        except ValueError:
            all_chains_output = []

        # Step 6: Matrix classification
        node_names = {n.id: n.name for n in self.graph.nodes}
        matrix_classifications = classify_all_nodes(
            self.node_assessments,
            node_names,
            influence_threshold=0.6,
            importance_threshold=0.6,
        )

        # Step 7: Final Bid Recommendation (Bidding logic)
        primary_chain = all_chains_output[0].node_ids if all_chains_output else []
        should_bid_result = should_bid(matrix_classifications, primary_chain)

        critical_deps = len(matrix_classifications.get(RiskQuadrant.TYPE_C, []))

        recommendation = BidRecommendation(
            should_bid=should_bid_result,
            confidence=0.9 if budget > 0 else 0.6,
            reasoning=self._generate_bid_reasoning(
                should_bid_result, critical_deps, all_chains_output
            ),
            key_risks=self._extract_key_risks(matrix_classifications),
            key_opportunities=self._extract_key_opportunities(matrix_classifications),
        )

        # Step 8: Summary metrics
        critical_failure_likelihood = all_chains_output[0].cumulative_risk if all_chains_output else 0.5
        
        summary = SummaryMetrics(
            aggregate_project_score=1.0 - critical_failure_likelihood,
            total_token_cost=self.token_count,
            critical_failure_likelihood=critical_failure_likelihood,
            nodes_evaluated=len(self.visited),
            total_nodes=len(self.graph.nodes),
            critical_dependency_count=critical_deps,
        )

        traversal_status = TraversalStatus.COMPLETE if budget > 0 else TraversalStatus.INCOMPLETE

        return AnalysisOutput(
            firm=self.firm,
            project=self.project,
            traversal_status=traversal_status,
            node_assessments=self.node_assessments,
            all_chains=all_chains_output,
            matrix_classifications=matrix_classifications,
            summary=summary,
            recommendation=recommendation,
        )

    def _generate_bid_reasoning(
        self, should_bid: bool, critical_count: int, chains: List[CriticalChain]
    ) -> str:
        """Generate bid reasoning based on structural project risk."""
        risk_str = f"{chains[0].cumulative_risk:.1%}" if chains else "Unknown"
        if should_bid:
            return (
                f"Recommendation: PROCEED. The critical dependency chain shows manageable risk ({risk_str}). "
                f"Identified {critical_count} critical dependencies outside of firm's direct influence, "
                "which is within acceptable structural limits for this firm profile."
            )
        else:
            return (
                f"Recommendation: DO NOT BID. The primary dependency chain is compromised by high-importance "
                f"nodes where the firm has low influence. Total risk for primary path: {risk_str}. "
                f"Found {critical_count} critical structural dependencies that exceed firm capability envelope."
            )

    def _extract_key_risks(self, classifications: Dict) -> List[str]:
        """Extract top 3 key risks from Critical Dependencies."""
        critical_deps = classifications.get(RiskQuadrant.TYPE_C, [])
        return [f"{n.node_name} (Risk: {n.importance_score * (1-n.influence_score):.2f})" for n in critical_deps[:3]]

    def _extract_key_opportunities(self, classifications: Dict) -> List[str]:
        """Extract top 3 opportunities from Strategic Wins."""
        strategic_wins = classifications.get(RiskQuadrant.TYPE_B, [])
        return [f"{n.node_name} (Influence: {n.influence_score:.2f})" for n in strategic_wins[:3]]
