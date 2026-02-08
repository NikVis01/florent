import json
import os
from pathlib import Path
from typing import Any, Dict, Optional

import aiofiles
from litestar import Litestar, post, get
from litestar.exceptions import HTTPException
from litestar.status_codes import (
    HTTP_400_BAD_REQUEST,
    HTTP_404_NOT_FOUND,
    HTTP_500_INTERNAL_SERVER_ERROR,
)
from pydantic import BaseModel, field_validator, ValidationError as PydanticValidationError

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
    """Analysis request with validation."""
    firm_data: Optional[Dict[str, Any]] = None
    project_data: Optional[Dict[str, Any]] = None
    firm_path: Optional[str] = None
    project_path: Optional[str] = None
    budget: Optional[int] = 100

    @field_validator('budget')
    @classmethod
    def validate_budget(cls, v):
        """Validate budget is positive."""
        if v is not None and v <= 0:
            raise ValueError('budget must be positive')
        return v

    def model_post_init(self, __context):
        """Validate that at least one firm source and one project source is provided."""
        if not self.firm_data and not self.firm_path:
            raise ValueError('Must provide either firm_data or firm_path')
        if not self.project_data and not self.project_path:
            raise ValueError('Must provide either project_data or project_path')


async def load_data_async(data: Optional[Dict[str, Any]], path: Optional[str]) -> Dict[str, Any]:
    """
    Load data from inline dict or file path (async).

    Raises:
        HTTPException: With appropriate status code and message
    """
    # If inline data provided, use it
    if data:
        return data

    # Must have path at this point (validation ensures one or the other)
    if not path:
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail="Must provide either data or path"
        )

    # Resolve path - try multiple strategies
    file_path = await resolve_path(path)

    # Load file asynchronously
    try:
        async with aiofiles.open(file_path, "r") as f:
            content = await f.read()
            return json.loads(content)
    except FileNotFoundError:
        raise HTTPException(
            status_code=HTTP_404_NOT_FOUND,
            detail=f"File not found: {path} (resolved to: {file_path})"
        )
    except json.JSONDecodeError as e:
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail=f"Invalid JSON in file {path}: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error reading file {path}: {str(e)}"
        )


async def resolve_path(path: str) -> str:
    """
    Resolve file path with multiple fallback strategies.

    Tries:
    1. Path as-is (relative or absolute)
    2. Container path translation (/app/src/data/...)
    3. Project root relative path

    Returns:
        Resolved file path

    Raises:
        HTTPException: If file not found after all strategies
    """
    # Strategy 1: Try path as-is
    if os.path.exists(path):
        logger.info(f"Path resolved as-is: {path}")
        return path

    # Strategy 2: Container path translation
    # Host: /home/user/.../florent/src/data/...
    # Container: /app/src/data/...
    if 'src/data' in path:
        parts = path.split('src/data', 1)
        if len(parts) > 1:
            container_path = f'/app/src/data{parts[1]}'
            if os.path.exists(container_path):
                logger.info(f"Path resolved via container translation: {path} → {container_path}")
                return container_path

    # Strategy 3: Try relative to project root
    # Assumes API runs from project root or container /app
    for base in [Path.cwd(), Path('/app')]:
        candidate = base / path
        if candidate.exists():
            logger.info(f"Path resolved relative to {base}: {candidate}")
            return str(candidate)

    # All strategies failed
    raise HTTPException(
        status_code=HTTP_404_NOT_FOUND,
        detail=f"File not found: {path} (tried: as-is, container translation, project-relative)"
    )


def parse_firm(firm_data: Dict[str, Any]) -> Firm:
    """
    Parse firm data into Firm entity.

    Raises:
        HTTPException: If validation fails
    """
    try:
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
    except KeyError as e:
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail=f"Invalid firm data: missing field {str(e)}"
        )
    except PydanticValidationError as e:
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail=f"Invalid firm data: {str(e)}"
        )


def parse_project(project_data: Dict[str, Any]) -> Project:
    """
    Parse project data into Project entity.

    Raises:
        HTTPException: If validation fails
    """
    try:
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
    except KeyError as e:
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail=f"Invalid project data: missing field {str(e)}"
        )
    except PydanticValidationError as e:
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail=f"Invalid project data: {str(e)}"
        )


def build_infrastructure_graph(project: Project) -> Graph:
    """Build initial graph from project requirements, ensuring no cycles and robust metadata handling."""
    if not project.ops_requirements:
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail="Project has no ops_requirements"
        )

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

    Returns:
        200: Successful analysis with full results
        400: Invalid request data
        404: Data files not found
        500: Internal server error
    """
    try:
        logger.info("analysis_request_received", budget=data.budget)

        # Load data (async with proper error handling)
        firm_data = await load_data_async(data.firm_data, data.firm_path)
        project_data = await load_data_async(data.project_data, data.project_path)

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
        # use_enum_values=False ensures enums serialize as names (TYPE_A) not values
        return {
            "status": "success",
            "message": f"Comprehensive analysis complete for {project.name}",
            "analysis": analysis_result.model_dump(mode='json')
        }

    except HTTPException:
        # Re-raise HTTPExceptions with proper status codes
        raise

    except PydanticValidationError as e:
        # Request validation failed
        logger.error("request_validation_failed", error=str(e))
        raise HTTPException(
            status_code=HTTP_400_BAD_REQUEST,
            detail=f"Request validation failed: {str(e)}"
        )

    except Exception as e:
        # Catch-all for unexpected errors
        logger.error("analysis_failed", error=str(e), exc_info=True)
        raise HTTPException(
            status_code=HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Internal server error: {str(e)}"
        )


@get("/")
async def health_check() -> str:
    """Health check endpoint."""
    return "Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."


app = Litestar(route_handlers=[health_check, analyze_project])
