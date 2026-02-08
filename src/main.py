import json
import os
from typing import Any, Dict, Optional
from litestar import Litestar, post, get
from pydantic import BaseModel

from src.services.clients.ai_client import AIClient
from src.models.entities import Firm, Project, ProjectEntry, ProjectExit
from src.models.base import Country, Sectors, StrategicFocus, OperationType
from src.models.graph import Graph, Node, Edge
from src.services.agent.core.orchestrator_v2 import RiskOrchestrator
from src.services.graph_builder import build_firm_contextual_graph
from src.services.logging.logger import get_logger

# Initialize AI Client (OpenAI via DSPy)
ai_client = AIClient()
logger = get_logger(__name__)

class AnalysisRequest(BaseModel):
    firm_data: Optional[Dict[str, Any]] = None
    project_data: Optional[Dict[str, Any]] = None
    firm_path: Optional[str] = None
    project_path: Optional[str] = None
    budget: Optional[int] = 100

def load_data(data: Optional[Dict[str, Any]], path: Optional[str]) -> Dict[str, Any]:
    if data:
        return data
    if path:
        # Handle path translation: if path doesn't exist, try converting host path to container path
        file_path = path
        
        # Check if path exists as-is first
        if not os.path.exists(file_path):
            # Try to convert host absolute path to container path
            # Host: /home/user/.../florent/src/data/...
            # Container: /app/src/data/...
            if 'src/data' in path:
                # Extract the part after 'src/data'
                parts = path.split('src/data', 1)
                if len(parts) > 1:
                    # Container path is /app/src/data + rest of path
                    container_path = f'/app/src/data{parts[1]}'
                    if os.path.exists(container_path):
                        file_path = container_path
                        logger.info(f"Translated host path {path} to container path {file_path}")
        
        if not os.path.exists(file_path):
            raise FileNotFoundError(f"File not found: {path}")
        
        with open(file_path, "r") as f:
            return json.load(f)
    raise ValueError("Missing data or path")

def parse_firm(firm_data: Dict[str, Any]) -> Firm:
    """Parse firm data into Firm entity."""
    countries = [Country(**c) for c in firm_data['countries_active']]
    sectors = [Sectors(**s) for s in firm_data['sectors']]
    services = [OperationType(**s) for s in firm_data['services']]
    focuses = [StrategicFocus(**f) for f in firm_data['strategic_focuses']]

    # Handle both old and new field names
    timeline_key = 'preferred_project_timeline' if 'preferred_project_timeline' in firm_data else 'prefered_project_timeline'

    return Firm(
        id=firm_data['id'],
        name=firm_data['name'],
        description=firm_data['description'],
        countries_active=countries,
        sectors=sectors,
        services=services,
        strategic_focuses=focuses,
        prefered_project_timeline=firm_data[timeline_key]
    )

def parse_project(project_data: Dict[str, Any]) -> Project:
    """Parse project data into Project entity."""
    country = Country(**project_data['country'])
    ops = [OperationType(**op) for op in project_data['ops_requirements']]
    entry = ProjectEntry(**project_data['entry_criteria']) if project_data.get('entry_criteria') else None
    exit_criteria = ProjectExit(**project_data['success_criteria']) if project_data.get('success_criteria') else None

    return Project(
        id=project_data['id'],
        name=project_data['name'],
        description=project_data['description'],
        country=country,
        sector=project_data['sector'],
        service_requirements=project_data['service_requirements'],
        timeline=project_data['timeline'],
        ops_requirements=ops,
        entry_criteria=entry,
        success_criteria=exit_criteria
    )

def build_infrastructure_graph(project: Project) -> Graph:
    """Build initial graph from project requirements, ensuring no cycles and robust metadata handling."""
    if not project.ops_requirements:
        raise ValueError("Project has no ops_requirements")

    node_map = {}
    
    # 1. Collect all nodes
    # Entry
    if project.entry_criteria:
        entry_id = project.entry_criteria.entry_node_id
        node_map[entry_id] = Node(
            id=entry_id,
            name="Entry Point",
            type=project.ops_requirements[0],
            embedding=[0.1, 0.1, 0.1]
        )
    
    # Ops (avoid duplicating entry/exit ids)
    for i, op in enumerate(project.ops_requirements):
        op_id = f"op_{i}"
        if op_id not in node_map:
            node_map[op_id] = Node(
                id=op_id,
                name=op.name,
                type=op,
                embedding=[0.2, 0.2, 0.2]
            )
            
    # Exit
    if project.success_criteria:
        exit_id = project.success_criteria.exit_node_id
        if exit_id not in node_map:
            node_map[exit_id] = Node(
                id=exit_id,
                name="Exit Point",
                type=project.ops_requirements[-1],
                embedding=[0.9, 0.9, 0.9]
            )

    # 2. Sequence edges (linear pipeline for initial graph)
    nodes_ordered = list(node_map.values())
    edges = []
    for i in range(len(nodes_ordered) - 1):
        # Prevent self-loops
        if nodes_ordered[i].id != nodes_ordered[i+1].id:
            edges.append(Edge(
                source=nodes_ordered[i],
                target=nodes_ordered[i+1],
                weight=0.8,
                relationship="sequence"
            ))

    return Graph(nodes=nodes_ordered, edges=edges)

@post("/analyze")
async def analyze_project(data: AnalysisRequest) -> Dict[str, Any]:
    """
    Main endpoint for risk analysis using Orchestrator V2.
    """
    try:
        logger.info("analysis_request_received", budget=data.budget)

        # Load data
        firm_data = load_data(data.firm_data, data.firm_path)
        project_data = load_data(data.project_data, data.project_path)

        # Parse into entities
        firm = parse_firm(firm_data)
        project = parse_project(project_data)

        logger.info("entities_parsed", firm=firm.name, project=project.name)

        # Build firm-contextual graph with cross-encoder weighting
        graph = await build_firm_contextual_graph(firm, project)

        # Run enhanced V2 analysis
        orchestrator = RiskOrchestrator(firm, project, graph)
        budget = data.budget or 100
        analysis_result = await orchestrator.run_analysis(budget)

        logger.info(
            "analysis_complete",
            project_score=analysis_result.summary.aggregate_project_score,
            nodes=analysis_result.summary.total_nodes
        )

        # Return full Pydantic model dump
        return {
            "status": "success",
            "message": f"Comprehensive analysis complete for {project.name}",
            "analysis": analysis_result.model_dump()
        }

    except Exception as e:
        logger.error("analysis_failed", error=str(e), exc_info=True)
        return {"status": "error", "message": str(e)}

@get("/")
async def health_check() -> str:
    return "Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."

app = Litestar(route_handlers=[health_check, analyze_project])
