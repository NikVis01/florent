"""Configuration snapshot models for reproducibility."""
from pydantic import BaseModel, Field
from typing import Dict, Any
from datetime import datetime


class ModelVersions(BaseModel):
    """Model versions used in analysis."""
    llm: str = Field(description="LLM model name")
    cross_encoder: str = Field(description="Cross-encoder model name")
    dspy_version: str = Field(description="DSPy version")


class ConfigurationSnapshot(BaseModel):
    """Complete configuration snapshot for reproducibility."""
    timestamp: datetime
    version: str = Field(description="Florent version")
    parameters: Dict[str, Dict[str, Any]] = Field(
        description="All 41 configuration parameters organized by module"
    )
    models: ModelVersions
