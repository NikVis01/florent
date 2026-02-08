#!/usr/bin/env python3
"""
Quick test script for cross-encoder functionality.
Run after starting BGE-M3 service.
"""
import asyncio
import sys
import os

# Add src to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.entities import Firm, Project, ProjectEntry, ProjectExit
from src.models.base import Country, Sectors, OperationType, StrategicFocus
from src.services.graph_builder import build_firm_contextual_graph


async def main():
    # Simple test firm
    firm = Firm(
        id="test_firm",
        name="ABC Engineering",
        description="Civil engineering consultancy",
        countries_active=[Country(name="Kenya", a2="KE", a3="KEN", numeric="404")],
        sectors=[Sectors(name="Transport", description="Roads and railways")],
        services=[OperationType(name="Engineering", category="Technical", description="Design")],
        strategic_focuses=[StrategicFocus(name="Infrastructure", description="Core focus")],
        prefered_project_timeline=24
    )

    # Simple test project
    project = Project(
        id="test_project",
        name="Highway Project",
        description="Test highway",
        country=Country(name="Kenya", a2="KE", a3="KEN", numeric="404"),
        sector="Transport",
        service_requirements=["Engineering"],
        timeline=36,
        ops_requirements=[
            OperationType(name="Design", category="Technical", description="Highway design"),
            OperationType(name="Construction", category="Execution", description="Build highway")
        ],
        entry_criteria=ProjectEntry(
            pre_requisites=["Funding"],
            mobilization_time=3,
            entry_node_id="entry"
        ),
        success_criteria=ProjectExit(
            success_metrics=["Complete"],
            mandate_end_date="2027-12-31",
            exit_node_id="exit"
        )
    )

    print("Building firm-contextual graph with cross-encoder...")
    graph = await build_firm_contextual_graph(firm, project)

    print("\nGraph built:")
    print(f"  Nodes: {len(graph.nodes)}")
    print(f"  Edges: {len(graph.edges)}")
    print("\nEdge weights:")
    for edge in graph.edges:
        print(f"  {edge.source.id} -> {edge.target.id}: {edge.weight:.3f}")


if __name__ == "__main__":
    asyncio.run(main())
