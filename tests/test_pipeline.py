"""
Tests for the complete analysis pipeline.

Tests the end-to-end flow from firm/project data through analysis output.
"""

import sys
import os
import unittest
from unittest.mock import patch, MagicMock

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.base import OperationType, Country, Sectors, StrategicFocus
from src.models.entities import Firm, Project, ProjectEntry, ProjectExit
from src.models.graph import Graph, Node, Edge
from src.services.pipeline import (
    build_infrastructure_graph,
    propagate_risk,
    detect_critical_chains,
    run_analysis
)
from src.services.agent.core.orchestrator import NodeAssessment


class TestBuildInfrastructureGraph(unittest.TestCase):
    """Test infrastructure graph construction."""

    def setUp(self):
        """Set up test environment."""
        self.mock_categories = {"financing", "equipment"}
        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.cat_patcher.start()

    def tearDown(self):
        self.cat_patcher.stop()

    def test_build_graph_from_project(self):
        """Test building graph from project with entry/exit criteria."""
        country = Country(
            name="Brazil",
            a2="BR",
            a3="BRA",
            num="076",
            region="Americas",
            sub_region="South America",
            affiliations=["BRICS"]
        )

        op1 = OperationType(name="Financing", category="financing", description="Capital mobilization")
        op2 = OperationType(name="Equipment", category="equipment", description="Equipment procurement")

        entry = ProjectEntry(
            pre_requisites=["Permit approved"],
            mobilization_time=6,
            entry_node_id="node_entry"
        )

        exit_criteria = ProjectExit(
            success_metrics=["Uptime > 99%"],
            mandate_end_date="2029-12-31",
            exit_node_id="node_exit"
        )

        project = Project(
            id="proj_001",
            name="Test Project",
            description="Test project",
            country=country,
            sector="energy",
            service_requirements=["financing"],
            timeline=36,
            ops_requirements=[op1, op2],
            entry_criteria=entry,
            success_criteria=exit_criteria
        )

        graph = build_infrastructure_graph(project)

        # Verify graph structure
        self.assertGreater(len(graph.nodes), 0)
        self.assertGreater(len(graph.edges), 0)

        # Verify entry and exit nodes exist
        node_ids = {node.id for node in graph.nodes}
        self.assertIn("node_entry", node_ids)
        self.assertIn("node_exit", node_ids)

    def test_build_graph_without_criteria_fails(self):
        """Test that building graph without entry/exit criteria fails."""
        country = Country(
            name="Brazil",
            a2="BR",
            a3="BRA",
            num="076",
            region="Americas",
            sub_region="South America",
            affiliations=[]
        )

        project = Project(
            id="proj_002",
            name="Incomplete Project",
            description="Missing criteria",
            country=country,
            sector="energy",
            service_requirements=["financing"],
            timeline=24,
            ops_requirements=[],
            entry_criteria=None,
            success_criteria=None
        )

        with self.assertRaises(ValueError):
            build_infrastructure_graph(project)


class TestRiskPropagation(unittest.TestCase):
    """Test risk propagation through graph."""

    def setUp(self):
        """Set up test environment."""
        self.mock_categories = {"test"}
        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.cat_patcher.start()

    def tearDown(self):
        self.cat_patcher.stop()

    def test_risk_propagates_downstream(self):
        """Test that risk propagates from upstream to downstream nodes."""
        op_type = OperationType(name="Test", category="test", description="Test")

        node_a = Node(id="A", name="Node A", type=op_type, embedding=[0.1])
        node_b = Node(id="B", name="Node B", type=op_type, embedding=[0.2])
        node_c = Node(id="C", name="Node C", type=op_type, embedding=[0.3])

        graph = Graph(
            nodes=[node_a, node_b, node_c],
            edges=[
                Edge(source=node_a, target=node_b, weight=0.8, relationship="prerequisite"),
                Edge(source=node_b, target=node_c, weight=0.7, relationship="prerequisite")
            ]
        )

        # High risk at entry node
        assessments = {
            "A": NodeAssessment(0.5, 0.9, "High risk entry"),
            "B": NodeAssessment(0.5, 0.5, "Medium risk"),
            "C": NodeAssessment(0.5, 0.3, "Low risk")
        }

        propagated = propagate_risk(graph, assessments)

        # Verify risk exists for all nodes
        self.assertIn("A", propagated)
        self.assertIn("B", propagated)
        self.assertIn("C", propagated)

        # Entry node should have its local risk
        self.assertAlmostEqual(propagated["A"], 0.9, places=1)

        # Downstream nodes should have compounded risk
        self.assertGreater(propagated["B"], assessments["B"].risk_level)


class TestCriticalChainDetection(unittest.TestCase):
    """Test critical chain detection."""

    def setUp(self):
        """Set up test environment."""
        self.mock_categories = {"test"}
        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.cat_patcher.start()

    def tearDown(self):
        self.cat_patcher.stop()

    def test_detect_high_risk_chain(self):
        """Test detection of high-risk dependency chains."""
        op_type = OperationType(name="Test", category="test", description="Test")

        node_a = Node(id="A", name="Node A", type=op_type, embedding=[0.1])
        node_b = Node(id="B", name="Node B", type=op_type, embedding=[0.2])

        graph = Graph(
            nodes=[node_a, node_b],
            edges=[
                Edge(source=node_a, target=node_b, weight=0.9, relationship="critical")
            ]
        )

        # High propagated risk
        propagated_risk = {
            "A": 0.8,
            "B": 0.9
        }

        chains = detect_critical_chains(graph, propagated_risk, threshold=0.6)

        # Should detect critical chain
        self.assertGreater(len(chains), 0)
        self.assertIn("A", chains[0]["nodes"])
        self.assertIn("B", chains[0]["nodes"])

    def test_no_chains_when_low_risk(self):
        """Test that low-risk paths are not flagged as critical."""
        op_type = OperationType(name="Test", category="test", description="Test")

        node_a = Node(id="A", name="Node A", type=op_type, embedding=[0.1])
        node_b = Node(id="B", name="Node B", type=op_type, embedding=[0.2])

        graph = Graph(
            nodes=[node_a, node_b],
            edges=[
                Edge(source=node_a, target=node_b, weight=0.5, relationship="optional")
            ]
        )

        # Low propagated risk
        propagated_risk = {
            "A": 0.3,
            "B": 0.4
        }

        chains = detect_critical_chains(graph, propagated_risk, threshold=0.6)

        # Should not detect critical chains
        self.assertEqual(len(chains), 0)


class TestCompleteAnalysisPipeline(unittest.TestCase):
    """Test the complete run_analysis pipeline."""

    def setUp(self):
        """Set up test environment."""
        self.mock_categories = {"financing", "equipment"}
        self.mock_sectors = {"energy"}
        self.mock_focuses = {"sustainability"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

    def tearDown(self):
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    @patch('src.services.agent.core.orchestrator.AgentOrchestrator.run_exploration')
    def test_run_analysis_pipeline(self, mock_exploration):
        """Test the complete analysis pipeline."""
        # Mock exploration results
        mock_assessments = {
            "node_entry": NodeAssessment(0.7, 0.5, "Entry assessment"),
            "node_financing_0": NodeAssessment(0.8, 0.7, "Financing assessment"),
            "node_equipment_1": NodeAssessment(0.6, 0.6, "Equipment assessment"),
            "node_exit": NodeAssessment(0.5, 0.4, "Exit assessment")
        }
        mock_exploration.return_value = mock_assessments

        # Create firm
        country = Country(
            name="Brazil",
            a2="BR",
            a3="BRA",
            num="076",
            region="Americas",
            sub_region="South America",
            affiliations=["BRICS"]
        )

        sector = Sectors(name="Energy", description="energy")
        focus = StrategicFocus(name="Sustainability", description="sustainability")

        op_finance = OperationType(name="Financing", category="financing", description="Capital")
        op_equipment = OperationType(name="Equipment", category="equipment", description="Procurement")

        firm = Firm(
            id="firm_001",
            name="Test Firm",
            description="Test firm",
            countries_active=[country],
            sectors=[sector],
            services=[op_finance, op_equipment],
            strategic_focuses=[focus],
            prefered_project_timeline=48
        )

        # Create project
        entry = ProjectEntry(
            pre_requisites=["Permit"],
            mobilization_time=6,
            entry_node_id="node_entry"
        )

        exit_criteria = ProjectExit(
            success_metrics=["Uptime"],
            mandate_end_date="2029-12-31",
            exit_node_id="node_exit"
        )

        project = Project(
            id="proj_001",
            name="Test Project",
            description="Test project",
            country=country,
            sector="energy",
            service_requirements=["financing", "equipment"],
            timeline=36,
            ops_requirements=[op_finance, op_equipment],
            entry_criteria=entry,
            success_criteria=exit_criteria
        )

        # Run analysis
        result = run_analysis(firm, project, budget=50)

        # Verify output structure
        self.assertIn("node_assessments", result)
        self.assertIn("action_matrix", result)
        self.assertIn("critical_chains", result)
        self.assertIn("summary", result)

        # Verify summary contains expected keys
        summary = result["summary"]
        self.assertIn("firm_id", summary)
        self.assertIn("project_id", summary)
        self.assertIn("overall_bankability", summary)
        self.assertIn("average_risk", summary)
        self.assertIn("recommendations", summary)

        self.assertEqual(summary["firm_id"], "firm_001")
        self.assertEqual(summary["project_id"], "proj_001")

        # Verify action matrix has all quadrants
        matrix = result["action_matrix"]
        self.assertIn("mitigate", matrix)
        self.assertIn("automate", matrix)
        self.assertIn("contingency", matrix)
        self.assertIn("delegate", matrix)


if __name__ == '__main__':
    unittest.main(verbosity=2)
