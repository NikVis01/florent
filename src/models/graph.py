from pydantic import BaseModel, model_validator, Field
from typing import List, Dict, Set
import logging

from src.models.base import OperationType

# Set up logging
logger = logging.getLogger(__name__)

# Node class
# A single point in the graph representing a specific operation or requirement node.
class Node(BaseModel):
    id: str
    name: str
    type: OperationType
    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")

    def __hash__(self):
        return hash(self.id)

    def __eq__(self, other):
        if not isinstance(other, Node):
            return False
        return self.id == other.id

# A directed connection between two nodes with an associated weight and relationship type.
class Edge(BaseModel):
    source: Node # ptr to node
    target: Node # ptr to node
    weight: float # Essentially Importance to the operation (e.g., cross-encoded similarity)
    relationship: str # e.g., "leads to", "is a prerequisite for", "is a component of"

# A collection of nodes and edges forming a Directed Acyclic Graph (DAG) for business logic.
class Graph(BaseModel):
    nodes: List[Node] = Field(default_factory=list)
    edges: List[Edge] = Field(default_factory=list)

    @model_validator(mode='after')
    def validate_graph(self) -> 'Graph':
        # 1. Existence Check: Ensure all edges reference nodes present in the nodes list
        node_ids = {node.id for node in self.nodes}
        for edge in self.edges:
            if edge.source.id not in node_ids:
                raise ValueError(f"Source node {edge.source.id} in edge not found in graph nodes.")
            if edge.target.id not in node_ids:
                raise ValueError(f"Target node {edge.target.id} in edge not found in graph nodes.")

        # 2. Cycle Detection (DAG Check)
        if self._has_cycle():
            raise ValueError("The graph contains a cycle; it must be a Directed Acyclic Graph (DAG).")
        
        return self

    def _has_cycle(self) -> bool:
        """
        Detects if the graph has a cycle using an iterative DFS approach.
        """
        adj = self._build_adjacency_list()
        
        visited: Set[str] = set()
        rec_stack: Set[str] = set()
        
        for node_id in adj:
            if node_id not in visited:
                # Stack contains (current_node, iterator_over_neighbors)
                stack = [(node_id, iter(adj[node_id]))]
                visited.add(node_id)
                rec_stack.add(node_id)
                
                while stack:
                    curr, neighbors = stack[-1]
                    try:
                        neighbor = next(neighbors)
                        if neighbor in rec_stack:
                            return True
                        if neighbor not in visited:
                            visited.add(neighbor)
                            rec_stack.add(neighbor)
                            stack.append((neighbor, iter(adj[neighbor])))
                    except StopIteration:
                        rec_stack.remove(curr)
                        stack.pop()
        return False

    def _build_adjacency_list(self) -> Dict[str, Set[str]]:
        adj = {node.id: set() for node in self.nodes}
        for edge in self.edges:
            adj[edge.source.id].add(edge.target.id)
        return adj

    def add_node(self, node: Node):
        if any(n.id == node.id for n in self.nodes):
            logger.warning(f"Node with id {node.id} already exists.")
            return
        self.nodes.append(node)

    def add_edge(self, source: Node, target: Node, weight: float, relationship: str = "connected to", validate: bool = True):
        """
        Add an edge to the graph.

        Args:
            source: Source node
            target: Target node
            weight: Edge weight
            relationship: Description of the relationship
            validate: Whether to validate DAG property after adding (default: True)
        """
        edge = Edge(source=source, target=target, weight=weight, relationship=relationship)
        self.edges.append(edge)
        # Re-validate after adding edge to ensure it remains a DAG
        if validate:
            self.validate_graph()

    def get_entry_nodes(self) -> List[Node]:
        """Returns nodes with in-degree 0 (no incoming edges)."""
        if not self.nodes:
            raise ValueError("Graph has no nodes")
        targets = {e.target.id for e in self.edges}
        entry_nodes = [n for n in self.nodes if n.id not in targets]
        if not entry_nodes:
            raise ValueError("Graph has no entry points")
        return entry_nodes

    def get_exit_nodes(self) -> List[Node]:
        """Returns nodes with out-degree 0 (no outgoing edges)."""
        if not self.nodes:
            raise ValueError("Graph has no nodes")
        sources = {e.source.id for e in self.edges}
        exit_nodes = [n for n in self.nodes if n.id not in sources]
        if not exit_nodes:
            raise ValueError("Graph has no exit points")
        return exit_nodes

    def get_parents(self, node: Node) -> List[Node]:
        """Returns all nodes with edges pointing to this node."""
        return [e.source for e in self.edges if e.target.id == node.id]

    def get_children(self, node: Node) -> List[Node]:
        """Returns all nodes this node points to."""
        return [e.target for e in self.edges if e.source.id == node.id]

    def get_distance(self, source: Node, target: Node) -> int:
        """BFS to find shortest path distance."""
        if source.id == target.id:
            return 0
        from collections import deque
        queue = deque([(source, 0)])
        visited = {source.id}
        while queue:
            current, dist = queue.popleft()
            for child in self.get_children(current):
                if child.id == target.id:
                    return dist + 1
                if child.id not in visited:
                    visited.add(child.id)
                    queue.append((child, dist + 1))
        raise ValueError(f"No path from {source.id} to {target.id}")
