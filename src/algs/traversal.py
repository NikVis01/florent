### Agentic tool for hybrid, deterministic, and agentic graph traversal

class Traversal:
    def __init__(self, graph: Graph):
        self.graph = graph

    def _traverse(self, start_node: Node):
        # General traversal method, can choose between DFS and BFS
        visited = set()
        stack = [start_node]
        while stack:
            node = stack.pop()
            if node not in visited:
                visited.add(node)
                for neighbor in self.graph.get_neighbors(node):
                    stack.append(neighbor)
        return visited

    def find_chain(self, start_node: Node, end_node: Node):
        # Finds markov chains in the graph
        visited = set()
        stack = [start_node]
        while stack:
            node = stack.pop()
            if node not in visited:
                visited.add(node)
                for neighbor in self.graph.get_neighbors(node):
                    stack.append(neighbor)
        return visited

    def find_path(self, start_node: Node, end_node: Node):
        # Finds paths in the graph
        visited = set()
        stack = [start_node]
        while stack:
            node = stack.pop()
            if node not in visited:
                visited.add(node)
                for neighbor in self.graph.get_neighbors(node):
                    stack.append(neighbor)
        return visited

    