import dspy

class NodeSignature(dspy.Signature):
    """
    Base signature for node analysis.
    Takes a firm's capability context and a node's requirement context,
    and returns a structured risk/influence assessment.
    """
    firm_context = dspy.InputField(desc="Aggregated capabilities and strategic focus of the firm")
    node_requirements = dspy.InputField(desc="Technical and operational requirements of the project node")
    
    influence_score = dspy.OutputField(desc="Numeric influence score between 0.0 and 1.0 (float)")
    risk_assessment = dspy.OutputField(desc="Numeric risk level between 0.0 and 1.0 (float)")
    reasoning = dspy.OutputField(desc="Brief explanation of the assessment")

class PropagationSignature(dspy.Signature):
    """
    Signature for calculating how risk propagates from a source node to its dependents.
    """
    upstream_risk_tensor = dspy.InputField(desc="Risk vector from parent nodes")
    local_risk_factors = dspy.InputField(desc="Specific risk factors for this node")
    
    cascading_risk_score = dspy.OutputField(desc="Total calculated risk after propagation")
