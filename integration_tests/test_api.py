"""
REST API Tests for Florent Risk Analysis Service

Tests the Litestar HTTP endpoints:
- GET / (health check)
- POST /analyze (main analysis endpoint)

Test scenarios:
1. Health check endpoint availability
2. Analysis with file paths
3. Analysis with JSON data directly
4. Request validation (missing fields, invalid paths, etc.)
5. Error handling and response formats
6. Budget parameter handling
"""

import sys
import os
import unittest
import json
from unittest.mock import patch, MagicMock
from pathlib import Path

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from litestar.testing import TestClient
from src.main import app


class TestHealthCheckEndpoint(unittest.TestCase):
    """Test the GET / health check endpoint."""

    def setUp(self):
        """Set up test client."""
        self.client = TestClient(app=app)

    def test_health_check_returns_200(self):
        """Test that health check returns 200 OK."""
        response = self.client.get("/")
        self.assertEqual(response.status_code, 200)

    def test_health_check_message(self):
        """Test that health check returns correct message."""
        response = self.client.get("/")
        self.assertIn("Project Florent", response.text)
        self.assertIn("RUNNING", response.text)


class TestAnalyzeEndpointWithFilePaths(unittest.TestCase):
    """Test POST /analyze endpoint using file paths."""

    def setUp(self):
        """Set up test client and file paths."""
        self.client = TestClient(app=app)

        # Get absolute paths to POC data
        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        self.firm_path = str(poc_dir / "firm.json")
        self.project_path = str(poc_dir / "project.json")

        # Verify files exist
        self.assertTrue(os.path.exists(self.firm_path), f"firm.json not found at {self.firm_path}")
        self.assertTrue(os.path.exists(self.project_path), f"project.json not found at {self.project_path}")

        # Mock registries
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.mock_sectors = {"energy", "construction", "infrastructure"}
        self.mock_focuses = {"sustainability", "efficiency"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

    def tearDown(self):
        """Clean up patches."""
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    @patch('src.services.pipeline.run_analysis')
    def test_analyze_with_file_paths_success(self, mock_run_analysis):
        """Test successful analysis using file paths."""
        # Mock the analysis pipeline
        mock_run_analysis.return_value = {
            "node_assessments": {},
            "action_matrix": {
                "mitigate": [],
                "automate": [],
                "contingency": [],
                "delegate": ["node_1", "node_2"]
            },
            "critical_chains": [],
            "summary": {
                "overall_bankability": 0.75,
                "average_risk": 0.25,
                "critical_chains_detected": 0,
                "recommendations": []
            }
        }

        response = self.client.post(
            "/analyze",
            json={
                "firm_path": self.firm_path,
                "project_path": self.project_path,
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "success")
        self.assertIn("analysis", data)
        self.assertIn("message", data)

    def test_analyze_with_invalid_firm_path(self):
        """Test analysis with non-existent firm file."""
        response = self.client.post(
            "/analyze",
            json={
                "firm_path": "/nonexistent/firm.json",
                "project_path": self.project_path,
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "error")
        self.assertIn("File not found", data["message"])

    def test_analyze_with_invalid_project_path(self):
        """Test analysis with non-existent project file."""
        response = self.client.post(
            "/analyze",
            json={
                "firm_path": self.firm_path,
                "project_path": "/nonexistent/project.json",
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "error")
        self.assertIn("File not found", data["message"])

    @patch('src.services.agent.core.orchestrator.AgentOrchestrator.run_exploration')
    def test_analyze_with_default_budget(self, mock_exploration):
        """Test that budget defaults to 100 when not provided."""
        # Mock only the AI exploration to avoid API calls
        mock_exploration.return_value = {}

        response = self.client.post(
            "/analyze",
            json={
                "firm_path": self.firm_path,
                "project_path": self.project_path
                # No budget specified - should default to 100
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        # Should succeed with default budget
        self.assertEqual(data["status"], "success")


class TestAnalyzeEndpointWithJSONData(unittest.TestCase):
    """Test POST /analyze endpoint using direct JSON data."""

    def setUp(self):
        """Set up test client and load POC data."""
        self.client = TestClient(app=app)

        # Load POC data
        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        with open(poc_dir / "firm.json", "r") as f:
            self.firm_data = json.load(f)
        with open(poc_dir / "project.json", "r") as f:
            self.project_data = json.load(f)

        # Mock registries
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.mock_sectors = {"energy", "construction", "infrastructure"}
        self.mock_focuses = {"sustainability", "efficiency"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

    def tearDown(self):
        """Clean up patches."""
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    @patch('src.services.pipeline.run_analysis')
    def test_analyze_with_json_data_success(self, mock_run_analysis):
        """Test successful analysis using JSON data."""
        mock_run_analysis.return_value = {
            "node_assessments": {},
            "action_matrix": {"mitigate": [], "automate": [], "contingency": [], "delegate": []},
            "critical_chains": [],
            "summary": {"overall_bankability": 0.8, "average_risk": 0.2, "critical_chains_detected": 0, "recommendations": []}
        }

        response = self.client.post(
            "/analyze",
            json={
                "firm_data": self.firm_data,
                "project_data": self.project_data,
                "budget": 50
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "success")
        self.assertIn("analysis", data)

    def test_analyze_with_missing_data_and_path(self):
        """Test that request fails when neither data nor path is provided."""
        response = self.client.post(
            "/analyze",
            json={
                "budget": 100
                # No firm_data, firm_path, project_data, or project_path
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "error")
        self.assertIn("Missing data or path", data["message"])


class TestAnalyzeEndpointValidation(unittest.TestCase):
    """Test request validation and error handling."""

    def setUp(self):
        """Set up test client."""
        self.client = TestClient(app=app)

        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        self.firm_path = str(poc_dir / "firm.json")
        self.project_path = str(poc_dir / "project.json")

        # Mock registries
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.mock_sectors = {"energy", "construction", "infrastructure"}
        self.mock_focuses = {"sustainability", "efficiency"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

    def tearDown(self):
        """Clean up patches."""
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    def test_analyze_with_malformed_json_in_firm_data(self):
        """Test analysis with invalid JSON structure in firm_data."""
        response = self.client.post(
            "/analyze",
            json={
                "firm_data": {"invalid": "structure"},  # Missing required fields
                "project_data": {"also": "invalid"},
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "error")
        # Should fail during entity parsing

    @patch('src.services.agent.core.orchestrator.AgentOrchestrator.run_exploration')
    def test_analyze_with_custom_budget(self, mock_exploration):
        """Test that custom budget is passed correctly."""
        # Mock only the AI exploration to avoid API calls
        mock_exploration.return_value = {}

        custom_budget = 250
        response = self.client.post(
            "/analyze",
            json={
                "firm_path": self.firm_path,
                "project_path": self.project_path,
                "budget": custom_budget
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        # Should succeed with custom budget
        self.assertEqual(data["status"], "success")

    def test_analyze_empty_request(self):
        """Test analysis with completely empty request."""
        response = self.client.post(
            "/analyze",
            json={}
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "error")


class TestAnalyzeEndpointResponseStructure(unittest.TestCase):
    """Test response structure and data formats."""

    def setUp(self):
        """Set up test client."""
        self.client = TestClient(app=app)

        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        self.firm_path = str(poc_dir / "firm.json")
        self.project_path = str(poc_dir / "project.json")

        # Mock registries
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.mock_sectors = {"energy", "construction", "infrastructure"}
        self.mock_focuses = {"sustainability", "efficiency"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

    def tearDown(self):
        """Clean up patches."""
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    @patch('src.services.pipeline.run_analysis')
    def test_success_response_structure(self, mock_run_analysis):
        """Test that success response has correct structure."""
        mock_analysis = {
            "node_assessments": {"node_1": {"influence_score": 0.7, "risk_level": 0.3}},
            "action_matrix": {
                "mitigate": ["node_1"],
                "automate": [],
                "contingency": [],
                "delegate": []
            },
            "critical_chains": [
                {"nodes": ["node_1", "node_2"], "risk": 0.5}
            ],
            "summary": {
                "overall_bankability": 0.75,
                "average_risk": 0.25,
                "critical_chains_detected": 1,
                "recommendations": ["Test recommendation"]
            }
        }
        mock_run_analysis.return_value = mock_analysis

        response = self.client.post(
            "/analyze",
            json={
                "firm_path": self.firm_path,
                "project_path": self.project_path,
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()

        # Verify top-level structure
        self.assertIn("status", data)
        self.assertIn("message", data)
        self.assertIn("analysis", data)
        self.assertEqual(data["status"], "success")

        # Verify analysis structure
        analysis = data["analysis"]
        self.assertIn("node_assessments", analysis)
        self.assertIn("action_matrix", analysis)
        self.assertIn("critical_chains", analysis)
        self.assertIn("summary", analysis)

        # Verify action matrix has all quadrants
        matrix = analysis["action_matrix"]
        self.assertIn("mitigate", matrix)
        self.assertIn("automate", matrix)
        self.assertIn("contingency", matrix)
        self.assertIn("delegate", matrix)

        # Verify summary has required fields
        summary = analysis["summary"]
        self.assertIn("overall_bankability", summary)
        self.assertIn("average_risk", summary)
        self.assertIn("critical_chains_detected", summary)

    def test_error_response_structure(self):
        """Test that error response has correct structure."""
        response = self.client.post(
            "/analyze",
            json={
                "firm_path": "/invalid/path.json",
                "project_path": self.project_path,
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)
        data = response.json()

        # Verify error structure
        self.assertIn("status", data)
        self.assertIn("message", data)
        self.assertEqual(data["status"], "error")
        self.assertIsInstance(data["message"], str)
        self.assertGreater(len(data["message"]), 0)


class TestAnalyzeEndpointLogging(unittest.TestCase):
    """Test that API calls are properly logged."""

    def setUp(self):
        """Set up test client."""
        self.client = TestClient(app=app)

        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        self.firm_path = str(poc_dir / "firm.json")
        self.project_path = str(poc_dir / "project.json")

        # Mock registries
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.mock_sectors = {"energy", "construction", "infrastructure"}
        self.mock_focuses = {"sustainability", "efficiency"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

    def tearDown(self):
        """Clean up patches."""
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    @patch('src.main.logger')
    @patch('src.services.pipeline.run_analysis')
    def test_logging_on_success(self, mock_run_analysis, mock_logger):
        """Test that successful requests are logged."""
        mock_run_analysis.return_value = {
            "node_assessments": {},
            "action_matrix": {"mitigate": [], "automate": [], "contingency": [], "delegate": []},
            "critical_chains": [],
            "summary": {"overall_bankability": 0.5, "average_risk": 0.5, "critical_chains_detected": 0, "recommendations": []}
        }

        response = self.client.post(
            "/analyze",
            json={
                "firm_path": self.firm_path,
                "project_path": self.project_path,
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)

        # Verify logging calls were made
        self.assertTrue(mock_logger.info.called)

        # Check for expected log events
        log_calls = [call[0][0] for call in mock_logger.info.call_args_list]
        self.assertIn("analysis_request_received", log_calls)
        self.assertIn("data_loaded", log_calls)
        self.assertIn("entities_parsed", log_calls)
        self.assertIn("analysis_complete", log_calls)

    @patch('src.main.logger')
    def test_logging_on_error(self, mock_logger):
        """Test that errors are logged."""
        response = self.client.post(
            "/analyze",
            json={
                "firm_path": "/nonexistent.json",
                "project_path": self.project_path,
                "budget": 100
            }
        )

        self.assertEqual(response.status_code, 201)

        # Verify error logging
        mock_logger.error.assert_called()
        error_call = mock_logger.error.call_args
        self.assertEqual(error_call[0][0], "analysis_failed")


class TestAnalyzeEndpointIntegration(unittest.TestCase):
    """Integration tests for the full API pipeline (without mocking pipeline)."""

    def setUp(self):
        """Set up test client."""
        self.client = TestClient(app=app)

        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        self.firm_path = str(poc_dir / "firm.json")
        self.project_path = str(poc_dir / "project.json")

        # Mock registries
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.mock_sectors = {"energy", "construction", "infrastructure"}
        self.mock_focuses = {"sustainability", "efficiency"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

    def tearDown(self):
        """Clean up patches."""
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    @patch('src.services.agent.core.orchestrator.AgentOrchestrator.run_exploration')
    def test_full_pipeline_integration(self, mock_exploration):
        """Test complete pipeline from HTTP request to response."""
        # Mock only the AI agent exploration (to avoid API calls)
        # Return empty dict - orchestrator will use fallback values
        mock_exploration.return_value = {}

        response = self.client.post(
            "/analyze",
            json={
                "firm_path": self.firm_path,
                "project_path": self.project_path,
                "budget": 100
            }
        )

        # Should succeed and return analysis
        self.assertEqual(response.status_code, 201)
        data = response.json()
        self.assertEqual(data["status"], "success")

        # Verify we got real analysis data
        self.assertIn("analysis", data)
        analysis = data["analysis"]

        # Check that all components are present
        self.assertIn("summary", analysis)
        summary = analysis["summary"]

        # Verify summary has numeric values
        if "overall_bankability" in summary:
            self.assertIsInstance(summary["overall_bankability"], (int, float))
            self.assertGreaterEqual(summary["overall_bankability"], 0)
            self.assertLessEqual(summary["overall_bankability"], 1)


class TestEndpointEdgeCases(unittest.TestCase):
    """Test edge cases and boundary conditions."""

    def setUp(self):
        """Set up test client."""
        self.client = TestClient(app=app)

    def test_analyze_with_zero_budget(self):
        """Test analysis with budget=0."""
        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        firm_path = str(poc_dir / "firm.json")
        project_path = str(poc_dir / "project.json")

        with patch('src.services.pipeline.run_analysis') as mock_run_analysis:
            mock_run_analysis.return_value = {
                "node_assessments": {},
                "action_matrix": {"mitigate": [], "automate": [], "contingency": [], "delegate": []},
                "critical_chains": [],
                "summary": {"overall_bankability": 0, "average_risk": 1, "critical_chains_detected": 0, "recommendations": []}
            }

            response = self.client.post(
                "/analyze",
                json={
                    "firm_path": firm_path,
                    "project_path": project_path,
                    "budget": 0
                }
            )

            # Should handle gracefully
            self.assertEqual(response.status_code, 201)

    def test_analyze_with_negative_budget(self):
        """Test analysis with negative budget."""
        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        firm_path = str(poc_dir / "firm.json")
        project_path = str(poc_dir / "project.json")

        response = self.client.post(
            "/analyze",
            json={
                "firm_path": firm_path,
                "project_path": project_path,
                "budget": -10
            }
        )

        # Should either error or handle gracefully
        self.assertEqual(response.status_code, 201)

    def test_analyze_with_very_large_budget(self):
        """Test analysis with extremely large budget."""
        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"
        firm_path = str(poc_dir / "firm.json")
        project_path = str(poc_dir / "project.json")

        with patch('src.services.pipeline.run_analysis') as mock_run_analysis:
            mock_run_analysis.return_value = {
                "node_assessments": {},
                "action_matrix": {"mitigate": [], "automate": [], "contingency": [], "delegate": []},
                "critical_chains": [],
                "summary": {"overall_bankability": 1, "average_risk": 0, "critical_chains_detected": 0, "recommendations": []}
            }

            response = self.client.post(
                "/analyze",
                json={
                    "firm_path": firm_path,
                    "project_path": project_path,
                    "budget": 999999
                }
            )

            self.assertEqual(response.status_code, 201)


if __name__ == '__main__':
    unittest.main(verbosity=2)
