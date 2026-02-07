
from typing import List
from pydantic import BaseModel, Field

from src.models.misc import OperationType, Sectors, StrategicFocus

class Firm(BaseModel):
    id: str
    name: str
    
    # Contains a fair amount of information about the firm
    description: str
    countries_active: List[str]
    sectors: List[Sectors]
    services: List[OperationType]
    strategic_focuses: List[StrategicFocus]
    prefered_project_timeline: int # in months
    
    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")
