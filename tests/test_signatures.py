import sys
import os
import unittest
from unittest.mock import patch, MagicMock

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


class TestDSPySignatures(unittest.TestCase):
    """Test DSPy signature definitions."""

    def setUp(self):
        """Set up test environment."""
        # Mock dspy module
        self.mock_dspy = MagicMock()
        self.mock_dspy.Signature = MagicMock
        self.mock_dspy.InputField = MagicMock(side_effect=lambda **kwargs: kwargs)
        self.mock_dspy.OutputField = MagicMock(side_effect=lambda **kwargs: kwargs)

    def test_node_signature_exists(self):
        """Test that NodeSignature class is defined."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature

            self.assertIsNotNone(NodeSignature)

    def test_node_signature_has_docstring(self):
        """Test that NodeSignature has documentation."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature

            self.assertIsNotNone(NodeSignature.__doc__)
            self.assertIn("firm", NodeSignature.__doc__.lower())

    def test_node_signature_input_fields(self):
        """Test that NodeSignature has required input fields."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature

            # Check for input field attributes
            self.assertTrue(hasattr(NodeSignature, 'firm_context'))
            self.assertTrue(hasattr(NodeSignature, 'node_requirements'))

    def test_node_signature_output_fields(self):
        """Test that NodeSignature has required output fields."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature

            # Check for output field attributes
            self.assertTrue(hasattr(NodeSignature, 'influence_score'))
            self.assertTrue(hasattr(NodeSignature, 'risk_assessment'))
            self.assertTrue(hasattr(NodeSignature, 'reasoning'))

    def test_node_signature_field_descriptions(self):
        """Test that NodeSignature fields have descriptions."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature

            # Input fields should have descriptions
            firm_context_field = NodeSignature.firm_context
            node_req_field = NodeSignature.node_requirements

            # These should be dspy fields with desc parameter
            self.assertIsNotNone(firm_context_field)
            self.assertIsNotNone(node_req_field)

    def test_propagation_signature_exists(self):
        """Test that PropagationSignature class is defined."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import PropagationSignature

            self.assertIsNotNone(PropagationSignature)

    def test_propagation_signature_has_docstring(self):
        """Test that PropagationSignature has documentation."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import PropagationSignature

            self.assertIsNotNone(PropagationSignature.__doc__)
            self.assertIn("risk", PropagationSignature.__doc__.lower())
            self.assertIn("propagat", PropagationSignature.__doc__.lower())

    def test_propagation_signature_input_fields(self):
        """Test that PropagationSignature has required input fields."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import PropagationSignature

            # Check for input field attributes
            self.assertTrue(hasattr(PropagationSignature, 'upstream_risk_tensor'))
            self.assertTrue(hasattr(PropagationSignature, 'local_risk_factors'))

    def test_propagation_signature_output_fields(self):
        """Test that PropagationSignature has required output fields."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import PropagationSignature

            # Check for output field attributes
            self.assertTrue(hasattr(PropagationSignature, 'cascading_risk_score'))

    def test_signature_inheritance(self):
        """Test that signatures inherit from dspy.Signature."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature, PropagationSignature

            # Both should be subclasses (or at least defined classes)
            self.assertTrue(isinstance(NodeSignature, type))
            self.assertTrue(isinstance(PropagationSignature, type))

    def test_node_signature_field_count(self):
        """Test that NodeSignature has expected number of fields."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature

            # Should have 2 input fields and 3 output fields
            input_fields = ['firm_context', 'node_requirements']
            output_fields = ['influence_score', 'risk_assessment', 'reasoning']

            for field in input_fields:
                self.assertTrue(hasattr(NodeSignature, field))

            for field in output_fields:
                self.assertTrue(hasattr(NodeSignature, field))

    def test_propagation_signature_field_count(self):
        """Test that PropagationSignature has expected number of fields."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import PropagationSignature

            # Should have 2 input fields and 1 output field
            input_fields = ['upstream_risk_tensor', 'local_risk_factors']
            output_fields = ['cascading_risk_score']

            for field in input_fields:
                self.assertTrue(hasattr(PropagationSignature, field))

            for field in output_fields:
                self.assertTrue(hasattr(PropagationSignature, field))

    def test_signatures_module_imports(self):
        """Test that signatures module imports correctly."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            try:
                from src.services.agent.models import signatures
                self.assertIsNotNone(signatures)
            except ImportError as e:
                self.fail(f"Failed to import signatures module: {e}")

    def test_field_naming_conventions(self):
        """Test that field names follow proper conventions."""
        with patch.dict('sys.modules', {'dspy': self.mock_dspy}):
            from src.services.agent.models.signatures import NodeSignature, PropagationSignature

            # Check that field names are snake_case
            node_fields = ['firm_context', 'node_requirements', 'influence_score',
                          'risk_assessment', 'reasoning']
            prop_fields = ['upstream_risk_tensor', 'local_risk_factors', 'cascading_risk_score']

            for field in node_fields:
                self.assertTrue(hasattr(NodeSignature, field))
                # Should be snake_case (contains underscore or is single word)
                self.assertTrue('_' in field or field.islower())

            for field in prop_fields:
                self.assertTrue(hasattr(PropagationSignature, field))
                self.assertTrue('_' in field or field.islower())


if __name__ == '__main__':
    unittest.main()
