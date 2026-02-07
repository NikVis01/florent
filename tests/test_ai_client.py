import sys
import os
import unittest
from unittest.mock import patch, MagicMock

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))


class TestAIClient(unittest.TestCase):
    """Test AIClient and DSPy initialization."""

    @patch.dict(os.environ, {'OPENAI_API_KEY': 'test-api-key-12345'})
    @patch('dspy.LM')
    @patch('dspy.configure')
    def test_init_dspy_success(self, mock_configure, mock_openai):
        """Test successful DSPy initialization."""
        from src.services.clients.ai_client import init_dspy

        mock_lm = MagicMock()
        mock_openai.return_value = mock_lm

        result = init_dspy()

        mock_openai.assert_called_once_with(model="gpt-4o-mini", api_key='test-api-key-12345')
        mock_configure.assert_called_once_with(lm=mock_lm)
        self.assertEqual(result, mock_lm)

    @patch.dict(os.environ, {}, clear=True)
    def test_init_dspy_missing_api_key(self):
        """Test DSPy initialization without API key."""
        from src.services.clients.ai_client import init_dspy

        with self.assertRaises(ValueError) as context:
            init_dspy()

        self.assertIn("OPENAI_API_KEY not found", str(context.exception))

    @patch.dict(os.environ, {'OPENAI_API_KEY': ''})
    def test_init_dspy_empty_api_key(self):
        """Test DSPy initialization with empty API key."""
        from src.services.clients.ai_client import init_dspy

        with self.assertRaises(ValueError) as context:
            init_dspy()

        self.assertIn("OPENAI_API_KEY not found", str(context.exception))

    @patch.dict(os.environ, {'OPENAI_API_KEY': 'test-api-key'})
    @patch('dspy.LM')
    @patch('dspy.configure')
    def test_ai_client_initialization(self, mock_configure, mock_openai):
        """Test AIClient initialization."""
        from src.services.clients.ai_client import AIClient

        mock_lm = MagicMock()
        mock_openai.return_value = mock_lm

        client = AIClient()

        self.assertIsNotNone(client.lm)
        self.assertEqual(client.lm, mock_lm)

    @patch.dict(os.environ, {'OPENAI_API_KEY': 'test-api-key'})
    @patch('dspy.LM')
    @patch('dspy.configure')
    def test_ai_client_get_lm(self, mock_configure, mock_openai):
        """Test AIClient get_lm method."""
        from src.services.clients.ai_client import AIClient

        mock_lm = MagicMock()
        mock_openai.return_value = mock_lm

        client = AIClient()
        result = client.get_lm()

        self.assertEqual(result, mock_lm)

    @patch.dict(os.environ, {'OPENAI_API_KEY': 'test-api-key'})
    @patch('dspy.LM')
    @patch('dspy.configure')
    def test_multiple_ai_client_instances(self, mock_configure, mock_openai):
        """Test creating multiple AIClient instances."""
        from src.services.clients.ai_client import AIClient

        mock_lm1 = MagicMock()
        mock_lm2 = MagicMock()
        mock_openai.side_effect = [mock_lm1, mock_lm2]

        client1 = AIClient()
        client2 = AIClient()

        # Both should have been initialized
        self.assertIsNotNone(client1.lm)
        self.assertIsNotNone(client2.lm)

    @patch.dict(os.environ, {'OPENAI_API_KEY': 'test-api-key'})
    @patch('dspy.LM', side_effect=Exception("OpenAI initialization failed"))
    @patch('dspy.configure')
    def test_ai_client_initialization_failure(self, mock_configure, mock_openai):
        """Test AIClient initialization failure."""
        from src.services.clients.ai_client import AIClient

        with self.assertRaises(Exception) as context:
            AIClient()

        self.assertIn("OpenAI initialization failed", str(context.exception))

    @patch.dict(os.environ, {'OPENAI_API_KEY': 'test-key'})
    @patch('dspy.LM')
    @patch('dspy.configure')
    def test_correct_model_used(self, mock_configure, mock_openai):
        """Test that correct model is specified."""
        from src.services.clients.ai_client import init_dspy

        mock_lm = MagicMock()
        mock_openai.return_value = mock_lm

        init_dspy()

        # Verify gpt-4o-mini was used
        call_kwargs = mock_openai.call_args[1]
        self.assertEqual(call_kwargs['model'], 'gpt-4o-mini')


class TestAIClientDotenv(unittest.TestCase):
    """Test dotenv loading in AI client."""

    @patch('dotenv.load_dotenv')
    def test_load_dotenv_called(self, mock_load_dotenv):
        """Test that load_dotenv is called on import."""
        # Clear the module from cache
        if 'src.services.clients.ai_client' in sys.modules:
            del sys.modules['src.services.clients.ai_client']

        # Import should trigger load_dotenv
        import src.services.clients.ai_client

        mock_load_dotenv.assert_called()


if __name__ == '__main__':
    unittest.main()
