import json
import os
from typing import Any, Dict, Optional
from litestar import Litestar, post, get
from pydantic import BaseModel

from src.services.clients.ai_client import AIClient
from src.models.entities import Firm, Project, ProjectEntry, ProjectExit
from src.models.base import Country, Sectors, StrategicFocus, OperationType
from src.services.pipeline import run_analysis
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
        if not os.path.exists(path):
            raise FileNotFoundError(f"File not found: {path}")
        with open(path, "r") as f:
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

@post("/analyze")
async def analyze_project(data: AnalysisRequest) -> Dict[str, Any]:
    """
    Main endpoint for risk analysis.
    Accepts JSON payloads or file paths for firm and project data.
    """
    try:
        logger.info("analysis_request_received")

        # Load data
        firm_data = load_data(data.firm_data, data.firm_path)
        project_data = load_data(data.project_data, data.project_path)

        logger.info(
            "data_loaded",
            firm_id=firm_data.get('id'),
            project_id=project_data.get('id')
        )

        # Parse into entities
        firm = parse_firm(firm_data)
        project = parse_project(project_data)

        logger.info(
            "entities_parsed",
            firm=firm.name,
            project=project.name
        )

        # Run analysis pipeline
        budget = data.budget or 100
        analysis_result = run_analysis(firm, project, budget)

        logger.info(
            "analysis_complete",
            bankability=analysis_result['summary']['overall_bankability']
        )

        return {
            "status": "success",
            "message": f"Analysis complete for {project.name}",
            "analysis": analysis_result
        }

    except Exception as e:
        logger.error("analysis_failed", error=str(e), exc_info=True)
        return {"status": "error", "message": str(e)}

@get("/")
async def health_check() -> str:
    return "Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."

app = Litestar(route_handlers=[health_check, analyze_project])
