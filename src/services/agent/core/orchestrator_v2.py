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
from src.models.orchestration import (
    TokenUsageTracker,
    DEFAULT_PERSONAS,
    ExecutionTrace,
    ExecutionPhase,
    CriticalPathMarker
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


class RiskOrchestrator:
    """
    Enhanced orchestrator implementing:
    - Critical chain-based prioritization
    - Exponential backoff retry logic
    - Disk-based caching
    - Async parallel execution
    - 2x2 matrix classification
    - Token usage tracking
    - Execution tracing
    """

    def __init__(
        self,
        firm: Firm,
        project: Project,
        graph: Graph,
        max_retries: int = None,
        cache_enabled: bool = None,
    ):
        self.firm = firm
        self.project = project
        self.graph = graph

        # Load configuration
        self.config = settings.agent
        self.matrix_config = settings.matrix
        self.graph_config = settings.graph_builder

        # Use config defaults if not provided
        self.max_retries = max_retries if max_retries is not None else self.config.max_retries
        self.cache_enabled = cache_enabled if cache_enabled is not None else self.config.cache_enabled
        self.cache_dir = self.config.cache_dir
        self.cache_dir.mkdir(parents=True, exist_ok=True)

        # Discovery limit from graph builder config
        self.DISCOVERY_LIMIT = self.graph_config.max_discovered_nodes

        # Core orchestrator state
        self.heap = NodeHeap(max_heap=True)
        self.visited: Set[str] = set()
        self.node_evaluator = dspy.Predict(NodeSignature)
        self.discovery_evaluator = dspy.Predict(DiscoverySignature)
        self.discovered_nodes_count = 0
        self.node_assessments: Dict[str, NodeAssessment] = {}
        self.critical_path_markers: Dict[str, CriticalPathMarker] = {}

        # Token usage tracking
        self.token_tracker = TokenUsageTracker()
        self.token_tracker.set_model_pricing(settings.LLM_MODEL)

        # Execution trace for debugging
        self.execution_trace = ExecutionTrace(
            firm_id=firm.id,
            project_id=project.id,
            token_tracker=self.token_tracker
        )

        # Load discovery personas
        self.personas = DEFAULT_PERSONAS

    def _cache_key(self, node: Node, firm_id: str, project_id: str) -> str:
        """Generate cache key for a node evaluation."""
        key_str = f"{firm_id}:{project_id}:{node.id}:{node.name}:{node.type.name}"
        return hashlib.sha256(key_str.encode()).hexdigest()

    def _load_from_cache(self, cache_key: str) -> Optional[NodeAssessment]:
        """Load cached assessment if available."""
        if not self.cache_enabled:
            return None

        cache_file = self.cache_dir / f"{cache_key}.json"
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

        cache_file = self.cache_dir / f"{cache_key}.json"
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

                # Parse result with config defaults
                importance = float(result.importance_score) if hasattr(result, "importance_score") else self.config.default_importance
                influence = float(result.influence_score) if hasattr(result, "influence_score") else self.config.default_influence
                reasoning = result.reasoning if hasattr(result, "reasoning") else "No reasoning provided"

                # Derived Risk Calculation
                derived_risk = importance * (1.0 - influence)

                # Track token usage
                self.token_tracker.add_node_eval(self.config.tokens_per_eval)

                assessment = NodeAssessment(
                    node_id=node.id,
                    node_name=node.name,
                    importance_score=max(0.0, min(1.0, importance)),
                    influence_score=max(0.0, min(1.0, influence)),
                    risk_level=max(0.0, min(1.0, derived_risk)),
                    reasoning=reasoning,
                    is_on_critical_path=self.critical_path_markers.get(node.id, CriticalPathMarker(
                        node_id=node.id, is_critical=False
                    )).is_critical,
                )

                # TRIGGER RECURSIVE DISCOVERY
                if self.discovered_nodes_count < self.DISCOVERY_LIMIT:
                    await self._discover_and_inject_nodes(node, node_requirements)

                # Save to cache
                self._save_to_cache(cache_key, assessment)

                return assessment

            except Exception as e:
                wait_time = self.config.backoff_base ** attempt
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
                    # Use default scores on failure
                    return NodeAssessment(
                        node_id=node.id,
                        node_name=node.name,
                        importance_score=self.config.default_importance,
                        influence_score=self.config.default_influence,
                        risk_level=self.config.default_importance * (1.0 - self.config.default_influence),
                        reasoning=f"Failed after {self.max_retries} retries: {str(e)}",
                        is_on_critical_path=False
                    )

    async def _discover_and_inject_nodes(self, node: Node, requirements: str):
        """Generatively discover hidden infrastructure dependencies using configured personas."""
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

        # Build context of existing graph to avoid duplicates
        existing_nodes = ", ".join([n.name for n in self.graph.nodes])

        async def _run_persona_discovery(persona_name: str):
            """Internal helper to run DSPy in a thread."""
            try:
                discovery = await asyncio.to_thread(
                    self.discovery_evaluator,
                    node_requirements=requirements,
                    existing_graph_context=existing_nodes,
                    persona=persona_name,
                    valid_types=valid_types
                )
                return persona_name, discovery
            except Exception as e:
                logger.warning("discovery_failed", node_id=node.id, persona=persona_name, error=str(e))
                return persona_name, None

        # Run all persona discoveries in parallel
        persona_names = [p.name for p in self.personas]
        tasks = [_run_persona_discovery(p) for p in persona_names]
        results = await asyncio.gather(*tasks)

        for persona_name, discovery in results:
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
                        persona=persona_name,
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
                        description=f"[{persona_name}] {desc}"
                    )
                )

                # Inject into graph with configured weight
                self.graph.add_node(new_node)
                self.graph.add_edge(
                    node, new_node,
                    weight=self.graph_config.discovered_edge_weight,
                    relationship=f"discovered by {persona_name}",
                    validate=False
                )

                # Link to exit node for path density
                exit_nodes = [n for n in self.graph.nodes if n.id == self.project.success_criteria.exit_node_id]
                if exit_nodes:
                    self.graph.add_edge(
                        new_node, exit_nodes[0],
                        weight=self.graph_config.infrastructure_weight,
                        relationship="infrastructure sustainment",
                        validate=False
                    )

                self.discovered_nodes_count += 1
                logger.info(
                    "new_node_discovered",
                    persona=persona_name,
                    parent=node.id,
                    new_node=new_node.name,
                    total=self.discovered_nodes_count
                )

            # Track token usage for discovery
            self.token_tracker.add_discovery(self.config.tokens_per_discovery)

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
        # Initialize execution trace
        self.execution_trace.budget_allocated = budget
        self.execution_trace.start_phase(ExecutionPhase.INIT)

        logger.info(
            "analysis_started_v2",
            firm=self.firm.name,
            project=self.project.name,
            budget=budget,
        )

        try:
            # Step 1: Get entry/exit nodes
            self.execution_trace.start_phase(ExecutionPhase.GRAPH_BUILD)
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

            self.execution_trace.complete_phase(ExecutionPhase.GRAPH_BUILD)

            # Step 2: Initialize heap and visited
            self.heap.push(entry_node, priority=1.0)

            # Step 3: Progressive traversal within budget
            self.execution_trace.start_phase(ExecutionPhase.NODE_EVALUATION)
            while not self.heap.is_empty() and budget > 0:
                node = self.heap.pop()
                if node.id in self.visited:
                    continue

                self.visited.add(node.id)
                assessment = await self._evaluate_node_with_retry(node)
                self.node_assessments[node.id] = assessment

                # Update execution trace
                self.execution_trace.budget_used += 1

                # Children of unmanaged importance get priority
                priority = assessment.risk_level
                for child in self.graph.get_children(node):
                    if child.id not in self.visited:
                        self.heap.push(child, priority=priority)

                budget -= 1

            self.execution_trace.complete_phase(ExecutionPhase.NODE_EVALUATION)

            # Step 4: Ensure ALL nodes are present in output (with config defaults)
            for node in self.graph.nodes:
                if node.id not in self.node_assessments:
                    self.node_assessments[node.id] = NodeAssessment(
                        node_id=node.id,
                        node_name=node.name,
                        importance_score=self.config.default_importance,
                        influence_score=self.config.default_influence,
                        risk_level=self.config.default_importance * (1.0 - self.config.default_influence),
                        reasoning="Node not reached within analysis budget.",
                        is_on_critical_path=False
                    )

            # Step 5: Detect ALL critical chains
            self.execution_trace.start_phase(ExecutionPhase.CHAIN_DETECTION)
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

                # Update critical path markers
                for chain_data in all_chains_output:
                    chain_id = f"chain_{hash(tuple(chain_data.node_ids))}"
                    for node_id in chain_data.node_ids:
                        if node_id not in self.critical_path_markers:
                            self.critical_path_markers[node_id] = CriticalPathMarker(
                                node_id=node_id,
                                is_critical=True
                            )
                        self.critical_path_markers[node_id].add_chain(chain_id)

            except ValueError:
                all_chains_output = []

            self.execution_trace.complete_phase(ExecutionPhase.CHAIN_DETECTION)

            # Step 6: Matrix classification
            self.execution_trace.start_phase(ExecutionPhase.MATRIX_CLASSIFICATION)
            node_names = {n.id: n.name for n in self.graph.nodes}
            matrix_classifications = classify_all_nodes(
                self.node_assessments,
                node_names,
                influence_threshold=self.matrix_config.influence_threshold,
                importance_threshold=self.matrix_config.importance_threshold,
            )
            self.execution_trace.complete_phase(ExecutionPhase.MATRIX_CLASSIFICATION)

            # Step 7: Final Bid Recommendation
            self.execution_trace.start_phase(ExecutionPhase.RECOMMENDATION)
            primary_chain = all_chains_output[0].node_ids if all_chains_output else []
            should_bid_result = should_bid(matrix_classifications, primary_chain)

            critical_deps = len(matrix_classifications.get(RiskQuadrant.TYPE_C, []))

            recommendation = BidRecommendation(
                should_bid=should_bid_result,
                confidence=0.9 if self.execution_trace.budget_remaining > 0 else 0.6,
                reasoning=self._generate_bid_reasoning(
                    should_bid_result, critical_deps, all_chains_output
                ),
                key_risks=self._extract_key_risks(matrix_classifications),
                key_opportunities=self._extract_key_opportunities(matrix_classifications),
            )
            self.execution_trace.complete_phase(ExecutionPhase.RECOMMENDATION)

            # Step 8: Summary metrics
            critical_failure_likelihood = all_chains_output[0].cumulative_risk if all_chains_output else 0.5

            summary = SummaryMetrics(
                aggregate_project_score=1.0 - critical_failure_likelihood,
                total_token_cost=self.token_tracker.total_tokens,
                critical_failure_likelihood=critical_failure_likelihood,
                nodes_evaluated=len(self.visited),
                total_nodes=len(self.graph.nodes),
                critical_dependency_count=critical_deps,
            )

            traversal_status = TraversalStatus.COMPLETE if self.execution_trace.budget_remaining > 0 else TraversalStatus.INCOMPLETE

            # Mark execution complete
            self.execution_trace.complete_execution()

            # Log execution summary
            exec_summary = self.execution_trace.get_summary()
            logger.info("analysis_complete_v2", **exec_summary)

            # Build enhanced output sections for MATLAB/Monte Carlo
            logger.info("building_enhanced_output_sections")
            enhanced_builder = self._build_enhanced_sections(
                matrix_classifications,
                all_chains_output
            )

            return AnalysisOutput(
                firm=self.firm,
                project=self.project,
                traversal_status=traversal_status,
                node_assessments=self.node_assessments,
                all_chains=all_chains_output,
                matrix_classifications=matrix_classifications,
                summary=summary,
                recommendation=recommendation,
                # Enhanced sections
                **enhanced_builder
            )

        except Exception as e:
            self.execution_trace.fail_phase(self.execution_trace.current_phase, str(e))
            logger.error("analysis_failed_v2", error=str(e), trace=self.execution_trace.get_summary())
            raise

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

    def _build_enhanced_sections(
        self,
        matrix_classifications: Dict,
        all_chains: List
    ) -> Dict:
        """Build all enhanced output sections for MATLAB integration."""
        from src.services.enhanced_output_builder import EnhancedOutputBuilder

        try:
            builder = EnhancedOutputBuilder(self.graph)

            # Get critical path nodes
            critical_path_nodes = set()
            if all_chains:
                critical_path_nodes = set(all_chains[0].node_ids)

            # Get discovered nodes (placeholder - track this in graph builder)
            discovered_nodes = set()

            # Build all enhanced sections
            enhanced = {}

            # 1. Graph Topology
            try:
                enhanced['graph_topology'] = builder.build_graph_topology(
                    critical_path_nodes=critical_path_nodes,
                    discovered_nodes=discovered_nodes
                )
            except Exception as e:
                logger.warning(f"Failed to build graph topology: {e}")
                enhanced['graph_topology'] = None

            # 2. Risk Distributions
            try:
                enhanced['risk_distributions'] = builder.build_risk_distributions(
                    node_assessments=self.node_assessments,
                    propagated_risks=None  # TODO: track propagated risks
                )
            except Exception as e:
                logger.warning(f"Failed to build risk distributions: {e}")
                enhanced['risk_distributions'] = None

            # 3. Propagation Trace
            try:
                enhanced['propagation_trace'] = builder.build_propagation_trace(
                    node_assessments=self.node_assessments,
                    propagated_risks={}  # TODO: track propagated risks
                )
            except Exception as e:
                logger.warning(f"Failed to build propagation trace: {e}")
                enhanced['propagation_trace'] = None

            # 4. Discovery Metadata (placeholder - track during graph building)
            enhanced['discovery_metadata'] = None

            # 5. Evaluation Metadata (placeholder - track during evaluation)
            enhanced['evaluation_metadata'] = None

            # 6. Configuration Snapshot
            try:
                enhanced['configuration_snapshot'] = builder.build_configuration_snapshot()
            except Exception as e:
                logger.warning(f"Failed to build config snapshot: {e}")
                enhanced['configuration_snapshot'] = None

            # 7. Graph Statistics
            try:
                enhanced['graph_statistics'] = builder.build_graph_statistics(
                    critical_path_nodes=critical_path_nodes
                )
            except Exception as e:
                logger.warning(f"Failed to build graph statistics: {e}")
                enhanced['graph_statistics'] = None

            # 8. Monte Carlo Parameters
            try:
                if enhanced.get('risk_distributions'):
                    enhanced['monte_carlo_parameters'] = builder.build_monte_carlo_parameters(
                        risk_distributions=enhanced['risk_distributions']
                    )
                else:
                    enhanced['monte_carlo_parameters'] = None
            except Exception as e:
                logger.warning(f"Failed to build Monte Carlo parameters: {e}")
                enhanced['monte_carlo_parameters'] = None

            logger.info("enhanced_sections_built",
                       sections_populated=sum(1 for v in enhanced.values() if v is not None))

            return enhanced

        except Exception as e:
            logger.error(f"Failed to build enhanced sections: {e}")
            # Return empty enhanced sections if builder fails
            return {
                'graph_topology': None,
                'risk_distributions': None,
                'propagation_trace': None,
                'discovery_metadata': None,
                'evaluation_metadata': None,
                'configuration_snapshot': None,
                'graph_statistics': None,
                'monte_carlo_parameters': None
            }
