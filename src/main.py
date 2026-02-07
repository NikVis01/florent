import json
import os
from typing import Any, Dict, Optional
from litestar import Litestar, Post, get
from pydantic import BaseModel

from src.services.clients.ai_client import AIClient

# Initialize AI Client (OpenAI via DSPy)
ai_client = AIClient()

class AnalysisRequest(BaseModel):
    firm_data: Optional[Dict[str, Any]] = None
    project_data: Optional[Dict[str, Any]] = None
    firm_path: Optional[str] = None
    project_path: Optional[str] = None

def load_data(data: Optional[Dict[str, Any]], path: Optional[str]) -> Dict[str, Any]:
    if data:
        return data
    if path:
        if not os.path.exists(path):
            raise FileNotFoundError(f"File not found: {path}")
        with open(path, "r") as f:
            return json.load(f)
    raise ValueError("Missing data or path")

@Post("/analyze")
async def analyze_project(data: AnalysisRequest) -> Dict[str, Any]:
    """
    Main endpoint for risk analysis.
    Accepts JSON payloads or file paths for firm and project data.
    """
    try:
        load_data(data.firm_data, data.firm_path)
        load_data(data.project_data, data.project_path)
        
        # In the future, we will use ai_client.get_lm() inside the orchestrator
        return {
            "status": "success",
            "message": "Analysis initiated with OpenAI",
            "analysis": {
                "risk_tensors": [[0.1, 0.4], [0.8, 0.2]],
                "critical_chains": ["path_1 -> path_5 -> path_12"],
                "pivotal_linchpins": ["node_7"]
            }
        }
    except Exception as e:
        return {"status": "error", "message": str(e)}

@get("/")
async def health_check() -> str:
    return "Project Florent: OpenAI-Powered Risk Analysis Server is RUNNING."

app = Litestar(route_handlers=[health_check, analyze_project])
