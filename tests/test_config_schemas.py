"""Tests for configuration schemas and settings integration."""

import pytest
from src.config.schemas import (
    CrossEncoderConfig,
    AgentConfig,
    MatrixConfig,
    BiddingConfig,
    GraphBuilderConfig,
    PipelineConfig,
    get_all_configs,
    override_config
)
from src.settings import settings


class TestConfigSchemas:
    """Test individual configuration schema loading and validation."""

    def test_cross_encoder_config_from_env(self):
        """Test CrossEncoderConfig loads from environment."""
        config = CrossEncoderConfig.from_env()

        assert config.endpoint is not None
        assert isinstance(config.enabled, bool)
        assert config.health_timeout > 0
        assert config.request_timeout > 0
        assert 0.0 <= config.fallback_score <= 1.0

        # Validation should pass
        config.validate()

    def test_agent_config_from_env(self):
        """Test AgentConfig loads from environment."""
        config = AgentConfig.from_env()

        assert config.max_retries > 0
        assert config.backoff_base >= 2
        assert 0.0 <= config.default_importance <= 1.0
        assert 0.0 <= config.default_influence <= 1.0
        assert config.tokens_per_eval > 0
        assert config.tokens_per_discovery > 0

        # Validation should pass
        config.validate()

    def test_matrix_config_from_env(self):
        """Test MatrixConfig loads from environment."""
        config = MatrixConfig.from_env()

        assert 0.0 <= config.influence_threshold <= 1.0
        assert 0.0 <= config.importance_threshold <= 1.0
        assert 0.0 <= config.high_risk_threshold <= 1.0

        # Validation should pass
        config.validate()

    def test_bidding_config_from_env(self):
        """Test BiddingConfig loads from environment."""
        config = BiddingConfig.from_env()

        assert 0.0 <= config.critical_dep_max_ratio <= 1.0
        assert 0.0 <= config.min_bankability_threshold <= 1.0
        assert config.high_confidence > config.low_confidence

        # Validation should pass
        config.validate()

    def test_graph_builder_config_from_env(self):
        """Test GraphBuilderConfig loads from environment."""
        config = GraphBuilderConfig.from_env()

        assert 0.0 <= config.gap_threshold <= 1.0
        assert config.max_iterations > 0
        assert config.max_discovered_nodes > 0
        assert 0.0 <= config.default_edge_weight <= 1.0

        # Validation should pass
        config.validate()

    def test_pipeline_config_from_env(self):
        """Test PipelineConfig loads from environment."""
        config = PipelineConfig.from_env()

        assert 0.0 <= config.min_edge_weight <= 1.0
        assert 0.0 <= config.edge_weight_decay <= 1.0
        assert config.default_budget > 0

        # Validation should pass
        config.validate()


class TestConfigValidation:
    """Test configuration validation logic."""

    def test_cross_encoder_invalid_fallback_score(self):
        """Test validation fails for invalid fallback score."""
        config = CrossEncoderConfig(
            endpoint="http://localhost:8080",
            fallback_score=1.5  # Invalid: > 1.0
        )
        with pytest.raises(AssertionError):
            config.validate()

    def test_agent_invalid_default_scores(self):
        """Test validation fails for invalid default scores."""
        config = AgentConfig(default_importance=1.5)  # Invalid: > 1.0
        with pytest.raises(AssertionError):
            config.validate()

    def test_bidding_confidence_ordering(self):
        """Test validation enforces high > low confidence."""
        config = BiddingConfig(high_confidence=0.5, low_confidence=0.9)
        with pytest.raises(AssertionError):
            config.validate()


class TestGetAllConfigs:
    """Test bulk configuration loading."""

    def test_get_all_configs_returns_all_modules(self):
        """Test get_all_configs returns all 6 config modules."""
        configs = get_all_configs()

        assert "cross_encoder" in configs
        assert "agent" in configs
        assert "matrix" in configs
        assert "bidding" in configs
        assert "graph_builder" in configs
        assert "pipeline" in configs

        assert len(configs) == 6

    def test_all_configs_validate(self):
        """Test all loaded configs pass validation."""
        configs = get_all_configs()

        # Should not raise any exceptions
        for name, config in configs.items():
            config.validate()


class TestOverrideConfig:
    """Test configuration override for hyperparameter tuning."""

    def test_override_single_parameter(self):
        """Test overriding a single config parameter."""
        configs = get_all_configs()
        original_threshold = configs["matrix"].influence_threshold

        configs = override_config(configs, {
            "matrix.influence_threshold": 0.75
        })

        assert configs["matrix"].influence_threshold == 0.75
        assert configs["matrix"].influence_threshold != original_threshold

    def test_override_multiple_parameters(self):
        """Test overriding multiple config parameters."""
        configs = get_all_configs()

        configs = override_config(configs, {
            "agent.max_retries": 5,
            "matrix.influence_threshold": 0.7,
            "bidding.critical_dep_max_ratio": 0.6
        })

        assert configs["agent"].max_retries == 5
        assert configs["matrix"].influence_threshold == 0.7
        assert configs["bidding"].critical_dep_max_ratio == 0.6

    def test_override_invalid_module_raises(self):
        """Test override fails with invalid module name."""
        configs = get_all_configs()

        with pytest.raises(ValueError, match="Unknown config module"):
            override_config(configs, {"invalid_module.param": 123})

    def test_override_invalid_parameter_raises(self):
        """Test override fails with invalid parameter name."""
        configs = get_all_configs()

        with pytest.raises(ValueError, match="Unknown parameter"):
            override_config(configs, {"agent.invalid_param": 123})

    def test_override_validates_new_value(self):
        """Test override validates the new value."""
        configs = get_all_configs()

        # Should fail validation (influence_threshold > 1.0)
        with pytest.raises(ValueError, match="Invalid override"):
            override_config(configs, {"matrix.influence_threshold": 1.5})


class TestSettingsIntegration:
    """Test integration with existing Settings class."""

    def test_settings_has_config_properties(self):
        """Test Settings exposes config objects as properties."""
        assert hasattr(settings, "cross_encoder")
        assert hasattr(settings, "agent")
        assert hasattr(settings, "matrix")
        assert hasattr(settings, "bidding")
        assert hasattr(settings, "graph_builder")
        assert hasattr(settings, "pipeline")

    def test_settings_config_properties_are_typed(self):
        """Test config properties return correct types."""
        assert isinstance(settings.cross_encoder, CrossEncoderConfig)
        assert isinstance(settings.agent, AgentConfig)
        assert isinstance(settings.matrix, MatrixConfig)
        assert isinstance(settings.bidding, BiddingConfig)
        assert isinstance(settings.graph_builder, GraphBuilderConfig)
        assert isinstance(settings.pipeline, PipelineConfig)

    def test_settings_get_all_configs(self):
        """Test Settings.get_all_configs() method."""
        configs = settings.get_all_configs()

        assert len(configs) == 6
        assert "cross_encoder" in configs
        assert isinstance(configs["cross_encoder"], CrossEncoderConfig)

    def test_settings_export_config_dict(self):
        """Test Settings.export_config_dict() for serialization."""
        config_dict = settings.export_config_dict()

        assert isinstance(config_dict, dict)
        assert "cross_encoder" in config_dict
        assert isinstance(config_dict["cross_encoder"], dict)
        assert "endpoint" in config_dict["cross_encoder"]

    def test_settings_backward_compatibility(self):
        """Test legacy flat attributes still work."""
        # Old way should still work
        assert hasattr(settings, "OPENAI_API_KEY")
        assert hasattr(settings, "LLM_MODEL")
        assert hasattr(settings, "GRAPH_GAP_THRESHOLD")
        assert hasattr(settings, "CROSS_ENCODER_ENDPOINT")

        # New way should also work
        assert settings.cross_encoder.endpoint == settings.CROSS_ENCODER_ENDPOINT
        assert settings.graph_builder.gap_threshold == settings.GRAPH_GAP_THRESHOLD


class TestConfigUsagePatterns:
    """Test common usage patterns for configuration."""

    def test_accessing_nested_config(self):
        """Test accessing config parameters via settings."""
        # New structured way
        timeout = settings.cross_encoder.request_timeout
        max_retries = settings.agent.max_retries
        influence_threshold = settings.matrix.influence_threshold

        assert isinstance(timeout, float)
        assert isinstance(max_retries, int)
        assert isinstance(influence_threshold, float)

    def test_config_for_logging(self):
        """Test exporting config for logging/debugging."""
        config_snapshot = settings.export_config_dict()

        # Should be JSON-serializable
        import json
        json_str = json.dumps(config_snapshot, default=str)
        assert len(json_str) > 0

    def test_config_for_hyperparameter_tuning(self):
        """Test config override pattern for experiments."""
        # Get baseline config
        baseline = settings.get_all_configs()

        # Create experiment config
        experiment = override_config(baseline, {
            "matrix.influence_threshold": 0.7,
            "agent.max_retries": 5
        })

        # Baseline unchanged
        assert baseline["matrix"].influence_threshold != 0.7

        # Experiment has new values
        assert experiment["matrix"].influence_threshold == 0.7
        assert experiment["agent"].max_retries == 5
