import dspy

class NodeSignature(dspy.Signature):
    """
    Base signature for node analysis.
    Takes a firm's capability context and a node's requirement context,
    and returns a structured assessment of influence and importance.
    """
    firm_context = dspy.InputField(desc="Aggregated capabilities and strategic focus of the firm")
    node_requirements = dspy.InputField(desc="Technical and operational requirements of the project node")
    
    importance_score = dspy.OutputField(desc="Numeric criticality/importance of the node to project success, between 0.0 and 1.0 (float)")
    influence_score = dspy.OutputField(desc="Numeric influence/control score the firm has over this node, between 0.0 and 1.0 (float)")
    reasoning = dspy.OutputField(desc="Exhaustive explanation of why these scores were assigned, based on the firm's fit for the node requirements")

class PropagationSignature(dspy.Signature):
    """
    Signature for calculating how risk propagates from a source node to its dependents.
    """
    upstream_risk_tensor = dspy.InputField(desc="Risk vector from parent nodes")
    local_risk_factors = dspy.InputField(desc="Specific risk factors for this node")
    
    cascading_risk_score = dspy.OutputField(desc="Total calculated risk after propagation")

class DiscoverySignature(dspy.Signature):
    """
    Signature for discovering hidden infrastructure dependencies.
    Identifies missing nodes that are required for a component to function but aren't in the initial graph.
    """
    node_requirements = dspy.InputField(desc="Technical and operational requirements of the current node")
    existing_graph_context = dspy.InputField(desc="Summary of nodes already in the infrastructure graph")
    
    hidden_dependencies = dspy.OutputField(desc="List of missing infrastructure nodes (Name, Type, Description)")
    reasoning = dspy.OutputField(desc="Reasoning for why these hidden dependencies are likely present")
