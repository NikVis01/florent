from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field, field_validator, model_validator

from src.models.base import OperationType, Sectors, StrategicFocus, Country

# --- Business Entities ---

class Firm(BaseModel):
    id: str
    name: str
    description: str
    countries_active: List[Country]
    sectors: List[Sectors]
    services: List[OperationType]
    strategic_focuses: List[StrategicFocus]
    prefered_project_timeline: int = Field(alias="preferred_project_timeline") # in months

    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")

    class Config:
        populate_by_name = True  # Allow both field name and alias

class ProjectEntry(BaseModel):
    pre_requisites: List[str] = Field(description="Mandatory conditions to be met before project start")
    mobilization_time: int = Field(description="Time in months required to start operations")
    entry_node_id: str = Field(description="ID of the first node in the infrastructure DAG")

class ProjectExit(BaseModel):
    success_metrics: List[str] = Field(description="KPIs or deliverables required for successful completion")
    mandate_end_date: Optional[str] = Field(None, description="ISO date for mandate completion")
    exit_node_id: str = Field(description="ID of the final/sink node in the infrastructure DAG")

class Project(BaseModel):
    id: str
    name: str
    description: str
    country: Country
    sector: str
    service_requirements: List[str]
    timeline: int # in months
    ops_requirements: List[OperationType]
    
    entry_criteria: Optional[ProjectEntry] = None
    success_criteria: Optional[ProjectExit] = None
    
    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")

class RiskProfile(BaseModel):
    id: str
    name: str
    risk_level: int = Field(ge=1, le=5, description="how detrimental is the failure of this node/operation")
    influence_level: int = Field(ge=1, le=5, description="how much can the firm control or influence the success of this node/operation")
    description: str

# --- Analysis Output Models (Client Facing) ---

class CriticalChain(BaseModel):
    chain_id: str
    nodes: List[str] = Field(description="Sequence of node IDs forming a critical path")
    aggregate_risk: float = Field(description="Cumulative failure probability across the chain")
    impact_description: str

class PivotalNode(BaseModel):
    node_id: str
    contribution_score: float = Field(description="Percentage weight this node adds to downstream risk")
    strategic_reason: str = Field(description="Why this node is a linchpin (e.g., high centrality + high local risk)")

class AnalysisOutput(BaseModel):
    project_id: str
    firm_id: str
    
    # Technical depth for simulations
    risk_tensors: Dict[str, Any] = Field(default_factory=dict, description="PyTorch tensors of risk distributions")
    
    # Business value for the client
    overall_bankability: float = Field(ge=0, le=1)
    critical_chains: List[CriticalChain] = Field(default_factory=list)
    pivotal_nodes: List[PivotalNode] = Field(default_factory=list)
    
    # SPICE-inspired spreads
    optimal_score: float
    worst_case_score: float
    scenario_spread: List[float] = Field(default_factory=list, description="Distribution of probable outcomes")

    class Config:
        arbitrary_types_allowed = True # Needed for Torch Tensors