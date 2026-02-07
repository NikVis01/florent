import sys
import os
import unittest
from unittest.mock import patch, MagicMock
from io import StringIO

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.services.agent.core.orchestrator import AgentOrchestrator
from src.models.graph import Graph, Node, Edge
from src.models.base import OperationType


class TestAgentOrchestrator(unittest.TestCase):
    """Test AgentOrchestrator for graph exploration."""

    def setUp(self):
        """Set up test data."""
        self.mock_categories = {"test_category"}
        self.patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.patcher.start()

        # Mock the DSPy evaluator to avoid "No LM loaded" errors
        self.mock_eval = patch.object(AgentOrchestrator, '_evaluate_node', 
                                     return_value=MagicMock(influence_score=0.5, risk_level=0.5, reasoning="Mocked"))
        self.mock_eval.start()

        # Create test nodes
        self.op_type = OperationType(name="Test", category="test_category", description="Test op")
        self.node_a = Node(id="A", name="Node A", type=self.op_type, embedding=[0.1, 0.2])
        self.node_b = Node(id="B", name="Node B", type=self.op_type, embedding=[0.3, 0.4])
        self.node_c = Node(id="C", name="Node C", type=self.op_type, embedding=[0.5, 0.6])

        # Create test graph
        self.graph = Graph(
            nodes=[self.node_a, self.node_b, self.node_c],
            edges=[
                Edge(source=self.node_a, target=self.node_b, weight=0.5, relationship="leads to"),
                Edge(source=self.node_b, target=self.node_c, weight=0.8, relationship="prerequisite")
            ]
        )

    def tearDown(self):
        self.patcher.stop()
        self.mock_eval.stop()

    def test_orchestrator_initialization(self):
        """Test that orchestrator initializes correctly."""
        orchestrator = AgentOrchestrator(self.graph)
        self.assertEqual(orchestrator.graph, self.graph)
        self.assertTrue(orchestrator.stack.is_empty())
        self.assertTrue(orchestrator.heap.is_empty())
        self.assertEqual(len(orchestrator.visited), 0)

    def test_orchestrator_has_correct_structures(self):
        """Test that orchestrator has stack, heap, and visited set."""
        orchestrator = AgentOrchestrator(self.graph)
        self.assertIsNotNone(orchestrator.stack)
        self.assertIsNotNone(orchestrator.heap)
        self.assertIsNotNone(orchestrator.visited)

    @patch('sys.stdout', new_callable=StringIO)
    def test_run_exploration_with_zero_budget(self, mock_stdout):
        """Test exploration with zero budget."""
        orchestrator = AgentOrchestrator(self.graph)
        orchestrator.run_exploration(budget=0)

        output = mock_stdout.getvalue()
        self.assertIn("Starting prioritized exploration", output)

    @patch('sys.stdout', new_callable=StringIO)
    def test_run_exploration_with_empty_heap(self, mock_stdout):
        """Test exploration with empty heap (no entry points)."""
        orchestrator = AgentOrchestrator(self.graph)
        orchestrator.run_exploration(budget=5)

        output = mock_stdout.getvalue()
        self.assertIn("budget: 5", output)
        # Since heap is empty, it should complete immediately

    @patch('sys.stdout', new_callable=StringIO)
    def test_run_exploration_with_nodes(self, mock_stdout):
        """Test exploration with nodes in heap."""
        orchestrator = AgentOrchestrator(self.graph)

        # Manually add nodes to heap for testing
        orchestrator.heap.push(self.node_a, priority=1.0)
        orchestrator.heap.push(self.node_b, priority=0.8)

        orchestrator.run_exploration(budget=2)

        output = mock_stdout.getvalue()
        self.assertIn("Processing node", output)

    def test_run_exploration_decrements_budget(self):
        """Test that exploration decrements budget correctly."""
        orchestrator = AgentOrchestrator(self.graph)

        # Add nodes to heap
        orchestrator.heap.push(self.node_a, priority=1.0)
        orchestrator.heap.push(self.node_b, priority=0.8)
        orchestrator.heap.push(self.node_c, priority=0.6)

        initial_budget = 2
        orchestrator.run_exploration(budget=initial_budget)

        # Should have visited 2 nodes
        self.assertEqual(len(orchestrator.visited), 2)

    def test_run_exploration_respects_visited_nodes(self):
        """Test that exploration doesn't reprocess visited nodes."""
        orchestrator = AgentOrchestrator(self.graph)

        # The orchestrator automatically pushes entry nodes (Node A)
        # We manually push Node A again with lower priority
        orchestrator.heap.push(self.node_a, priority=0.9)

        # We want to isolate the 'visited' check, so we mock get_children to return nothing
        with patch.object(Graph, 'get_children', return_value=[]):
            orchestrator.run_exploration(budget=5)

        # Should only visit node_a once
        self.assertEqual(len(orchestrator.visited), 1)
        self.assertIn("A", orchestrator.visited)

    @patch('sys.stdout', new_callable=StringIO)
    def test_evaluate_blast_radius(self, mock_stdout):
        """Test blast radius evaluation."""
        orchestrator = AgentOrchestrator(self.graph)
        orchestrator.evaluate_blast_radius(self.node_b)

        output = mock_stdout.getvalue()
        self.assertIn("Evaluating blast radius for flagged node: Node B", output)
        self.assertIn("Re-evaluating upstream dependencies", output)

    @patch('sys.stdout', new_callable=StringIO)
    def test_evaluate_blast_radius_uses_stack(self, mock_stdout):
        """Test that blast radius evaluation uses stack."""
        orchestrator = AgentOrchestrator(self.graph)

        # Stack should be empty initially
        self.assertTrue(orchestrator.stack.is_empty())

        orchestrator.evaluate_blast_radius(self.node_a)

        # Should have processed at least one node
        output = mock_stdout.getvalue()
        self.assertIn("Re-evaluating", output)

    def test_multiple_explorations(self):
        """Test running multiple exploration cycles."""
        orchestrator = AgentOrchestrator(self.graph)

        # First exploration
        orchestrator.heap.push(self.node_a, priority=1.0)
        orchestrator.run_exploration(budget=1)
        first_visited_count = len(orchestrator.visited)

        # Second exploration
        orchestrator.heap.push(self.node_b, priority=1.0)
        orchestrator.run_exploration(budget=1)
        second_visited_count = len(orchestrator.visited)

        # Should have visited more nodes
        self.assertGreaterEqual(second_visited_count, first_visited_count)

    def test_orchestrator_with_complex_graph(self):
        """Test orchestrator with a larger graph."""
        # Create a larger graph
        nodes = [
            Node(id=f"N{i}", name=f"Node {i}", type=self.op_type, embedding=[float(i)])
            for i in range(10)
        ]
        edges = [
            Edge(source=nodes[i], target=nodes[i+1], weight=0.5, relationship="next")
            for i in range(9)
        ]
        large_graph = Graph(nodes=nodes, edges=edges)

        orchestrator = AgentOrchestrator(large_graph)
        self.assertEqual(len(orchestrator.graph.nodes), 10)
        self.assertEqual(len(orchestrator.graph.edges), 9)

    def test_orchestrator_state_persistence(self):
        """Test that orchestrator maintains state across operations."""
        orchestrator = AgentOrchestrator(self.graph)

        # Add node and run exploration
        orchestrator.heap.push(self.node_a, priority=1.0)
        orchestrator.run_exploration(budget=1)

        # Check state is maintained
        self.assertIn("A", orchestrator.visited)

        # Add another node
        orchestrator.heap.push(self.node_b, priority=1.0)
        orchestrator.run_exploration(budget=1)

        # Should have both nodes visited
        self.assertIn("A", orchestrator.visited)
        self.assertIn("B", orchestrator.visited)


if __name__ == '__main__':
    unittest.main()
