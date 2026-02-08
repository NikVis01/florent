"""
Configuration dataclasses for Florent risk assessment system.

All tunable parameters are centralized here with type safety and validation.
Load from environment variables with sensible defaults.
"""

import os
from dataclasses import dataclass, asdict
from typing import Dict, Any
from pathlib import Path


@dataclass
class CrossEncoderConfig:
    """Configuration for BGE-M3 cross-encoder inference."""

    endpoint: str = "http://localhost:8080"
    enabled: bool = True
    health_timeout: float = 2.0  # seconds
    request_timeout: float = 10.0  # seconds
    fallback_score: float = 0.5  # score when service fails

    @classmethod
    def from_env(cls) -> "CrossEncoderConfig":
        """Load configuration from environment variables."""
        return cls(
            endpoint=os.getenv("CROSS_ENCODER_ENDPOINT", os.getenv("BGE_M3_URL", "http://localhost:8080")),
            enabled=os.getenv("USE_CROSS_ENCODER", "true").lower() == "true",
            health_timeout=float(os.getenv("CROSS_ENCODER_HEALTH_TIMEOUT", "2")),
            request_timeout=float(os.getenv("CROSS_ENCODER_REQUEST_TIMEOUT", "10")),
            fallback_score=float(os.getenv("CROSS_ENCODER_FALLBACK_SCORE", "0.5"))
        )

    def validate(self):
        """Validate configuration values."""
        assert 0.0 <= self.fallback_score <= 1.0, "Fallback score must be 0-1"
        assert self.health_timeout > 0, "Health timeout must be positive"
        assert self.request_timeout > 0, "Request timeout must be positive"


@dataclass
class AgentConfig:
    """Configuration for DSPy agent orchestrator."""

    # Retry and error handling
    max_retries: int = 3
    backoff_base: int = 2  # exponential backoff: base^attempt

    # Caching
    cache_enabled: bool = True
    cache_dir: Path = Path.home() / ".cache" / "florent" / "dspy_cache"

    # Default scores when evaluation fails
    default_importance: float = 0.5
    default_influence: float = 0.5

    # Token estimation (for cost tracking)
    tokens_per_eval: int = 300
    tokens_per_discovery: int = 500

    @classmethod
    def from_env(cls) -> "AgentConfig":
        """Load configuration from environment variables."""
        cache_dir_str = os.getenv("DSPY_CACHE_DIR", "~/.cache/florent/dspy_cache")
        cache_dir = Path(cache_dir_str).expanduser()

        return cls(
            max_retries=int(os.getenv("AGENT_MAX_RETRIES", "3")),
            backoff_base=int(os.getenv("AGENT_BACKOFF_BASE", "2")),
            cache_enabled=os.getenv("AGENT_CACHE_ENABLED", "true").lower() == "true",
            cache_dir=cache_dir,
            default_importance=float(os.getenv("AGENT_DEFAULT_IMPORTANCE", "0.5")),
            default_influence=float(os.getenv("AGENT_DEFAULT_INFLUENCE", "0.5")),
            tokens_per_eval=int(os.getenv("AGENT_TOKENS_PER_EVAL", "300")),
            tokens_per_discovery=int(os.getenv("AGENT_TOKENS_PER_DISCOVERY", "500"))
        )

    def validate(self):
        """Validate configuration values."""
        assert self.max_retries > 0, "Max retries must be positive"
        assert self.backoff_base >= 2, "Backoff base must be >= 2"
        assert 0.0 <= self.default_importance <= 1.0, "Default importance must be 0-1"
        assert 0.0 <= self.default_influence <= 1.0, "Default influence must be 0-1"
        assert self.tokens_per_eval > 0, "Tokens per eval must be positive"
        assert self.tokens_per_discovery > 0, "Tokens per discovery must be positive"


@dataclass
class MatrixConfig:
    """Configuration for importance/influence matrix classification."""

    # Thresholds for classifying nodes as "high" (0-1 scale)
    influence_threshold: float = 0.6
    importance_threshold: float = 0.6

    # Legacy thresholds for risk-based classification (if still used)
    high_risk_threshold: float = 0.7
    high_influence_threshold: float = 0.7

    @classmethod
    def from_env(cls) -> "MatrixConfig":
        """Load configuration from environment variables."""
        return cls(
            influence_threshold=float(os.getenv("MATRIX_INFLUENCE_THRESHOLD", "0.6")),
            importance_threshold=float(os.getenv("MATRIX_IMPORTANCE_THRESHOLD", "0.6")),
            high_risk_threshold=float(os.getenv("MATRIX_HIGH_RISK_THRESHOLD", "0.7")),
            high_influence_threshold=float(os.getenv("MATRIX_HIGH_INFLUENCE_THRESHOLD", "0.7"))
        )

    def validate(self):
        """Validate configuration values."""
        assert 0.0 <= self.influence_threshold <= 1.0, "Influence threshold must be 0-1"
        assert 0.0 <= self.importance_threshold <= 1.0, "Importance threshold must be 0-1"
        assert 0.0 <= self.high_risk_threshold <= 1.0, "High risk threshold must be 0-1"
        assert 0.0 <= self.high_influence_threshold <= 1.0, "High influence threshold must be 0-1"


@dataclass
class BiddingConfig:
    """Configuration for bid decision logic."""

    # Maximum ratio of critical dependencies (Type C) on critical path before rejecting bid
    critical_dep_max_ratio: float = 0.5  # 50%

    # Minimum bankability score to recommend bidding
    min_bankability_threshold: float = 0.7

    # Confidence thresholds for recommendations
    high_confidence: float = 0.9
    low_confidence: float = 0.6

    # Bankability classification thresholds
    bankability_high: float = 0.8  # "Strong bankability"
    bankability_medium: float = 0.6  # "Moderate bankability"

    @classmethod
    def from_env(cls) -> "BiddingConfig":
        """Load configuration from environment variables."""
        return cls(
            critical_dep_max_ratio=float(os.getenv("BID_CRITICAL_DEP_MAX_RATIO", "0.5")),
            min_bankability_threshold=float(os.getenv("BID_MIN_BANKABILITY_THRESHOLD", "0.7")),
            high_confidence=float(os.getenv("RECOMMENDATION_HIGH_CONFIDENCE", "0.9")),
            low_confidence=float(os.getenv("RECOMMENDATION_LOW_CONFIDENCE", "0.6")),
            bankability_high=float(os.getenv("RECOMMENDATION_BANKABILITY_HIGH", "0.8")),
            bankability_medium=float(os.getenv("RECOMMENDATION_BANKABILITY_MEDIUM", "0.6"))
        )

    def validate(self):
        """Validate configuration values."""
        assert 0.0 <= self.critical_dep_max_ratio <= 1.0, "Critical dep ratio must be 0-1"
        assert 0.0 <= self.min_bankability_threshold <= 1.0, "Bankability threshold must be 0-1"
        assert 0.0 <= self.high_confidence <= 1.0, "High confidence must be 0-1"
        assert 0.0 <= self.low_confidence <= 1.0, "Low confidence must be 0-1"
        assert self.high_confidence > self.low_confidence, "High confidence must exceed low"
        assert 0.0 <= self.bankability_high <= 1.0, "Bankability high must be 0-1"
        assert 0.0 <= self.bankability_medium <= 1.0, "Bankability medium must be 0-1"
        assert self.bankability_high > self.bankability_medium, "High must exceed medium"


@dataclass
class GraphBuilderConfig:
    """Configuration for firm-contextual graph builder."""

    # Gap detection and discovery
    gap_threshold: float = 0.3  # Similarity floor for triggering discovery
    max_iterations: int = 10  # Max gap-filling iterations
    max_discovered_nodes: int = 50  # Global limit on generated nodes
    max_nodes_per_gap: int = 3  # Max nodes to inject per gap
    max_gaps_per_iteration: int = 5  # Max gaps to process per iteration

    # Edge weights
    default_edge_weight: float = 0.8
    distance_decay_factor: float = 0.9  # weight = similarity * decay^distance
    discovered_min_weight: float = 0.4
    discovered_default_weight: float = 0.6
    discovered_edge_weight: float = 0.8
    infrastructure_weight: float = 0.5  # For sustainment edges to exit
    bridge_gap_weight: float = 0.7
    bridge_gap_min_weight: float = 0.5

    @classmethod
    def from_env(cls) -> "GraphBuilderConfig":
        """Load configuration from environment variables."""
        return cls(
            gap_threshold=float(os.getenv("GRAPH_GAP_THRESHOLD", "0.3")),
            max_iterations=int(os.getenv("GRAPH_MAX_ITERATIONS", "10")),
            max_discovered_nodes=int(os.getenv("GRAPH_MAX_DISCOVERED_NODES", "50")),
            max_nodes_per_gap=int(os.getenv("GRAPH_MAX_NODES_PER_GAP", "3")),
            max_gaps_per_iteration=int(os.getenv("GRAPH_MAX_GAPS_PER_ITERATION", "5")),
            default_edge_weight=float(os.getenv("GRAPH_DEFAULT_EDGE_WEIGHT", "0.8")),
            distance_decay_factor=float(os.getenv("GRAPH_DISTANCE_DECAY_FACTOR", "0.9")),
            discovered_min_weight=float(os.getenv("GRAPH_DISCOVERED_MIN_WEIGHT", "0.4")),
            discovered_default_weight=float(os.getenv("GRAPH_DISCOVERED_DEFAULT_WEIGHT", "0.6")),
            discovered_edge_weight=float(os.getenv("GRAPH_DISCOVERED_EDGE_WEIGHT", "0.8")),
            infrastructure_weight=float(os.getenv("GRAPH_INFRASTRUCTURE_WEIGHT", "0.5")),
            bridge_gap_weight=float(os.getenv("GRAPH_BRIDGE_GAP_WEIGHT", "0.7")),
            bridge_gap_min_weight=float(os.getenv("GRAPH_BRIDGE_GAP_MIN_WEIGHT", "0.5"))
        )

    def validate(self):
        """Validate configuration values."""
        assert 0.0 <= self.gap_threshold <= 1.0, "Gap threshold must be 0-1"
        assert self.max_iterations > 0, "Max iterations must be positive"
        assert self.max_discovered_nodes > 0, "Max discovered nodes must be positive"
        assert self.max_nodes_per_gap > 0, "Max nodes per gap must be positive"
        assert 0.0 <= self.default_edge_weight <= 1.0, "Default edge weight must be 0-1"
        assert 0.0 < self.distance_decay_factor <= 1.0, "Distance decay must be 0-1"


@dataclass
class PipelineConfig:
    """Configuration for analysis pipeline."""

    # Graph building
    min_edge_weight: float = 0.6
    edge_weight_decay: float = 0.05  # Decay per sequential edge
    initial_edge_weight: float = 0.9

    # Risk propagation
    risk_propagation_factor: float = 0.5  # Multiplier in compound formula
    critical_chain_threshold: float = 0.1  # Min aggregate risk for critical chains

    # Execution
    default_budget: int = 100  # Default number of node evaluations

    # Defaults
    default_failure_likelihood: float = 0.5

    @classmethod
    def from_env(cls) -> "PipelineConfig":
        """Load configuration from environment variables."""
        return cls(
            min_edge_weight=float(os.getenv("PIPELINE_MIN_EDGE_WEIGHT", "0.6")),
            edge_weight_decay=float(os.getenv("PIPELINE_EDGE_WEIGHT_DECAY", "0.05")),
            initial_edge_weight=float(os.getenv("PIPELINE_INITIAL_EDGE_WEIGHT", "0.9")),
            risk_propagation_factor=float(os.getenv("PIPELINE_RISK_PROPAGATION_FACTOR", "0.5")),
            critical_chain_threshold=float(os.getenv("PIPELINE_CRITICAL_CHAIN_THRESHOLD", "0.1")),
            default_budget=int(os.getenv("PIPELINE_DEFAULT_BUDGET", "100")),
            default_failure_likelihood=float(os.getenv("METRICS_DEFAULT_FAILURE_LIKELIHOOD", "0.5"))
        )

    def validate(self):
        """Validate configuration values."""
        assert 0.0 <= self.min_edge_weight <= 1.0, "Min edge weight must be 0-1"
        assert 0.0 <= self.edge_weight_decay <= 1.0, "Edge weight decay must be 0-1"
        assert 0.0 <= self.initial_edge_weight <= 1.0, "Initial edge weight must be 0-1"
        assert 0.0 <= self.risk_propagation_factor <= 1.0, "Risk propagation factor must be 0-1"
        assert 0.0 <= self.critical_chain_threshold <= 1.0, "Critical chain threshold must be 0-1"
        assert self.default_budget > 0, "Default budget must be positive"
        assert 0.0 <= self.default_failure_likelihood <= 1.0, "Default failure likelihood must be 0-1"


# ==============================================================================
# Helper functions for configuration management
# ==============================================================================

def get_all_configs() -> Dict[str, Any]:
    """
    Load all configuration objects from environment variables.

    Returns:
        Dictionary with configuration objects for each module.
    """
    configs = {
        "cross_encoder": CrossEncoderConfig.from_env(),
        "agent": AgentConfig.from_env(),
        "matrix": MatrixConfig.from_env(),
        "bidding": BiddingConfig.from_env(),
        "graph_builder": GraphBuilderConfig.from_env(),
        "pipeline": PipelineConfig.from_env()
    }

    # Validate all configs
    for name, config in configs.items():
        try:
            config.validate()
        except AssertionError as e:
            raise ValueError(f"Invalid configuration for {name}: {e}")

    return configs


def override_config(config_dict: Dict[str, Any], overrides: Dict[str, Any]) -> Dict[str, Any]:
    """
    Override configuration values for hyperparameter tuning.

    Args:
        config_dict: Original configuration dictionary
        overrides: Dictionary of {path: value} to override (e.g., {"agent.max_retries": 5})

    Returns:
        Updated configuration dictionary

    Example:
        >>> configs = get_all_configs()
        >>> configs = override_config(configs, {"agent.max_retries": 5, "matrix.influence_threshold": 0.7})
    """
    import copy
    config_dict = copy.deepcopy(config_dict)

    for path, value in overrides.items():
        parts = path.split(".")
        if len(parts) != 2:
            raise ValueError(f"Invalid config path: {path}. Expected format: 'module.parameter'")

        module, param = parts
        if module not in config_dict:
            raise ValueError(f"Unknown config module: {module}")

        config_obj = config_dict[module]
        if not hasattr(config_obj, param):
            raise ValueError(f"Unknown parameter: {param} in module {module}")

        # Update the value
        setattr(config_obj, param, value)

        # Re-validate
        try:
            config_obj.validate()
        except AssertionError as e:
            raise ValueError(f"Invalid override for {path}={value}: {e}")

    return config_dict


def export_config_dict() -> Dict[str, Dict[str, Any]]:
    """
    Export all configurations as nested dictionaries (for serialization).

    Returns:
        Nested dictionary: {module: {param: value}}
    """
    configs = get_all_configs()
    return {
        module: asdict(config_obj)
        for module, config_obj in configs.items()
    }
