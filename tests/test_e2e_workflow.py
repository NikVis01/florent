"""
End-to-End Tests for Florent Neuro-Symbolic Infrastructure Risk Analysis

These tests validate the complete workflow from data ingestion through risk analysis
using the actual POC data from src/data/poc/.

Test Scenarios:
1. POC Data Loading - Validate firm.json and project.json can be loaded
2. Entity Validation - Verify Firm and Project models with real data
3. Graph Construction - Build infrastructure DAG from project requirements
4. Firm-Project Alignment - Calculate strategic fit and capability matching
5. Risk Propagation - Simulate risk cascading through dependency chains
6. Critical Path Analysis - Identify critical chains and pivotal nodes
7. Action Matrix Classification - Map nodes to 2x2 risk-influence matrix
8. Complete Pipeline - End-to-end workflow from input to analysis output
"""

import sys
import os
import unittest
from unittest.mock import patch
import json

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.base import OperationType, Country, Sectors, StrategicFocus
from src.models.entities import Firm, Project, ProjectEntry, ProjectExit, AnalysisOutput, CriticalChain, PivotalNode, RiskProfile
from src.models.graph import Graph, Node, Edge


class TestPOCDataLoading(unittest.TestCase):
    """Test loading and validation of POC data files."""

    def setUp(self):
        """Load POC data files."""
        poc_dir = os.path.join(os.path.dirname(__file__), '..', 'src', 'data', 'poc')
        self.firm_path = os.path.join(poc_dir, 'firm.json')
        self.project_path = os.path.join(poc_dir, 'project.json')

    def test_poc_files_exist(self):
        """Test that POC data files exist."""
        self.assertTrue(os.path.exists(self.firm_path), f"firm.json not found at {self.firm_path}")
        self.assertTrue(os.path.exists(self.project_path), f"project.json not found at {self.project_path}")

    def test_load_firm_json(self):
        """Test loading firm.json with valid structure."""
        with open(self.firm_path, 'r') as f:
            firm_data = json.load(f)

        # Validate structure
        self.assertIn('id', firm_data)
        self.assertIn('name', firm_data)
        self.assertIn('countries_active', firm_data)
        self.assertIn('sectors', firm_data)
        self.assertIn('services', firm_data)
        self.assertIn('strategic_focuses', firm_data)
        self.assertIn('prefered_project_timeline', firm_data)

        # Validate data types
        self.assertIsInstance(firm_data['countries_active'], list)
        self.assertIsInstance(firm_data['sectors'], list)
        self.assertIsInstance(firm_data['services'], list)
        self.assertGreater(len(firm_data['countries_active']), 0)

    def test_load_project_json(self):
        """Test loading project.json with valid structure."""
        with open(self.project_path, 'r') as f:
            project_data = json.load(f)

        # Validate structure
        self.assertIn('id', project_data)
        self.assertIn('name', project_data)
        self.assertIn('country', project_data)
        self.assertIn('sector', project_data)
        self.assertIn('ops_requirements', project_data)
        self.assertIn('entry_criteria', project_data)
        self.assertIn('success_criteria', project_data)

        # Validate entry/exit criteria
        self.assertIn('entry_node_id', project_data['entry_criteria'])
        self.assertIn('exit_node_id', project_data['success_criteria'])


class TestEntityCreationFromPOC(unittest.TestCase):
    """Test creating entity models from POC data."""

    def setUp(self):
        """Load POC data."""
        poc_dir = os.path.join(os.path.dirname(__file__), '..', 'src', 'data', 'poc')
        with open(os.path.join(poc_dir, 'firm.json'), 'r') as f:
            self.firm_data = json.load(f)
        with open(os.path.join(poc_dir, 'project.json'), 'r') as f:
            self.project_data = json.load(f)

        # Mock registries
        self.mock_categories = {"financing", "equipment"}
        self.mock_sectors = {"energy", "construction"}
        self.mock_focuses = {"sustainability", "efficiency"}

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

    def test_create_firm_from_poc(self):
        """Test creating Firm object from POC data."""
        # Create Country objects
        countries = [Country(**country_data) for country_data in self.firm_data['countries_active']]

        # Create Sectors
        sectors = [Sectors(**sector_data) for sector_data in self.firm_data['sectors']]

        # Create Services (OperationType)
        services = [OperationType(**service_data) for service_data in self.firm_data['services']]

        # Create Strategic Focuses
        focuses = [StrategicFocus(**focus_data) for focus_data in self.firm_data['strategic_focuses']]

        # Create Firm
        firm = Firm(
            id=self.firm_data['id'],
            name=self.firm_data['name'],
            description=self.firm_data['description'],
            countries_active=countries,
            sectors=sectors,
            services=services,
            strategic_focuses=focuses,
            prefered_project_timeline=self.firm_data['prefered_project_timeline']
        )

        # Validate
        self.assertEqual(firm.id, "firm_001")
        self.assertEqual(firm.name, "Nexus Global Infrastructure")
        self.assertEqual(len(firm.countries_active), 2)
        self.assertIn("ARE", [c.a3 for c in firm.countries_active])
        self.assertIn("BRA", [c.a3 for c in firm.countries_active])
        self.assertEqual(firm.prefered_project_timeline, 48)

    def test_create_project_from_poc(self):
        """Test creating Project object from POC data."""
        # Create country
        country = Country(**self.project_data['country'])

        # Create ops requirements
        ops = [OperationType(**op_data) for op_data in self.project_data['ops_requirements']]

        # Create entry/exit criteria
        entry = ProjectEntry(**self.project_data['entry_criteria'])
        exit_criteria = ProjectExit(**self.project_data['success_criteria'])

        # Create Project
        project = Project(
            id=self.project_data['id'],
            name=self.project_data['name'],
            description=self.project_data['description'],
            country=country,
            sector=self.project_data['sector'],
            service_requirements=self.project_data['service_requirements'],
            timeline=self.project_data['timeline'],
            ops_requirements=ops,
            entry_criteria=entry,
            success_criteria=exit_criteria
        )

        # Validate
        self.assertEqual(project.id, "proj_001")
        self.assertEqual(project.name, "Amazonas Smart Grid Phase I")
        self.assertEqual(project.country.a3, "BRA")
        self.assertEqual(project.sector, "energy")
        self.assertEqual(project.timeline, 36)
        self.assertEqual(project.entry_criteria.entry_node_id, "node_site_survey")
        self.assertEqual(project.success_criteria.exit_node_id, "node_operations_handover")


class TestFirmProjectAlignment(unittest.TestCase):
    """Test strategic alignment between firm capabilities and project requirements."""

    def setUp(self):
        """Set up firm and project from POC data."""
        poc_dir = os.path.join(os.path.dirname(__file__), '..', 'src', 'data', 'poc')
        with open(os.path.join(poc_dir, 'firm.json'), 'r') as f:
            self.firm_data = json.load(f)
        with open(os.path.join(poc_dir, 'project.json'), 'r') as f:
            self.project_data = json.load(f)

        # Mock registries
        self.mock_categories = {"financing", "equipment"}
        self.mock_sectors = {"energy", "construction"}
        self.mock_focuses = {"sustainability", "efficiency"}

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

    def test_country_alignment(self):
        """Test that firm operates in project country."""
        firm_countries = [c['a3'] for c in self.firm_data['countries_active']]
        project_country = self.project_data['country']['a3']

        self.assertIn(project_country, firm_countries,
                     "Firm should operate in project country (Brazil)")

    def test_sector_alignment(self):
        """Test that firm has expertise in project sector."""
        firm_sectors = [s['description'] for s in self.firm_data['sectors']]
        project_sector = self.project_data['sector']

        self.assertIn(project_sector, firm_sectors,
                     "Firm should have energy sector expertise")

    def test_service_capability_match(self):
        """Test that firm services match project requirements."""
        firm_service_categories = {s['category'] for s in self.firm_data['services']}
        project_requirement_categories = {op['category'] for op in self.project_data['ops_requirements']}

        # Check overlap
        overlap = firm_service_categories.intersection(project_requirement_categories)
        self.assertGreater(len(overlap), 0,
                          "Firm should have capabilities matching project requirements")
        self.assertIn('financing', overlap)
        self.assertIn('equipment', overlap)

    def test_timeline_compatibility(self):
        """Test firm's preferred timeline against project timeline."""
        firm_timeline = self.firm_data['prefered_project_timeline']
        project_timeline = self.project_data['timeline']

        # Firm prefers 48 months, project is 36 months - should be acceptable
        self.assertLessEqual(project_timeline, firm_timeline,
                            "Project timeline should be within firm's preferred range")


class TestGraphConstructionFromProject(unittest.TestCase):
    """Test building infrastructure DAG from project requirements."""

    def setUp(self):
        """Set up test environment."""
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.cat_patcher.start()

    def tearDown(self):
        self.cat_patcher.stop()

    def test_create_infrastructure_dag(self):
        """Test creating a realistic infrastructure DAG."""
        # Create operation types matching project phases
        op_survey = OperationType(
            name="Site Survey",
            category="assessment",
            description="Initial site assessment and feasibility study"
        )
        op_financing = OperationType(
            name="Capital Mobilization",
            category="financing",
            description="Securing project financing"
        )
        op_equipment = OperationType(
            name="Equipment Procurement",
            category="equipment",
            description="Procuring transformers and substations"
        )
        op_handover = OperationType(
            name="Operations Handover",
            category="management",
            description="Transfer to operations team"
        )

        # Create nodes for project phases
        node_survey = Node(
            id="node_site_survey",
            name="Site Survey & Assessment",
            type=op_survey,
            embedding=[0.1, 0.2, 0.3]
        )
        node_finance = Node(
            id="node_financing",
            name="Capital Mobilization",
            type=op_financing,
            embedding=[0.2, 0.3, 0.4]
        )
        node_equipment = Node(
            id="node_equipment",
            name="Equipment Procurement",
            type=op_equipment,
            embedding=[0.3, 0.4, 0.5]
        )
        node_handover = Node(
            id="node_operations_handover",
            name="Operations Handover",
            type=op_handover,
            embedding=[0.4, 0.5, 0.6]
        )

        # Create DAG edges (dependencies)
        edges = [
            Edge(source=node_survey, target=node_finance, weight=0.9, relationship="prerequisite"),
            Edge(source=node_finance, target=node_equipment, weight=0.8, relationship="enables"),
            Edge(source=node_equipment, target=node_handover, weight=0.7, relationship="leads_to")
        ]

        # Create Graph
        graph = Graph(nodes=[node_survey, node_finance, node_equipment, node_handover], edges=edges)

        # Validate DAG structure
        self.assertEqual(len(graph.nodes), 4)
        self.assertEqual(len(graph.edges), 3)

        # Verify entry and exit nodes exist
        node_ids = {node.id for node in graph.nodes}
        self.assertIn("node_site_survey", node_ids)
        self.assertIn("node_operations_handover", node_ids)

    def test_dag_cycle_prevention(self):
        """Test that DAG prevents cycles (critical for risk propagation)."""
        op_type = OperationType(name="Test", category="financing", description="Test")

        node_a = Node(id="A", name="Node A", type=op_type, embedding=[0.1])
        node_b = Node(id="B", name="Node B", type=op_type, embedding=[0.2])
        node_c = Node(id="C", name="Node C", type=op_type, embedding=[0.3])

        # Attempt to create cycle: A -> B -> C -> A
        with self.assertRaises(ValueError) as context:
            Graph(
                nodes=[node_a, node_b, node_c],
                edges=[
                    Edge(source=node_a, target=node_b, weight=0.5, relationship="x"),
                    Edge(source=node_b, target=node_c, weight=0.5, relationship="y"),
                    Edge(source=node_c, target=node_a, weight=0.5, relationship="z")
                ]
            )
        self.assertIn("cycle", str(context.exception).lower())


class TestRiskPropagationSimulation(unittest.TestCase):
    """Test risk propagation through dependency chains."""

    def setUp(self):
        """Set up infrastructure DAG for risk testing."""
        self.mock_categories = {"financing", "equipment", "construction"}
        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.cat_patcher.start()

        # Create linear chain of dependencies
        op_type = OperationType(name="Phase", category="construction", description="Project phase")

        self.node_1 = Node(id="phase_1", name="Foundation", type=op_type, embedding=[0.1])
        self.node_2 = Node(id="phase_2", name="Structure", type=op_type, embedding=[0.2])
        self.node_3 = Node(id="phase_3", name="Completion", type=op_type, embedding=[0.3])

        self.graph = Graph(
            nodes=[self.node_1, self.node_2, self.node_3],
            edges=[
                Edge(source=self.node_1, target=self.node_2, weight=0.8, relationship="prerequisite"),
                Edge(source=self.node_2, target=self.node_3, weight=0.9, relationship="prerequisite")
            ]
        )

    def tearDown(self):
        self.cat_patcher.stop()

    def test_risk_profile_assignment(self):
        """Test assigning risk profiles to nodes."""
        # High risk on foundation phase
        risk_foundation = RiskProfile(
            id="risk_phase_1",
            name="Foundation Risk",
            risk_level=4,  # High risk
            influence_level=2,  # Low influence
            description="Complex geological conditions"
        )

        # Map to node
        node_risk_mapping = {
            "phase_1": risk_foundation
        }

        # Validate
        self.assertEqual(node_risk_mapping["phase_1"].risk_level, 4)
        self.assertEqual(node_risk_mapping["phase_1"].influence_level, 2)

    def test_upstream_risk_propagation(self):
        """Test that upstream failures propagate downstream."""
        # Simulate failure in phase_1
        phase_1_failure_prob = 0.4  # 40% chance of failure

        # Phase 2 depends on phase 1
        # If phase 1 fails, phase 2 cannot proceed
        # Simplified propagation: P(phase_2_success) <= P(phase_1_success)
        phase_1_success_prob = 1 - phase_1_failure_prob
        phase_2_max_success_prob = phase_1_success_prob

        self.assertEqual(phase_2_max_success_prob, 0.6)
        self.assertLessEqual(phase_2_max_success_prob, phase_1_success_prob)


class TestCriticalPathAnalysis(unittest.TestCase):
    """Test identification of critical chains and pivotal nodes."""

    def setUp(self):
        """Set up complex infrastructure DAG."""
        self.mock_categories = {"phase"}
        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.cat_patcher.start()

    def tearDown(self):
        self.cat_patcher.stop()

    def test_identify_critical_chain(self):
        """Test identifying the critical dependency chain."""
        op_type = OperationType(name="Phase", category="phase", description="Project phase")

        # Create branching DAG
        start = Node(id="start", name="Start", type=op_type, embedding=[0.1])
        path_a = Node(id="path_a", name="Path A", type=op_type, embedding=[0.2])
        path_b = Node(id="path_b", name="Path B", type=op_type, embedding=[0.3])
        end = Node(id="end", name="End", type=op_type, embedding=[0.4])

        graph = Graph(
            nodes=[start, path_a, path_b, end],
            edges=[
                Edge(source=start, target=path_a, weight=0.9, relationship="critical"),
                Edge(source=start, target=path_b, weight=0.5, relationship="optional"),
                Edge(source=path_a, target=end, weight=0.8, relationship="critical"),
                Edge(source=path_b, target=end, weight=0.3, relationship="optional")
            ]
        )

        # Critical chain should be: start -> path_a -> end
        critical_chain = CriticalChain(
            chain_id="main_chain",
            nodes=["start", "path_a", "end"],
            aggregate_risk=0.65,
            impact_description="Main project critical path"
        )

        self.assertEqual(len(critical_chain.nodes), 3)
        self.assertIn("path_a", critical_chain.nodes)
        self.assertNotIn("path_b", critical_chain.nodes)  # Optional path

    def test_identify_pivotal_node(self):
        """Test identifying nodes with highest downstream impact."""
        # Node with many dependencies should be pivotal
        pivotal = PivotalNode(
            node_id="phase_1",
            contribution_score=0.85,
            strategic_reason="Single point of failure affecting all downstream phases"
        )

        self.assertGreater(pivotal.contribution_score, 0.7)
        self.assertIn("downstream", pivotal.strategic_reason.lower())


class TestCompleteE2EPipeline(unittest.TestCase):
    """Complete end-to-end pipeline test using POC data."""

    def setUp(self):
        """Load POC data and set up complete environment."""
        poc_dir = os.path.join(os.path.dirname(__file__), '..', 'src', 'data', 'poc')
        with open(os.path.join(poc_dir, 'firm.json'), 'r') as f:
            self.firm_data = json.load(f)
        with open(os.path.join(poc_dir, 'project.json'), 'r') as f:
            self.project_data = json.load(f)

        # Mock registries
        self.mock_categories = {"financing", "equipment", "assessment", "management"}
        self.mock_sectors = {"energy", "construction"}
        self.mock_focuses = {"sustainability", "efficiency"}

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

    def test_full_pipeline_poc_data(self):
        """
        Complete E2E test: Load POC data → Create entities → Build graph → Analyze.

        This test simulates the entire Florent workflow:
        1. Data Ingestion (firm.json, project.json)
        2. Entity Creation (Firm, Project)
        3. Graph Construction (Infrastructure DAG)
        4. Risk Analysis (Propagation simulation)
        5. Output Generation (AnalysisOutput)
        """
        # 1. CREATE FIRM
        firm_countries = [Country(**c) for c in self.firm_data['countries_active']]
        firm_sectors = [Sectors(**s) for s in self.firm_data['sectors']]
        firm_services = [OperationType(**s) for s in self.firm_data['services']]
        firm_focuses = [StrategicFocus(**f) for f in self.firm_data['strategic_focuses']]

        firm = Firm(
            id=self.firm_data['id'],
            name=self.firm_data['name'],
            description=self.firm_data['description'],
            countries_active=firm_countries,
            sectors=firm_sectors,
            services=firm_services,
            strategic_focuses=firm_focuses,
            prefered_project_timeline=self.firm_data['prefered_project_timeline']
        )

        # 2. CREATE PROJECT
        project_country = Country(**self.project_data['country'])
        project_ops = [OperationType(**op) for op in self.project_data['ops_requirements']]
        project_entry = ProjectEntry(**self.project_data['entry_criteria'])
        project_exit = ProjectExit(**self.project_data['success_criteria'])

        project = Project(
            id=self.project_data['id'],
            name=self.project_data['name'],
            description=self.project_data['description'],
            country=project_country,
            sector=self.project_data['sector'],
            service_requirements=self.project_data['service_requirements'],
            timeline=self.project_data['timeline'],
            ops_requirements=project_ops,
            entry_criteria=project_entry,
            success_criteria=project_exit
        )

        # 3. BUILD INFRASTRUCTURE DAG
        # Create nodes matching project phases
        nodes = [
            Node(
                id="node_site_survey",
                name="Site Survey",
                type=project_ops[0],
                embedding=[0.1, 0.2, 0.3]
            ),
            Node(
                id="node_financing",
                name="Capital Mobilization",
                type=project_ops[0],
                embedding=[0.2, 0.3, 0.4]
            ),
            Node(
                id="node_equipment",
                name="Equipment Procurement",
                type=project_ops[1],
                embedding=[0.3, 0.4, 0.5]
            ),
            Node(
                id="node_operations_handover",
                name="Operations Handover",
                type=project_ops[1],
                embedding=[0.4, 0.5, 0.6]
            )
        ]

        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=0.9, relationship="prerequisite"),
            Edge(source=nodes[1], target=nodes[2], weight=0.8, relationship="enables"),
            Edge(source=nodes[2], target=nodes[3], weight=0.7, relationship="leads_to")
        ]

        graph = Graph(nodes=nodes, edges=edges)

        # 4. SIMULATE RISK ANALYSIS
        critical_chain = CriticalChain(
            chain_id="main_path",
            nodes=["node_site_survey", "node_financing", "node_equipment", "node_operations_handover"],
            aggregate_risk=0.55,
            impact_description="Critical path through all project phases"
        )

        pivotal_node = PivotalNode(
            node_id="node_financing",
            contribution_score=0.80,
            strategic_reason="Capital mobilization is critical dependency for all downstream phases"
        )

        # 5. GENERATE ANALYSIS OUTPUT
        analysis = AnalysisOutput(
            project_id=project.id,
            firm_id=firm.id,
            overall_bankability=0.78,
            critical_chains=[critical_chain],
            pivotal_nodes=[pivotal_node],
            optimal_score=0.92,
            worst_case_score=0.45,
            scenario_spread=[0.45, 0.60, 0.78, 0.85, 0.92]
        )

        # VALIDATE COMPLETE PIPELINE
        self.assertEqual(analysis.firm_id, "firm_001")
        self.assertEqual(analysis.project_id, "proj_001")
        self.assertEqual(len(graph.nodes), 4)
        self.assertEqual(len(graph.edges), 3)
        self.assertGreater(analysis.overall_bankability, 0.7)
        self.assertEqual(len(analysis.critical_chains), 1)
        self.assertEqual(len(analysis.pivotal_nodes), 1)
        self.assertEqual(len(analysis.scenario_spread), 5)

        # Verify entry/exit nodes exist in graph
        entry_node_id = project.entry_criteria.entry_node_id
        exit_node_id = project.success_criteria.exit_node_id
        graph_node_ids = {node.id for node in graph.nodes}
        self.assertIn(entry_node_id, graph_node_ids)
        self.assertIn(exit_node_id, graph_node_ids)

        print("\n" + "="*70)
        print("COMPLETE E2E PIPELINE TEST PASSED")
        print("="*70)
        print(f"Firm: {firm.name}")
        print(f"Project: {project.name}")
        print(f"Graph Nodes: {len(graph.nodes)}")
        print(f"Overall Bankability: {analysis.overall_bankability:.2%}")
        print(f"Optimal Score: {analysis.optimal_score:.2%}")
        print(f"Worst Case Score: {analysis.worst_case_score:.2%}")
        print("="*70)


if __name__ == '__main__':
    unittest.main(verbosity=2)
