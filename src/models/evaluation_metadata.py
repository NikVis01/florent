"""Evaluation metadata models for performance tracking."""
from pydantic import BaseModel, Field
from typing import Dict
from datetime import datetime


class NodeEvaluation(BaseModel):
    """Evaluation details for a single node."""
    evaluation_time_ms: float = Field(description="Time taken to evaluate this node")
    tokens_used: int = Field(ge=0, description="Tokens consumed for this evaluation")
    cost_usd: float = Field(ge=0.0, description="Cost in USD")
    retry_attempts: int = Field(ge=0, default=0)
    cache_hit: bool = Field(default=False)
    model_used: str
    timestamp: datetime


class TokenBreakdown(BaseModel):
    """Token usage breakdown by operation type."""
    node_evaluation: int = Field(ge=0)
    discovery: int = Field(ge=0)
    system_overhead: int = Field(ge=0, default=0)


class EvaluationTotals(BaseModel):
    """Aggregate evaluation statistics."""
    total_tokens: int = Field(ge=0)
    total_cost_usd: float = Field(ge=0.0)
    total_time_ms: float = Field(ge=0.0)
    cache_hits: int = Field(ge=0)
    cache_misses: int = Field(ge=0)
    failed_evaluations: int = Field(ge=0)
    retries_performed: int = Field(ge=0)
    nodes_from_cache: int = Field(ge=0)


class EvaluationMetadata(BaseModel):
    """Complete evaluation metadata."""
    nodes: Dict[str, NodeEvaluation] = Field(
        description="Per-node evaluation details"
    )
    totals: EvaluationTotals
    token_breakdown: TokenBreakdown
