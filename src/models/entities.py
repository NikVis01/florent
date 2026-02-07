from typing import List, Optional
from pydantic import BaseModel, Field, field_validator

from src.models.base import OperationType, Sectors, StrategicFocus, Country, get_valid_country_codes

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
