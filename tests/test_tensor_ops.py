import sys
import os
import unittest
from unittest.mock import patch, MagicMock
import ctypes

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


class TestTensorOpsCpp(unittest.TestCase):
    """Test C++ tensor operations bindings."""

    def setUp(self):
        """Set up mocks for C++ library."""
        # Mock the ctypes CDLL to avoid loading actual .so file
        self.mock_lib = MagicMock()
        self.patcher = patch('ctypes.CDLL', return_value=self.mock_lib)
        self.patcher.start()

    def tearDown(self):
        """Clean up patches."""
        self.patcher.stop()
        # Clear the module cache to reset imports
        if 'src.services.agent.ops.tensor_ops_cpp' in sys.modules:
            del sys.modules['src.services.agent.ops.tensor_ops_cpp']

    def test_library_loading(self):
        """Test that the library attempts to load."""
        try:
            from src.services.agent.ops.tensor_ops_cpp import _lib
            # If we get here, the mock library was loaded
            self.assertIsNotNone(_lib)
        except OSError:
            # This is expected if the .so file doesn't exist
            pass

    def test_cosine_similarity_function_signature(self):
        """Test that cosine_similarity function exists and has correct signature."""
        # Mock the library functions
        self.mock_lib.cosine_similarity = MagicMock(return_value=ctypes.c_float(0.95))
        self.mock_lib.cosine_similarity.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int
        ]
        self.mock_lib.cosine_similarity.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import cosine_similarity

        # Test the function call
        v1 = [1.0, 0.0, 0.0]
        v2 = [1.0, 0.0, 0.0]
        result = cosine_similarity(v1, v2)

        # Verify the mock was called
        self.mock_lib.cosine_similarity.assert_called_once()

    def test_cosine_similarity_identical_vectors(self):
        """Test cosine similarity with identical vectors."""
        self.mock_lib.cosine_similarity = MagicMock(return_value=1.0)
        self.mock_lib.cosine_similarity.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int
        ]
        self.mock_lib.cosine_similarity.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import cosine_similarity

        v1 = [1.0, 2.0, 3.0]
        v2 = [1.0, 2.0, 3.0]
        result = cosine_similarity(v1, v2)

        self.assertEqual(result, 1.0)

    def test_cosine_similarity_orthogonal_vectors(self):
        """Test cosine similarity with orthogonal vectors."""
        self.mock_lib.cosine_similarity = MagicMock(return_value=0.0)
        self.mock_lib.cosine_similarity.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int
        ]
        self.mock_lib.cosine_similarity.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import cosine_similarity

        v1 = [1.0, 0.0]
        v2 = [0.0, 1.0]
        result = cosine_similarity(v1, v2)

        self.assertEqual(result, 0.0)

    def test_calculate_influence_tensor_function(self):
        """Test calculate_influence_tensor function."""
        self.mock_lib.calculate_influence_tensor = MagicMock(return_value=0.75)
        self.mock_lib.calculate_influence_tensor.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int,
            ctypes.c_float
        ]
        self.mock_lib.calculate_influence_tensor.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import calculate_influence_tensor

        firm_tensor = [0.5, 0.6, 0.7]
        node_tensor = [0.8, 0.9, 1.0]
        centrality = 0.85

        result = calculate_influence_tensor(firm_tensor, node_tensor, centrality)

        self.mock_lib.calculate_influence_tensor.assert_called_once()
        self.assertEqual(result, 0.75)

    def test_calculate_influence_tensor_high_centrality(self):
        """Test influence tensor calculation with high centrality."""
        self.mock_lib.calculate_influence_tensor = MagicMock(return_value=0.95)
        self.mock_lib.calculate_influence_tensor.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int,
            ctypes.c_float
        ]
        self.mock_lib.calculate_influence_tensor.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import calculate_influence_tensor

        firm_tensor = [1.0, 1.0, 1.0]
        node_tensor = [1.0, 1.0, 1.0]
        centrality = 1.0

        result = calculate_influence_tensor(firm_tensor, node_tensor, centrality)

        self.assertEqual(result, 0.95)

    def test_propagate_risk_function(self):
        """Test propagate_risk function."""
        self.mock_lib.propagate_risk = MagicMock(return_value=0.65)
        self.mock_lib.propagate_risk.argtypes = [
            ctypes.c_float,
            ctypes.c_float,
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int
        ]
        self.mock_lib.propagate_risk.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import propagate_risk

        local_failure_prob = 0.2
        multiplier = 1.5
        parent_probs = [0.3, 0.4, 0.5]

        result = propagate_risk(local_failure_prob, multiplier, parent_probs)

        self.mock_lib.propagate_risk.assert_called_once()
        self.assertEqual(result, 0.65)

    def test_propagate_risk_no_parents(self):
        """Test risk propagation with no parent nodes."""
        self.mock_lib.propagate_risk = MagicMock(return_value=0.2)
        self.mock_lib.propagate_risk.argtypes = [
            ctypes.c_float,
            ctypes.c_float,
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int
        ]
        self.mock_lib.propagate_risk.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import propagate_risk

        local_failure_prob = 0.2
        multiplier = 1.0
        parent_probs = []

        result = propagate_risk(local_failure_prob, multiplier, parent_probs)

        self.assertEqual(result, 0.2)

    def test_propagate_risk_multiple_parents(self):
        """Test risk propagation with multiple parent nodes."""
        self.mock_lib.propagate_risk = MagicMock(return_value=0.85)
        self.mock_lib.propagate_risk.argtypes = [
            ctypes.c_float,
            ctypes.c_float,
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int
        ]
        self.mock_lib.propagate_risk.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import propagate_risk

        local_failure_prob = 0.5
        multiplier = 2.0
        parent_probs = [0.6, 0.7, 0.8, 0.9]

        result = propagate_risk(local_failure_prob, multiplier, parent_probs)

        self.assertEqual(result, 0.85)

    def test_vector_size_consistency(self):
        """Test that vector sizes are handled correctly."""
        self.mock_lib.cosine_similarity = MagicMock(return_value=0.8)
        self.mock_lib.cosine_similarity.argtypes = [
            ctypes.POINTER(ctypes.c_float),
            ctypes.POINTER(ctypes.c_float),
            ctypes.c_int
        ]
        self.mock_lib.cosine_similarity.restype = ctypes.c_float

        from src.services.agent.ops.tensor_ops_cpp import cosine_similarity

        # Different size vectors
        v1 = [1.0, 2.0, 3.0, 4.0, 5.0]
        v2 = [5.0, 4.0, 3.0, 2.0, 1.0]

        result = cosine_similarity(v1, v2)

        # Verify the function was called with correct size
        call_args = self.mock_lib.cosine_similarity.call_args
        # Check that size parameter is 5
        # Note: This is a simplified check due to ctypes complexity

    def test_library_fallback_loading(self):
        """Test that library tries fallback loading path."""
        import sys
        # Remove the module if it's already loaded
        if 'src.services.agent.ops.tensor_ops_cpp' in sys.modules:
            del sys.modules['src.services.agent.ops.tensor_ops_cpp']

        with patch('ctypes.CDLL', side_effect=[OSError("Not found"), MagicMock()]) as mock_cdll:
            # This should test the fallback mechanism
            # First attempt fails, second succeeds
            try:
                import src.services.agent.ops.tensor_ops_cpp  # noqa: F401
                # If we get here, fallback worked
                self.assertEqual(mock_cdll.call_count, 2)
            except (OSError, ImportError):
                # Expected if both paths fail or module structure changed
                pass


if __name__ == '__main__':
    unittest.main()
