from typing import List, Optional
from pydantic import BaseModel, Field, field_validator

from src.models.base import OperationType, Sectors, StrategicFocus, Country, get_valid_country_codes

# Represents a business entity with its active regions, services, and strategic goals.
class Firm(BaseModel):
    id: str
    name: str
    
    # Contains a fair amount of information about the firm
    description: str
    countries_active: List[Country] # List of Country objects
    sectors: List[Sectors]
    services: List[OperationType]
    strategic_focuses: List[StrategicFocus]
    prefered_project_timeline: int # in months
    
    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")


# Requirements for starting a project (Entry point)
class ProjectEntry(BaseModel):
    pre_requisites: List[str] = Field(description="Mandatory conditions to be met before project start")
    mobilization_time: int = Field(description="Time in months required to start operations")
    entry_node_id: str = Field(description="ID of the first node in the infrastructure DAG")

# Criteria for successfully completing a project (Exit point)
class ProjectExit(BaseModel):
    success_metrics: List[str] = Field(description="KPIs or deliverables required for successful completion")
    mandate_end_date: Optional[str] = Field(None, description="ISO date for mandate completion")
    exit_node_id: str = Field(description="ID of the final/sink node in the infrastructure DAG")

# Describes a specific business project or requirement within a country and sector.
class Project(BaseModel):
    id: str
    name: str
    description: str
    country: Country # Full Country metadata
    sector: str
    service_requirements: List[str]
    timeline: int # in months
    ops_requirements: List[OperationType]
    
    entry_criteria: Optional[ProjectEntry] = None
    success_criteria: Optional[ProjectExit] = None
    
    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")


# Defines a set of risk characteristics or thresholds for an entity or project.
class RiskProfile(BaseModel):
    id: str
    name: str
    risk_level: int = Field(ge=1, le=5, description="how detrimental is the failure of this node/operation")
    influence_level: int = Field(ge=1, le=5, description="how much can the firm control or influence the success of this node/operation")
    description: str
    