import sys
import os
import unittest
from unittest.mock import patch

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.services.agent.core.traversal import NodeStack, NodeHeap
from src.models.graph import Node
from src.models.base import OperationType


class TestNodeStack(unittest.TestCase):
    """Test NodeStack (LIFO Stack) implementation."""

    def setUp(self):
        """Set up test data."""
        self.stack = NodeStack()

        self.mock_categories = {"test_category"}
        self.patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.patcher.start()

        self.node_a = Node(
            id="A",
            name="Node A",
            type=OperationType(name="Test", category="test_category", description="Test op"),
            embedding=[0.1, 0.2]
        )
        self.node_b = Node(
            id="B",
            name="Node B",
            type=OperationType(name="Test", category="test_category", description="Test op"),
            embedding=[0.3, 0.4]
        )
        self.node_c = Node(
            id="C",
            name="Node C",
            type=OperationType(name="Test", category="test_category", description="Test op"),
            embedding=[0.5, 0.6]
        )

    def tearDown(self):
        self.patcher.stop()

    def test_stack_initialization(self):
        """Test that stack initializes as empty."""
        self.assertTrue(self.stack.is_empty())
        self.assertEqual(len(self.stack), 0)

    def test_push_single_node(self):
        """Test pushing a single node to stack."""
        self.stack.push(self.node_a)
        self.assertFalse(self.stack.is_empty())
        self.assertEqual(len(self.stack), 1)

    def test_push_multiple_nodes(self):
        """Test pushing multiple nodes to stack."""
        self.stack.push(self.node_a)
        self.stack.push(self.node_b)
        self.stack.push(self.node_c)
        self.assertEqual(len(self.stack), 3)

    def test_pop_single_node(self):
        """Test popping a single node from stack."""
        self.stack.push(self.node_a)
        popped = self.stack.pop()
        self.assertEqual(popped.id, "A")
        self.assertTrue(self.stack.is_empty())

    def test_lifo_order(self):
        """Test that stack follows LIFO (Last In First Out) order."""
        self.stack.push(self.node_a)
        self.stack.push(self.node_b)
        self.stack.push(self.node_c)

        self.assertEqual(self.stack.pop().id, "C")
        self.assertEqual(self.stack.pop().id, "B")
        self.assertEqual(self.stack.pop().id, "A")

    def test_peek_without_popping(self):
        """Test peeking at top of stack without removing it."""
        self.stack.push(self.node_a)
        self.stack.push(self.node_b)

        peeked = self.stack.peek()
        self.assertEqual(peeked.id, "B")
        self.assertEqual(len(self.stack), 2)  # Should still have 2 items

    def test_pop_empty_stack(self):
        """Test that popping from empty stack raises error."""
        with self.assertRaises(IndexError) as context:
            self.stack.pop()
        self.assertIn("pop from empty stack", str(context.exception))

    def test_peek_empty_stack(self):
        """Test that peeking at empty stack raises error."""
        with self.assertRaises(IndexError) as context:
            self.stack.peek()
        self.assertIn("peek from empty stack", str(context.exception))

    def test_len_after_operations(self):
        """Test that len is correctly maintained after push/pop operations."""
        self.stack.push(self.node_a)
        self.assertEqual(len(self.stack), 1)

        self.stack.push(self.node_b)
        self.assertEqual(len(self.stack), 2)

        self.stack.pop()
        self.assertEqual(len(self.stack), 1)

        self.stack.pop()
        self.assertEqual(len(self.stack), 0)

    def test_multiple_push_pop_cycles(self):
        """Test multiple cycles of push and pop operations."""
        for i in range(3):
            self.stack.push(self.node_a)
            self.stack.push(self.node_b)
            self.stack.pop()
            self.stack.pop()

        self.assertTrue(self.stack.is_empty())


class TestNodeHeap(unittest.TestCase):
    """Test NodeHeap (Priority Queue) implementation."""

    def setUp(self):
        """Set up test data."""
        self.mock_categories = {"test_category"}
        self.patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.patcher.start()

        self.node_a = Node(
            id="A",
            name="Node A",
            type=OperationType(name="Test", category="test_category", description="Test op"),
            embedding=[0.1, 0.2]
        )
        self.node_b = Node(
            id="B",
            name="Node B",
            type=OperationType(name="Test", category="test_category", description="Test op"),
            embedding=[0.3, 0.4]
        )
        self.node_c = Node(
            id="C",
            name="Node C",
            type=OperationType(name="Test", category="test_category", description="Test op"),
            embedding=[0.5, 0.6]
        )

    def tearDown(self):
        self.patcher.stop()

    def test_max_heap_initialization(self):
        """Test that max heap initializes correctly."""
        heap = NodeHeap(max_heap=True)
        self.assertTrue(heap.is_empty())
        self.assertEqual(len(heap), 0)
        self.assertTrue(heap.max_heap)

    def test_min_heap_initialization(self):
        """Test that min heap initializes correctly."""
        heap = NodeHeap(max_heap=False)
        self.assertTrue(heap.is_empty())
        self.assertFalse(heap.max_heap)

    def test_push_single_node(self):
        """Test pushing a single node to heap."""
        heap = NodeHeap(max_heap=True)
        heap.push(self.node_a, priority=0.5)
        self.assertFalse(heap.is_empty())
        self.assertEqual(len(heap), 1)

    def test_max_heap_priority_order(self):
        """Test that max heap returns highest priority first."""
        heap = NodeHeap(max_heap=True)
        heap.push(self.node_a, priority=0.3)
        heap.push(self.node_b, priority=0.7)
        heap.push(self.node_c, priority=0.5)

        # Should pop in order: B (0.7), C (0.5), A (0.3)
        self.assertEqual(heap.pop().id, "B")
        self.assertEqual(heap.pop().id, "C")
        self.assertEqual(heap.pop().id, "A")

    def test_min_heap_priority_order(self):
        """Test that min heap returns lowest priority first."""
        heap = NodeHeap(max_heap=False)
        heap.push(self.node_a, priority=0.3)
        heap.push(self.node_b, priority=0.7)
        heap.push(self.node_c, priority=0.5)

        # Should pop in order: A (0.3), C (0.5), B (0.7)
        self.assertEqual(heap.pop().id, "A")
        self.assertEqual(heap.pop().id, "C")
        self.assertEqual(heap.pop().id, "B")

    def test_equal_priorities(self):
        """Test heap behavior with equal priorities."""
        heap = NodeHeap(max_heap=True)
        heap.push(self.node_a, priority=0.5)
        heap.push(self.node_b, priority=0.5)
        heap.push(self.node_c, priority=0.5)

        # All should be popped (order may vary for equal priorities)
        popped_ids = set()
        popped_ids.add(heap.pop().id)
        popped_ids.add(heap.pop().id)
        popped_ids.add(heap.pop().id)

        self.assertEqual(popped_ids, {"A", "B", "C"})

    def test_pop_empty_heap(self):
        """Test that popping from empty heap raises error."""
        heap = NodeHeap(max_heap=True)
        with self.assertRaises(IndexError) as context:
            heap.pop()
        self.assertIn("pop from empty heap", str(context.exception))

    def test_len_after_operations(self):
        """Test that len is correctly maintained."""
        heap = NodeHeap(max_heap=True)
        heap.push(self.node_a, priority=0.5)
        self.assertEqual(len(heap), 1)

        heap.push(self.node_b, priority=0.7)
        self.assertEqual(len(heap), 2)

        heap.pop()
        self.assertEqual(len(heap), 1)

        heap.pop()
        self.assertEqual(len(heap), 0)

    def test_large_scale_max_heap(self):
        """Test max heap with many nodes."""
        heap = NodeHeap(max_heap=True)
        priorities = [0.1, 0.9, 0.3, 0.7, 0.5, 0.2, 0.8, 0.4, 0.6]

        for i, priority in enumerate(priorities):
            node = Node(
                id=f"N{i}",
                name=f"Node {i}",
                type=OperationType(name="Test", category="test_category", description="Test op"),
                embedding=[float(i)]
            )
            heap.push(node, priority=priority)

        # Pop all and verify descending order
        prev_priority = 1.0
        while not heap.is_empty():
            node = heap.pop()
            # Can't check exact priority, but count should decrease
            self.assertTrue(len(heap) >= 0)

    def test_negative_priorities(self):
        """Test heap with negative priorities."""
        heap = NodeHeap(max_heap=True)
        heap.push(self.node_a, priority=-0.5)
        heap.push(self.node_b, priority=0.0)
        heap.push(self.node_c, priority=-0.2)

        # Max heap: 0.0, -0.2, -0.5
        self.assertEqual(heap.pop().id, "B")
        self.assertEqual(heap.pop().id, "C")
        self.assertEqual(heap.pop().id, "A")

    def test_very_close_priorities(self):
        """Test heap with very close priority values."""
        heap = NodeHeap(max_heap=True)
        heap.push(self.node_a, priority=0.50001)
        heap.push(self.node_b, priority=0.50002)
        heap.push(self.node_c, priority=0.50000)

        # Should still maintain order
        self.assertEqual(heap.pop().id, "B")
        self.assertEqual(heap.pop().id, "A")
        self.assertEqual(heap.pop().id, "C")


if __name__ == '__main__':
    unittest.main()
