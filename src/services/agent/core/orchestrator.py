from typing import Set, Dict
from src.models.graph import Graph, Node
from src.services.agent.core.traversal import NodeStack, NodeHeap
from src.services.agent.models.signatures import NodeSignature
import dspy

class NodeAssessment:
    def __init__(self, influence_score: float, risk_level: float, reasoning: str):
        self.influence_score = influence_score
        self.risk_level = risk_level
        self.reasoning = reasoning

class AgentOrchestrator:
    """
    Manual control loop for the Florent agent service.
    Implements the 'No-LangChain' philosophy by manually managing
    Stack (for DFS/Blast Radius) and Heap (for priority exploration).
    """
    def __init__(self, graph: Graph):
        self.graph = graph
        self.stack = NodeStack()
        self.heap = NodeHeap(max_heap=True)
        self.visited: Set[str] = set()
        self.evaluator = dspy.Predict(NodeSignature)

    def run_exploration(self, budget: int) -> Dict[str, NodeAssessment]:
        """
        Main exploration loop. Spends 'budget' tokens on the most critical nodes.
        Uses the Heap to prioritize nodes.
        """
        print(f"Starting prioritized exploration with budget: {budget}")

        # Initialize heap with entry nodes
        for node in self.graph.get_entry_nodes():
            self.heap.push(node, priority=1.0)

        node_assessments = {}

        while not self.heap.is_empty() and budget > 0:
            node = self.heap.pop()
            if node.id in self.visited:
                continue

            self.visited.add(node.id)
            print(f"Processing node: {node.name} (Budget remaining: {budget})")

            # Evaluate node
            assessment = self._evaluate_node(node)
            node_assessments[node.id] = assessment

            # Push children with priorities
            for child in self.graph.get_children(node):
                if child.id not in self.visited:
                    priority = assessment.influence_score * assessment.risk_level
                    self.heap.push(child, priority=priority)

            budget -= 1

        return node_assessments

    def _evaluate_node(self, node: Node) -> NodeAssessment:
        """Evaluate single node using DSPy."""
        try:
            result = self.evaluator(
                firm_context=f"Node: {node.name}, Type: {node.type}",
                node_requirements=f"Evaluating node {node.id}"
            )
            influence = float(result.influence_score) if hasattr(result, 'influence_score') else 0.5
            risk = float(result.risk_assessment) if hasattr(result, 'risk_assessment') else 0.5
            reasoning = result.reasoning if hasattr(result, 'reasoning') else "No reasoning provided"
            return NodeAssessment(influence, risk, reasoning)
        except Exception as e:
            print(f"Error evaluating node {node.id}: {e}")
            return NodeAssessment(0.5, 0.5, f"Error: {str(e)}")

    def evaluate_blast_radius(self, flagged_node: Node):
        """
        Uses the Stack to re-evaluate upstream 'Blast Radius' when a node is flagged.
        """
        print(f"Evaluating blast radius for flagged node: {flagged_node.name}")
        self.stack.push(flagged_node)

        while not self.stack.is_empty():
            node = self.stack.pop()
            print(f"Re-evaluating upstream dependencies for: {node.name}")

            parents = self.graph.get_parents(node)
            for parent in parents:
                self.stack.push(parent)
