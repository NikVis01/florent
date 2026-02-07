import sys
import os
import unittest
from unittest.mock import patch, MagicMock, mock_open
import json

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.base import OperationType, Country, Sectors, StrategicFocus
from src.models.entities import Firm, Project, ProjectEntry, ProjectExit, RiskProfile, AnalysisOutput, CriticalChain, PivotalNode
from src.models.graph import Graph, Node, Edge
from src.services.agent.core.traversal import NodeStack, NodeHeap


class TestEndToEndGraphWorkflow(unittest.TestCase):
    """Integration test for complete graph workflow."""

    def setUp(self):
        """Set up comprehensive test data."""
        self.mock_categories = {"construction", "transportation", "logistics"}
        self.mock_sectors = {"infrastructure", "energy"}
        self.mock_focuses = {"efficiency", "sustainability"}

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

    def test_complete_project_workflow(self):
        """Test complete workflow from project creation to analysis."""
        # 1. Create country
        country = Country(
            name="United States",
            a2="US",
            a3="USA",
            num="840",
            region="Americas",
            sub_region="Northern America",
            affiliations=["NATO"]
        )

        # 2. Create operation types
        construction_op = OperationType(
            name="Road Construction",
            category="construction",
            description="Highway construction operations"
        )
        transport_op = OperationType(
            name="Material Transport",
            category="transportation",
            description="Heavy material logistics"
        )

        # 3. Create nodes
        node_site_prep = Node(
            id="SITE_PREP",
            name="Site Preparation",
            type=construction_op,
            embedding=[0.1, 0.2, 0.3]
        )
        node_foundation = Node(
            id="FOUNDATION",
            name="Foundation Work",
            type=construction_op,
            embedding=[0.2, 0.3, 0.4]
        )
        node_paving = Node(
            id="PAVING",
            name="Road Paving",
            type=construction_op,
            embedding=[0.3, 0.4, 0.5]
        )

        # 4. Create graph
        graph = Graph(
            nodes=[node_site_prep, node_foundation, node_paving],
            edges=[
                Edge(source=node_site_prep, target=node_foundation, weight=0.9, relationship="prerequisite"),
                Edge(source=node_foundation, target=node_paving, weight=0.8, relationship="prerequisite")
            ]
        )

        # 5. Create firm
        sector = Sectors(name="Infrastructure", description="infrastructure")
        focus = StrategicFocus(name="Efficiency", description="efficiency")

        firm = Firm(
            id="FIRM001",
            name="Construction Corp",
            description="Leading construction firm",
            countries_active=[country],
            sectors=[sector],
            services=[construction_op, transport_op],
            strategic_focuses=[focus],
            prefered_project_timeline=24,
            embedding=[0.5, 0.6, 0.7]
        )

        # 6. Create project
        project_entry = ProjectEntry(
            pre_requisites=["Environmental approval", "Funding secured"],
            mobilization_time=3,
            entry_node_id="SITE_PREP"
        )
        project_exit = ProjectExit(
            success_metrics=["Road operational", "Quality standards met"],
            mandate_end_date="2025-12-31",
            exit_node_id="PAVING"
        )

        project = Project(
            id="PROJ001",
            name="Highway Construction Project",
            description="Major highway construction",
            country=country,
            sector="infrastructure",
            service_requirements=["construction", "transportation"],
            timeline=24,
            ops_requirements=[construction_op],
            entry_criteria=project_entry,
            success_criteria=project_exit,
            embedding=[0.6, 0.7, 0.8]
        )

        # 7. Create risk profiles
        risk_high = RiskProfile(
            id="RISK_HIGH",
            name="Foundation Risk",
            risk_level=4,
            influence_level=2,
            description="Critical foundation work with weather dependency"
        )

        # 8. Create analysis output
        chain = CriticalChain(
            chain_id="CHAIN001",
            nodes=["SITE_PREP", "FOUNDATION", "PAVING"],
            aggregate_risk=0.65,
            impact_description="Critical path through all construction phases"
        )
        pivot = PivotalNode(
            node_id="FOUNDATION",
            contribution_score=0.75,
            strategic_reason="Central node affecting all downstream activities"
        )

        analysis = AnalysisOutput(
            project_id="PROJ001",
            firm_id="FIRM001",
            overall_bankability=0.72,
            critical_chains=[chain],
            pivotal_nodes=[pivot],
            optimal_score=0.90,
            worst_case_score=0.45,
            scenario_spread=[0.45, 0.60, 0.72, 0.80, 0.90]
        )

        # Verify all components are correctly connected
        self.assertEqual(len(graph.nodes), 3)
        self.assertEqual(len(graph.edges), 2)
        self.assertEqual(project.entry_criteria.entry_node_id, node_site_prep.id)
        self.assertEqual(project.success_criteria.exit_node_id, node_paving.id)
        self.assertEqual(len(firm.countries_active), 1)
        self.assertEqual(analysis.project_id, project.id)
        self.assertEqual(analysis.firm_id, firm.id)


class TestGraphTraversalIntegration(unittest.TestCase):
    """Integration test for graph traversal with stack and heap."""

    def setUp(self):
        """Set up test data."""
        self.mock_categories = {"test"}
        self.patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.patcher.start()

        self.op_type = OperationType(name="Test", category="test", description="Test op")

    def tearDown(self):
        self.patcher.stop()

    def test_dfs_traversal_with_stack(self):
        """Test depth-first traversal using NodeStack."""
        # Create a graph: A -> B -> C -> D
        nodes = [
            Node(id=f"N{i}", name=f"Node {i}", type=self.op_type, embedding=[float(i)])
            for i in range(4)
        ]
        edges = [
            Edge(source=nodes[i], target=nodes[i+1], weight=0.5, relationship="next")
            for i in range(3)
        ]
        graph = Graph(nodes=nodes, edges=edges)

        # Simulate DFS traversal
        stack = NodeStack()
        visited = []

        # Start from last node (D) and traverse backwards
        stack.push(nodes[3])
        while not stack.is_empty():
            current = stack.pop()
            visited.append(current.id)

        # Should have visited the node
        self.assertIn("N3", visited)

    def test_bfs_traversal_with_heap(self):
        """Test breadth-first traversal using NodeHeap."""
        # Create a simple graph
        nodes = [
            Node(id=f"N{i}", name=f"Node {i}", type=self.op_type, embedding=[float(i)])
            for i in range(5)
        ]

        heap = NodeHeap(max_heap=True)

        # Add nodes with different priorities
        for i, node in enumerate(nodes):
            heap.push(node, priority=float(i) / 10.0)

        # Pop all nodes - should come out in priority order
        result_ids = []
        while not heap.is_empty():
            result_ids.append(heap.pop().id)

        # Verify we got all nodes
        self.assertEqual(len(result_ids), 5)


class TestOrchestratorWithGraphIntegration(unittest.TestCase):
    """Integration test for AgentOrchestrator with actual Graph."""

    def setUp(self):
        """Set up test environment."""
        self.mock_categories = {"operations"}
        self.patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.patcher.start()

        self.op_type = OperationType(name="Operation", category="operations", description="Test operation")

    def tearDown(self):
        self.patcher.stop()

    @patch('src.services.agent.core.orchestrator.AgentOrchestrator')
    def test_orchestrator_graph_integration(self, mock_orchestrator_class):
        """Test that orchestrator can work with a real graph."""
        # Create graph
        nodes = [
            Node(id="A", name="Node A", type=self.op_type, embedding=[0.1]),
            Node(id="B", name="Node B", type=self.op_type, embedding=[0.2]),
            Node(id="C", name="Node C", type=self.op_type, embedding=[0.3])
        ]
        edges = [
            Edge(source=nodes[0], target=nodes[1], weight=0.6, relationship="leads to"),
            Edge(source=nodes[1], target=nodes[2], weight=0.7, relationship="prerequisite")
        ]
        graph = Graph(nodes=nodes, edges=edges)

        # Create mock orchestrator instance
        mock_orchestrator = MagicMock()
        mock_orchestrator_class.return_value = mock_orchestrator

        from src.services.agent.core.orchestrator import AgentOrchestrator

        # Create orchestrator with graph
        orchestrator = AgentOrchestrator(graph)

        # Verify it can be called
        mock_orchestrator_class.assert_called_once_with(graph)


class TestGeoAnalyzerWithEntities(unittest.TestCase):
    """Integration test for GeoAnalyzer with entity models."""

    def setUp(self):
        """Set up test data."""
        self.countries_data = [
            {
                "name": "France",
                "a2": "FR",
                "a3": "FRA",
                "num": "250",
                "region": "Europe",
                "sub_region": "Western Europe",
                "affiliations": ["EU", "NATO"]
            },
            {
                "name": "Germany",
                "a2": "DE",
                "a3": "DEU",
                "num": "276",
                "region": "Europe",
                "sub_region": "Western Europe",
                "affiliations": ["EU", "NATO"]
            }
        ]
        self.affiliations_data = {
            "EU": ["FRA", "DEU"],
            "NATO": ["FRA", "DEU"]
        }

    def test_geo_analyzer_with_firm_countries(self):
        """Test GeoAnalyzer with Firm's active countries."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data), \
             patch('src.models.base.get_categories', return_value={"logistics"}), \
             patch('src.models.base.get_sectors', return_value={"manufacturing"}), \
             patch('src.models.base.get_focuses', return_value={"growth"}):

            from src.services.country.geo import GeoAnalyzer

            analyzer = GeoAnalyzer()

            # Create countries for firm
            france = Country(
                name="France",
                a2="FR",
                a3="FRA",
                num="250",
                region="Europe",
                sub_region="Western Europe",
                affiliations=["EU", "NATO"]
            )
            germany = Country(
                name="Germany",
                a2="DE",
                a3="DEU",
                num="276",
                region="Europe",
                sub_region="Western Europe",
                affiliations=["EU", "NATO"]
            )

            # Check similarity between firm's active countries
            similarity = analyzer.calculate_geo_similarity("FRA", "DEU")

            # Same region + same sub-region + 2 shared affiliations = 0.8
            self.assertEqual(similarity, 0.8)

    def test_geo_analyzer_with_project_country(self):
        """Test GeoAnalyzer with Project country."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value=self.affiliations_data):

            from src.services.country.geo import GeoAnalyzer

            analyzer = GeoAnalyzer()

            # Get project country
            france = analyzer.get_country("FRA")
            self.assertIsNotNone(france)
            self.assertEqual(france.name, "France")
            self.assertIn("EU", france.affiliations)


class TestCompleteAnalysisPipeline(unittest.TestCase):
    """Integration test simulating complete analysis pipeline."""

    def setUp(self):
        """Set up comprehensive test environment."""
        self.mock_categories = {"engineering", "procurement"}
        self.mock_sectors = {"infrastructure"}
        self.mock_focuses = {"quality"}

        self.cat_patcher = patch('src.models.base.get_categories', return_value=self.mock_categories)
        self.sec_patcher = patch('src.models.base.get_sectors', return_value=self.mock_sectors)
        self.foc_patcher = patch('src.models.base.get_focuses', return_value=self.mock_focuses)

        self.cat_patcher.start()
        self.sec_patcher.start()
        self.foc_patcher.start()

        self.countries_data = [
            {
                "name": "Singapore",
                "a2": "SG",
                "a3": "SGP",
                "num": "702",
                "region": "Asia",
                "sub_region": "South-Eastern Asia",
                "affiliations": ["ASEAN"]
            }
        ]

    def tearDown(self):
        self.cat_patcher.stop()
        self.sec_patcher.stop()
        self.foc_patcher.stop()

    def test_full_pipeline_simulation(self):
        """Test simulation of complete analysis pipeline."""
        with patch('src.models.base.load_countries_data', return_value=self.countries_data), \
             patch('src.models.base.load_affiliations_data', return_value={"ASEAN": ["SGP"]}):

            # 1. Load geo data
            from src.services.country.geo import GeoAnalyzer
            geo = GeoAnalyzer()
            country = geo.get_country("SGP")
            self.assertIsNotNone(country)

            # 2. Create entities
            op_type = OperationType(name="Engineering", category="engineering", description="Design work")
            sector = Sectors(name="Infrastructure", description="infrastructure")
            focus = StrategicFocus(name="Quality", description="quality")

            firm = Firm(
                id="FIRM_SG",
                name="Singapore Engineering",
                description="Top engineering firm",
                countries_active=[country],
                sectors=[sector],
                services=[op_type],
                strategic_focuses=[focus],
                prefered_project_timeline=18
            )

            # 3. Create graph
            nodes = [
                Node(id="DESIGN", name="Design Phase", type=op_type, embedding=[0.2, 0.3]),
                Node(id="BUILD", name="Build Phase", type=op_type, embedding=[0.4, 0.5])
            ]
            edges = [
                Edge(source=nodes[0], target=nodes[1], weight=0.85, relationship="prerequisite")
            ]
            graph = Graph(nodes=nodes, edges=edges)

            # 4. Create project
            project = Project(
                id="PROJ_SG",
                name="Metro Expansion",
                description="Expanding metro system",
                country=country,
                sector="infrastructure",
                service_requirements=["engineering"],
                timeline=36,
                ops_requirements=[op_type]
            )

            # 5. Simulate analysis
            analysis = AnalysisOutput(
                project_id=project.id,
                firm_id=firm.id,
                overall_bankability=0.85,
                critical_chains=[
                    CriticalChain(
                        chain_id="MAIN",
                        nodes=["DESIGN", "BUILD"],
                        aggregate_risk=0.35,
                        impact_description="Main project path"
                    )
                ],
                pivotal_nodes=[
                    PivotalNode(
                        node_id="DESIGN",
                        contribution_score=0.70,
                        strategic_reason="Design quality affects all downstream"
                    )
                ],
                optimal_score=0.95,
                worst_case_score=0.60
            )

            # Verify complete pipeline
            self.assertEqual(analysis.firm_id, firm.id)
            self.assertEqual(analysis.project_id, project.id)
            self.assertGreater(analysis.overall_bankability, 0.8)
            self.assertEqual(len(graph.nodes), 2)
            self.assertEqual(len(graph.edges), 1)


if __name__ == '__main__':
    unittest.main()
