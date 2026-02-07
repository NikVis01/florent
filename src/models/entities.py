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
    
    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")


# Defines a set of risk characteristics or thresholds for an entity or project.
class RiskProfile(BaseModel):
    id: str
    name: str
    risk_level: int = Field(ge=1, le=5, description="how detrimental is the failure of this node/operation")
    influence_level: int = Field(ge=1, le=5, description="how much can the firm control or influence the success of this node/operation")
    description: str
    