### Agentic tool for hybrid, deterministic, and agentic graph traversal

from typing import List, Set
from src.models.graph import Graph, Node

class Traversal:
    def __init__(self, graph: Graph):
        self.graph = graph

    def get_neighbors(self, node: Node) -> List[Node]:
        """Returns the list of nodes that the given node points to."""
        return [edge.target for edge in self.graph.edges if edge.source.id == node.id]

    def _traverse(self, start_node: Node):
        # General traversal method, can choose between DFS and BFS
        visited = set()
        stack = [start_node]
        while stack:
            node = stack.pop()
            if node.id not in visited:
                visited.add(node.id)
                for neighbor in self.get_neighbors(node):
                    stack.append(neighbor)
        return visited

    def find_chain(self, start_node: Node, end_node: Node):
        # Finds markov chains in the graph
        visited = set()
        stack = [start_node]
        while stack:
            node = stack.pop()
            if node.id not in visited:
                visited.add(node.id)
                if node.id == end_node.id:
                    break
                for neighbor in self.get_neighbors(node):
                    stack.append(neighbor)
        return visited

    def find_path(self, start_node: Node, end_node: Node):
        # Finds paths in the graph
        visited = set()
        stack = [start_node]
        while stack:
            node = stack.pop()
            if node.id not in visited:
                visited.add(node.id)
                if node.id == end_node.id:
                    break
                for neighbor in self.get_neighbors(node):
                    stack.append(neighbor)
        return visited