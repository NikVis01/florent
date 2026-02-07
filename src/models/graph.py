from pydantic import BaseModel

# Type of operations requirement or business need
# One of:
# - "transportation"
# - "financing"
# - "insurance"
# - "guarantee"
# - "recruitment"
# - "materials"
# - "equipment"
# - "other"
class OperationType(BaseModel):
    name: str
    category: Literal[
        "transportation",
        "financing",
        "insurance",
        "guarantee",
        "recruitment",
        "materials",
        "equipment",
        "other",
    ]
    description: str

# Node class
class Node(BaseModel):
    id: str
    name: str
    type: OperationType

    def __init__(self, id: str, name: str, type: OperationType):
        self.id = id
        self.name = name
        self.type = type
        
class Edge(BaseModel):
    source: Node # ptr to node
    target: Node # ptr to node
    weight: float # Essentially Importance to the operation

    def __init__(self, source: Node, target: Node, weight: float):
        self.source = source
        self.target = target
        self.weight = weight

class Graph(BaseModel):
    nodes: List[Node]
    edges: List[Edge]
