# Random models
from typing import List
from pydantic import BaseModel, Field

from src.models.misc import OperationType

class Project(BaseModel):
    id: str
    name: str
    description: str
    country: str
    sector: str
    service_requirements: List[str]
    timeline: int # in months
    ops_requirements: List[OperationType]
    
    embedding: List[float] = Field(default_factory=list, description="Vector embedding for similarity calculations")
