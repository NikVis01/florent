import sys
import os
import unittest
from unittest.mock import patch
from pydantic import ValidationError

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.entities import (
    Firm, ProjectEntry, ProjectExit, Project, RiskProfile,
    CriticalChain, PivotalNode, AnalysisOutput
)
from src.models.base import OperationType, Sectors, StrategicFocus, Country


class TestFirm(unittest.TestCase):
    """Test Firm model."""

    def setUp(self):
        """Set up common test data."""
        self.country = Country(
            name="USA",
            a2="US",
            a3="USA",
            num="840",
            region="Americas",
            sub_region="Northern America"
        )

        # Mock registries
        self.mock_categories = {"transportation"}
        self.mock_sectors = {"logistics"}
        self.mock_focuses = {"efficiency"}

        self.category_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sector_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.focus_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.category_patcher.start()
        self.sector_patcher.start()
        self.focus_patcher.start()

        self.operation_type = OperationType(
            name="Freight",
            category="transportation",
            description="Freight transport"
        )
        self.sector = Sectors(
            name="Logistics",
            description="logistics"
        )
        self.focus = StrategicFocus(
            name="Efficiency",
            description="efficiency"
        )

    def tearDown(self):
        self.category_patcher.stop()
        self.sector_patcher.stop()
        self.focus_patcher.stop()

    def test_valid_firm(self):
        """Test creating a valid Firm."""
        firm = Firm(
            id="FIRM001",
            name="Test Logistics Corp",
            description="A test logistics firm",
            countries_active=[self.country],
            sectors=[self.sector],
            services=[self.operation_type],
            strategic_focuses=[self.focus],
            prefered_project_timeline=12,
            embedding=[0.1, 0.2, 0.3]
        )
        self.assertEqual(firm.id, "FIRM001")
        self.assertEqual(firm.name, "Test Logistics Corp")
        self.assertEqual(len(firm.countries_active), 1)
        self.assertEqual(len(firm.embedding), 3)

    def test_firm_with_default_embedding(self):
        """Test creating Firm with default empty embedding."""
        firm = Firm(
            id="FIRM002",
            name="No Embedding Corp",
            description="Test firm without embedding",
            countries_active=[self.country],
            sectors=[self.sector],
            services=[self.operation_type],
            strategic_focuses=[self.focus],
            prefered_project_timeline=6
        )
        self.assertEqual(len(firm.embedding), 0)

    def test_firm_missing_required_fields(self):
        """Test creating Firm with missing required fields."""
        with self.assertRaises(ValidationError):
            Firm(
                id="INCOMPLETE",
                name="Incomplete Firm"
            )

    def test_firm_multiple_countries(self):
        """Test Firm with multiple active countries."""
        country2 = Country(
            name="Canada",
            a2="CA",
            a3="CAN",
            num="124",
            region="Americas",
            sub_region="Northern America"
        )
        firm = Firm(
            id="FIRM003",
            name="Multi-Country Corp",
            description="Operating in multiple countries",
            countries_active=[self.country, country2],
            sectors=[self.sector],
            services=[self.operation_type],
            strategic_focuses=[self.focus],
            prefered_project_timeline=24
        )
        self.assertEqual(len(firm.countries_active), 2)


class TestProjectEntry(unittest.TestCase):
    """Test ProjectEntry model."""

    def test_valid_project_entry(self):
        """Test creating a valid ProjectEntry."""
        entry = ProjectEntry(
            pre_requisites=["Approval", "Funding"],
            mobilization_time=3,
            entry_node_id="NODE_START"
        )
        self.assertEqual(len(entry.pre_requisites), 2)
        self.assertEqual(entry.mobilization_time, 3)
        self.assertEqual(entry.entry_node_id, "NODE_START")

    def test_empty_prerequisites(self):
        """Test ProjectEntry with empty prerequisites."""
        entry = ProjectEntry(
            pre_requisites=[],
            mobilization_time=1,
            entry_node_id="NODE_START"
        )
        self.assertEqual(len(entry.pre_requisites), 0)


class TestProjectExit(unittest.TestCase):
    """Test ProjectExit model."""

    def test_valid_project_exit(self):
        """Test creating a valid ProjectExit."""
        exit_criteria = ProjectExit(
            success_metrics=["90% completion", "Budget met"],
            mandate_end_date="2024-12-31",
            exit_node_id="NODE_END"
        )
        self.assertEqual(len(exit_criteria.success_metrics), 2)
        self.assertEqual(exit_criteria.mandate_end_date, "2024-12-31")

    def test_project_exit_without_date(self):
        """Test ProjectExit without mandate end date."""
        exit_criteria = ProjectExit(
            success_metrics=["Completion"],
            exit_node_id="NODE_END"
        )
        self.assertIsNone(exit_criteria.mandate_end_date)


class TestProject(unittest.TestCase):
    """Test Project model."""

    def setUp(self):
        """Set up common test data."""
        self.country = Country(
            name="France",
            a2="FR",
            a3="FRA",
            num="250",
            region="Europe",
            sub_region="Western Europe"
        )

        self.mock_categories = {"construction"}
        self.category_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.category_patcher.start()

        self.operation_type = OperationType(
            name="Building",
            category="construction",
            description="Construction work"
        )

    def tearDown(self):
        self.category_patcher.stop()

    def test_valid_project(self):
        """Test creating a valid Project."""
        project = Project(
            id="PROJ001",
            name="Bridge Construction",
            description="Building a major bridge",
            country=self.country,
            sector="infrastructure",
            service_requirements=["concrete", "steel"],
            timeline=36,
            ops_requirements=[self.operation_type],
            embedding=[0.5, 0.6, 0.7]
        )
        self.assertEqual(project.id, "PROJ001")
        self.assertEqual(project.timeline, 36)
        self.assertEqual(len(project.service_requirements), 2)

    def test_project_with_entry_exit_criteria(self):
        """Test Project with entry and exit criteria."""
        entry = ProjectEntry(
            pre_requisites=["Environmental clearance"],
            mobilization_time=6,
            entry_node_id="START"
        )
        exit_criteria = ProjectExit(
            success_metrics=["Bridge operational"],
            exit_node_id="END"
        )
        project = Project(
            id="PROJ002",
            name="Complex Project",
            description="Project with criteria",
            country=self.country,
            sector="infrastructure",
            service_requirements=["engineering"],
            timeline=24,
            ops_requirements=[self.operation_type],
            entry_criteria=entry,
            success_criteria=exit_criteria
        )
        self.assertIsNotNone(project.entry_criteria)
        self.assertIsNotNone(project.success_criteria)


class TestRiskProfile(unittest.TestCase):
    """Test RiskProfile model."""

    def test_valid_risk_profile(self):
        """Test creating a valid RiskProfile."""
        risk = RiskProfile(
            id="RISK001",
            name="High Risk Node",
            risk_level=4,
            influence_level=2,
            description="Critical infrastructure component"
        )
        self.assertEqual(risk.risk_level, 4)
        self.assertEqual(risk.influence_level, 2)

    def test_risk_level_boundaries(self):
        """Test RiskProfile with boundary values."""
        risk_min = RiskProfile(
            id="RISK_MIN",
            name="Minimum Risk",
            risk_level=1,
            influence_level=1,
            description="Lowest risk"
        )
        risk_max = RiskProfile(
            id="RISK_MAX",
            name="Maximum Risk",
            risk_level=5,
            influence_level=5,
            description="Highest risk"
        )
        self.assertEqual(risk_min.risk_level, 1)
        self.assertEqual(risk_max.risk_level, 5)

    def test_invalid_risk_level_too_low(self):
        """Test RiskProfile with risk level below minimum."""
        with self.assertRaises(ValidationError):
            RiskProfile(
                id="RISK_INVALID",
                name="Invalid Risk",
                risk_level=0,
                influence_level=3,
                description="Should fail"
            )

    def test_invalid_risk_level_too_high(self):
        """Test RiskProfile with risk level above maximum."""
        with self.assertRaises(ValidationError):
            RiskProfile(
                id="RISK_INVALID",
                name="Invalid Risk",
                risk_level=6,
                influence_level=3,
                description="Should fail"
            )


class TestCriticalChain(unittest.TestCase):
    """Test CriticalChain model."""

    def test_valid_critical_chain(self):
        """Test creating a valid CriticalChain."""
        chain = CriticalChain(
            chain_id="CHAIN001",
            nodes=["NODE1", "NODE2", "NODE3"],
            aggregate_risk=0.75,
            impact_description="High impact chain through core infrastructure"
        )
        self.assertEqual(len(chain.nodes), 3)
        self.assertEqual(chain.aggregate_risk, 0.75)

    def test_empty_chain(self):
        """Test CriticalChain with no nodes."""
        chain = CriticalChain(
            chain_id="CHAIN_EMPTY",
            nodes=[],
            aggregate_risk=0.0,
            impact_description="Empty chain"
        )
        self.assertEqual(len(chain.nodes), 0)


class TestPivotalNode(unittest.TestCase):
    """Test PivotalNode model."""

    def test_valid_pivotal_node(self):
        """Test creating a valid PivotalNode."""
        node = PivotalNode(
            node_id="PIVOT001",
            contribution_score=0.65,
            strategic_reason="Central hub with high downstream dependencies"
        )
        self.assertEqual(node.node_id, "PIVOT001")
        self.assertEqual(node.contribution_score, 0.65)


class TestAnalysisOutput(unittest.TestCase):
    """Test AnalysisOutput model."""

    def test_valid_analysis_output(self):
        """Test creating a valid AnalysisOutput."""
        chain = CriticalChain(
            chain_id="CHAIN001",
            nodes=["N1", "N2"],
            aggregate_risk=0.8,
            impact_description="Critical path"
        )
        pivot = PivotalNode(
            node_id="N1",
            contribution_score=0.9,
            strategic_reason="Key node"
        )
        analysis = AnalysisOutput(
            project_id="PROJ001",
            firm_id="FIRM001",
            overall_bankability=0.75,
            critical_chains=[chain],
            pivotal_nodes=[pivot],
            optimal_score=0.95,
            worst_case_score=0.45,
            scenario_spread=[0.5, 0.6, 0.7, 0.8, 0.9]
        )
        self.assertEqual(analysis.overall_bankability, 0.75)
        self.assertEqual(len(analysis.critical_chains), 1)
        self.assertEqual(len(analysis.pivotal_nodes), 1)
        self.assertEqual(len(analysis.scenario_spread), 5)

    def test_analysis_with_risk_tensors(self):
        """Test AnalysisOutput with risk tensors."""
        analysis = AnalysisOutput(
            project_id="PROJ002",
            firm_id="FIRM002",
            overall_bankability=0.6,
            risk_tensors={"node1": [0.1, 0.2], "node2": [0.3, 0.4]},
            optimal_score=0.9,
            worst_case_score=0.3
        )
        self.assertEqual(len(analysis.risk_tensors), 2)

    def test_bankability_boundaries(self):
        """Test AnalysisOutput with boundary bankability values."""
        analysis_min = AnalysisOutput(
            project_id="P1",
            firm_id="F1",
            overall_bankability=0.0,
            optimal_score=0.5,
            worst_case_score=0.0
        )
        analysis_max = AnalysisOutput(
            project_id="P2",
            firm_id="F2",
            overall_bankability=1.0,
            optimal_score=1.0,
            worst_case_score=0.5
        )
        self.assertEqual(analysis_min.overall_bankability, 0.0)
        self.assertEqual(analysis_max.overall_bankability, 1.0)

    def test_invalid_bankability(self):
        """Test AnalysisOutput with invalid bankability values."""
        with self.assertRaises(ValidationError):
            AnalysisOutput(
                project_id="P3",
                firm_id="F3",
                overall_bankability=1.5,
                optimal_score=0.8,
                worst_case_score=0.2
            )


if __name__ == '__main__':
    unittest.main()
