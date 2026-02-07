import heapq
from typing import List, Tuple
from src.models.graph import Node

class NodeStack:
    """
    Standard LIFO Stack for Depth-First exploration.
    Used for 'Blast Radius' analysis where we push parents of a flagged node
    to re-evaluate upstream impact.
    """
    def __init__(self):
        self._items: List[Node] = []

    def push(self, node: Node):
        self._items.append(node)

    def pop(self) -> Node:
        if self.is_empty():
            raise IndexError("pop from empty stack")
        return self._items.pop()

    def peek(self) -> Node:
        if self.is_empty():
            raise IndexError("peek from empty stack")
        return self._items[-1]

    def is_empty(self) -> bool:
        return len(self._items) == 0

    def __len__(self) -> int:
        return len(self._items)

class NodeHeap:
    """
    Priority Queue (Min-Heap/Max-Heap) for prioritized exploration.
    Used for the main loop to spend 'token budget' on critical nodes first.
    Nodes are stored as (priority, node_id, node_object).
    
    NOTE: Python's heapq is a min-heap. For a max-priority queue (highest score first),
    negate the priority values.
    """
    def __init__(self, max_heap: bool = True):
        self._heap: List[Tuple[float, str, Node]] = []
        self.max_heap = max_heap

    def push(self, node: Node, priority: float):
        # We include node.id in the tuple to handle cases where priority values are equal,
        # ensuring we don't try to compare Node objects directly if they don't support it.
        val = -priority if self.max_heap else priority
        heapq.heappush(self._heap, (val, node.id, node))

    def pop(self) -> Node:
        if self.is_empty():
            raise IndexError("pop from empty heap")
        _, _, node = heapq.heappop(self._heap)
        return node

    def is_empty(self) -> bool:
        return len(self._heap) == 0

    def __len__(self) -> int:
        return len(self._heap)
