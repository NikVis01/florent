"""Risk propagation trace models."""
from pydantic import BaseModel, Field
from typing import List, Dict


class IncomingRisk(BaseModel):
    """Risk contribution from a parent node."""
    from_node: str = Field(alias="from")
    contributed: float = Field(ge=0.0, le=1.0, description="Risk contributed by parent")
    edge_weight: float = Field(ge=0.0, le=1.0, description="Edge weight from parent")
    attenuation: float = Field(description="Distance attenuation factor")

    class Config:
        populate_by_name = True


class OutgoingRisk(BaseModel):
    """Risk transmitted to a child node."""
    to_node: str = Field(alias="to")
    transmitted: float = Field(ge=0.0, le=1.0, description="Risk passed to child")
    multiplier: float = Field(description="Propagation multiplier")

    class Config:
        populate_by_name = True


class NodePropagation(BaseModel):
    """Propagation details for a single node."""
    local_risk: float = Field(ge=0.0, le=1.0)
    incoming_risk: List[IncomingRisk] = Field(default_factory=list)
    propagated_risk: float = Field(ge=0.0, le=1.0)
    outgoing_risk: List[OutgoingRisk] = Field(default_factory=list)
    propagation_multiplier: float
    formula: str = Field(
        default="risk = local + (max_parent * local * propagation_factor)",
        description="Formula used for propagation"
    )


class PropagationConfig(BaseModel):
    """Configuration used for propagation."""
    propagation_factor: float = Field(description="Risk compound multiplier")
    multiplier: float = Field(description="Critical path multiplier")
    attenuation_factor: float = Field(description="Distance decay factor")
    method: str = Field(default="topological_sort")


class PropagationTrace(BaseModel):
    """Complete risk propagation trace."""
    nodes: Dict[str, NodePropagation] = Field(
        description="Per-node propagation breakdown"
    )
    config: PropagationConfig
