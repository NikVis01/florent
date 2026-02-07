import sys
import os
import unittest
from unittest.mock import patch
from pydantic import ValidationError

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.graph import Node, Edge, Graph
from src.models.base import OperationType

class TestGraphModels(unittest.TestCase):
    def setUp(self):
        # Mock the categories registry
        self.mock_categories = {"transportation"}
        self.patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.patcher.start()

        self.type_transport = OperationType(
            name="Trucking",
            category="transportation",
            description="LTL shipping"
        )
        self.node_a = Node(id="A", name="Node A", type=self.type_transport, embedding=[0.1, 0.2])
        self.node_b = Node(id="B", name="Node B", type=self.type_transport, embedding=[0.3, 0.4])
        self.node_c = Node(id="C", name="Node C", type=self.type_transport, embedding=[0.5, 0.6])

    def tearDown(self):
        self.patcher.stop()

    def test_valid_dag(self):
        graph = Graph(
            nodes=[self.node_a, self.node_b, self.node_c],
            edges=[
                Edge(source=self.node_a, target=self.node_b, weight=0.5, relationship="leads to"),
                Edge(source=self.node_b, target=self.node_c, weight=0.8, relationship="prerequisite")
            ]
        )
        self.assertEqual(len(graph.nodes), 3)
        self.assertEqual(len(graph.edges), 2)

    def test_cycle_detection(self):
        with self.assertRaisesRegex(ValidationError, "The graph contains a cycle"):
            Graph(
                nodes=[self.node_a, self.node_b, self.node_c],
                edges=[
                    Edge(source=self.node_a, target=self.node_b, weight=0.5, relationship="x"),
                    Edge(source=self.node_b, target=self.node_c, weight=0.8, relationship="y"),
                    Edge(source=self.node_c, target=self.node_a, weight=0.9, relationship="z")  # Cycle
                ]
            )

    def test_node_existence_validation(self):
        node_external = Node(id="External", name="External", type=self.type_transport, embedding=[0.0, 0.0])
        with self.assertRaisesRegex(ValidationError, "not found in graph nodes"):
            Graph(
                nodes=[self.node_a, self.node_b],
                edges=[
                    Edge(source=self.node_a, target=node_external, weight=0.5, relationship="invalid")
                ]
            )

    def test_add_edge_dynamic_dag_check(self):
        graph = Graph(nodes=[self.node_a, self.node_b, self.node_c])
        graph.add_edge(self.node_a, self.node_b, 0.5, "step 1")
        graph.add_edge(self.node_b, self.node_c, 0.8, "step 2")
        
        with self.assertRaisesRegex(ValueError, "The graph contains a cycle"):
            graph.add_edge(self.node_c, self.node_a, 0.9, "loop")

    def test_fairly_large_graph(self):
        # Create 100 nodes and 99 edges in a line
        nodes = [
            Node(id=f"N{i}", name=f"Node {i}", type=self.type_transport, embedding=[float(i)])
            for i in range(100)
        ]
        edges = [
            Edge(source=nodes[i], target=nodes[i+1], weight=1.0, relationship="next")
            for i in range(99)
        ]
        graph = Graph(nodes=nodes, edges=edges)
        self.assertEqual(len(graph.nodes), 100)
        self.assertEqual(len(graph.edges), 99)

if __name__ == '__main__':
    unittest.main()
