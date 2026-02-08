"""
Dataclasses for agent orchestration and execution tracking.

Provides structured types for token usage tracking, discovery personas,
and execution traces.
"""

from dataclasses import dataclass, field
from datetime import datetime
from typing import List, Dict, Any
from enum import Enum


@dataclass
class TokenUsageTracker:
    """
    Track token usage and costs across different operation types.

    Attributes:
        node_evaluation: Tokens used for node importance/influence evaluation
        discovery: Tokens used for hidden dependency discovery
        total_operations: Total number of operations performed
        model: LLM model being used (for cost calculation)
        cost_per_1k_tokens: Cost per 1000 tokens (USD)
    """
    node_evaluation: int = 0
    discovery: int = 0
    total_operations: int = 0
    model: str = "gpt-4o-mini"
    cost_per_1k_tokens: float = 0.00015  # Default for gpt-4o-mini

    def add_node_eval(self, tokens: int):
        """Add tokens from node evaluation."""
        self.node_evaluation += tokens
        self.total_operations += 1

    def add_discovery(self, tokens: int):
        """Add tokens from discovery operation."""
        self.discovery += tokens
        self.total_operations += 1

    @property
    def total_tokens(self) -> int:
        """Total tokens consumed across all operations."""
        return self.node_evaluation + self.discovery

    @property
    def total_cost_usd(self) -> float:
        """Total estimated cost in USD."""
        return (self.total_tokens / 1000) * self.cost_per_1k_tokens

    def set_model_pricing(self, model: str):
        """Update cost based on model."""
        pricing = {
            "gpt-4o-mini": 0.00015,
            "gpt-4o": 0.0025,
            "gpt-4": 0.03,
            "gpt-3.5-turbo": 0.0015
        }
        self.model = model
        self.cost_per_1k_tokens = pricing.get(model, 0.0)

    def get_breakdown(self) -> Dict[str, Any]:
        """Get detailed token usage breakdown."""
        return {
            "node_evaluation": self.node_evaluation,
            "discovery": self.discovery,
            "total_tokens": self.total_tokens,
            "total_cost_usd": round(self.total_cost_usd, 4),
            "model": self.model,
            "operations": self.total_operations
        }


@dataclass
class DiscoveryPersona:
    """
    Configuration for an AI discovery persona.

    Each persona represents a different analytical perspective for discovering
    hidden infrastructure dependencies.

    Attributes:
        name: Persona name (e.g., "Technical Infrastructure Expert")
        description: Detailed description of persona's role
        expertise_areas: List of domain expertise areas
        bias_towards: Types of dependencies this persona tends to discover
        discovery_weight: Confidence weight for this persona's discoveries (0-1)
    """
    name: str
    description: str
    expertise_areas: List[str]
    bias_towards: List[str]
    discovery_weight: float = 1.0

    def __post_init__(self):
        """Validate persona configuration."""
        assert 0.0 <= self.discovery_weight <= 1.0, \
            f"Discovery weight must be 0-1, got {self.discovery_weight}"
        assert len(self.name) > 0, "Persona name cannot be empty"
        assert len(self.expertise_areas) > 0, "Must have at least one expertise area"


# Default discovery personas
DEFAULT_PERSONAS = [
    DiscoveryPersona(
        name="Technical Infrastructure Expert",
        description="Focuses on hardware, software, and technical dependencies",
        expertise_areas=["infrastructure", "technical", "engineering", "construction", "manufacturing"],
        bias_towards=["technical"],
        discovery_weight=1.0
    ),
    DiscoveryPersona(
        name="Financial Risk & Compliance Auditor",
        description="Identifies financial and regulatory hidden dependencies",
        expertise_areas=["finance", "compliance", "regulatory", "auditing", "accounting", "banking"],
        bias_towards=["financial"],
        discovery_weight=0.9
    ),
    DiscoveryPersona(
        name="Geopolitical & Regulatory Consultant",
        description="Uncovers political and cross-border dependencies",
        expertise_areas=["geopolitical", "regulatory", "international", "policy", "law", "government"],
        bias_towards=["political"],
        discovery_weight=0.85
    ),
    DiscoveryPersona(
        name="Supply Chain & Logistics Expert",
        description="Identifies supply chain and logistics dependencies",
        expertise_areas=["supply_chain", "logistics", "transportation", "shipping"],
        bias_towards=["supply_chain"],
        discovery_weight=0.95
    )
]


@dataclass
class CriticalPathMarker:
    """
    Enhanced tracking of nodes on critical paths.

    Attributes:
        node_id: Node identifier
        is_critical: Whether node is on any critical path
        chain_ids: List of critical chain IDs containing this node
        criticality_score: How critical this node is (0-1, based on # of chains)
        rank: Position in primary critical chain (0 = entry, higher = downstream)
    """
    node_id: str
    is_critical: bool
    chain_ids: List[str] = field(default_factory=list)
    criticality_score: float = 0.0
    rank: int = 0

    def __post_init__(self):
        """Validate criticality score."""
        assert 0.0 <= self.criticality_score <= 1.0, \
            f"Criticality score must be 0-1, got {self.criticality_score}"

    def add_chain(self, chain_id: str):
        """Add this node to a critical chain."""
        if chain_id not in self.chain_ids:
            self.chain_ids.append(chain_id)
            self.is_critical = True
            # Update criticality score (normalized by number of chains)
            self.criticality_score = min(1.0, len(self.chain_ids) * 0.2)


class ExecutionPhase(str, Enum):
    """Phases of pipeline execution."""
    INIT = "initialization"
    GRAPH_BUILD = "graph_building"
    CROSS_ENCODER_SCORING = "cross_encoder_scoring"
    GAP_DETECTION = "gap_detection"
    NODE_DISCOVERY = "node_discovery"
    NODE_EVALUATION = "node_evaluation"
    RISK_PROPAGATION = "risk_propagation"
    MATRIX_CLASSIFICATION = "matrix_classification"
    CHAIN_DETECTION = "chain_detection"
    RECOMMENDATION = "recommendation"
    COMPLETE = "complete"
    ERROR = "error"


@dataclass
class ExecutionTrace:
    """
    Full trace of pipeline execution for debugging and monitoring.

    Attributes:
        firm_id: Firm being analyzed
        project_id: Project being analyzed
        start_time: When execution started
        end_time: When execution completed (None if still running)
        current_phase: Current execution phase
        phases_completed: List of completed phases
        phases_failed: List of failed phases with error messages
        budget_allocated: Total budget (node evaluations) allocated
        budget_used: Budget consumed so far
        token_tracker: Token usage tracker
        metadata: Additional execution metadata
    """
    firm_id: str
    project_id: str
    start_time: datetime = field(default_factory=datetime.now)
    end_time: datetime | None = None
    current_phase: ExecutionPhase = ExecutionPhase.INIT
    phases_completed: List[str] = field(default_factory=list)
    phases_failed: List[Dict[str, str]] = field(default_factory=list)
    budget_allocated: int = 0
    budget_used: int = 0
    token_tracker: TokenUsageTracker = field(default_factory=TokenUsageTracker)
    metadata: Dict[str, Any] = field(default_factory=dict)

    def start_phase(self, phase: ExecutionPhase):
        """Start a new execution phase."""
        self.current_phase = phase
        self.metadata[f"{phase.value}_start"] = datetime.now()

    def complete_phase(self, phase: ExecutionPhase):
        """Mark a phase as completed."""
        self.phases_completed.append(phase.value)
        self.metadata[f"{phase.value}_end"] = datetime.now()

    def fail_phase(self, phase: ExecutionPhase, error: str):
        """Mark a phase as failed with error message."""
        self.phases_failed.append({
            "phase": phase.value,
            "error": error,
            "timestamp": datetime.now().isoformat()
        })
        self.current_phase = ExecutionPhase.ERROR

    def complete_execution(self):
        """Mark execution as complete."""
        self.end_time = datetime.now()
        self.current_phase = ExecutionPhase.COMPLETE

    @property
    def duration_seconds(self) -> float:
        """Total execution time in seconds."""
        if self.end_time is None:
            return (datetime.now() - self.start_time).total_seconds()
        return (self.end_time - self.start_time).total_seconds()

    @property
    def budget_remaining(self) -> int:
        """Remaining budget."""
        return max(0, self.budget_allocated - self.budget_used)

    @property
    def is_complete(self) -> bool:
        """Check if execution is complete."""
        return self.current_phase in [ExecutionPhase.COMPLETE, ExecutionPhase.ERROR]

    @property
    def is_error(self) -> bool:
        """Check if execution failed."""
        return self.current_phase == ExecutionPhase.ERROR

    def get_summary(self) -> Dict[str, Any]:
        """Get execution summary."""
        return {
            "firm_id": self.firm_id,
            "project_id": self.project_id,
            "duration_seconds": round(self.duration_seconds, 2),
            "current_phase": self.current_phase.value,
            "phases_completed": len(self.phases_completed),
            "phases_failed": len(self.phases_failed),
            "budget_used": self.budget_used,
            "budget_remaining": self.budget_remaining,
            "token_usage": self.token_tracker.get_breakdown(),
            "is_complete": self.is_complete,
            "is_error": self.is_error
        }


def load_personas_from_config(config_path: str = None) -> List[DiscoveryPersona]:
    """
    Load discovery personas from JSON configuration file.

    Args:
        config_path: Path to personas config JSON (optional)

    Returns:
        List of DiscoveryPersona objects

    If no config_path provided or file not found, returns DEFAULT_PERSONAS.
    """
    if config_path is None:
        return DEFAULT_PERSONAS.copy()

    try:
        import json
        from pathlib import Path

        path = Path(config_path)
        if not path.exists():
            return DEFAULT_PERSONAS.copy()

        with open(path, "r") as f:
            data = json.load(f)

        personas = []
        for item in data:
            persona = DiscoveryPersona(
                name=item["name"],
                description=item["description"],
                expertise_areas=item["expertise_areas"],
                bias_towards=item["bias_towards"],
                discovery_weight=item.get("discovery_weight", 1.0)
            )
            personas.append(persona)

        return personas if personas else DEFAULT_PERSONAS.copy()

    except Exception as e:
        # Fallback to defaults on any error
        print(f"Warning: Failed to load personas from {config_path}: {e}")
        return DEFAULT_PERSONAS.copy()
