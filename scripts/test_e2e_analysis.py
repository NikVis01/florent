#!/usr/bin/env python3
"""
End-to-End Test Script for Complete Analysis Pipeline

Tests the full workflow using POC data:
1. Load firm.json and project.json
2. Parse into entities
3. Run complete analysis pipeline
4. Display results
"""

import sys
import os
import json
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.models.entities import Firm, Project, ProjectEntry, ProjectExit
from src.models.base import Country, Sectors, StrategicFocus, OperationType
from src.services.pipeline import run_analysis


def load_poc_data():
    """Load POC data files."""
    poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"

    firm_path = poc_dir / "firm.json"
    project_path = poc_dir / "project.json"

    print(f"Loading firm data from: {firm_path}")
    with open(firm_path, 'r') as f:
        firm_data = json.load(f)

    print(f"Loading project data from: {project_path}")
    with open(project_path, 'r') as f:
        project_data = json.load(f)

    return firm_data, project_data


def parse_firm(firm_data):
    """Parse firm data into Firm entity."""
    print(f"\nParsing firm: {firm_data['name']}")

    countries = [Country(**c) for c in firm_data['countries_active']]
    sectors = [Sectors(**s) for s in firm_data['sectors']]
    services = [OperationType(**s) for s in firm_data['services']]
    focuses = [StrategicFocus(**f) for f in firm_data['strategic_focuses']]

    # Handle both old and new field names
    timeline_key = 'preferred_project_timeline' if 'preferred_project_timeline' in firm_data else 'prefered_project_timeline'

    firm = Firm(
        id=firm_data['id'],
        name=firm_data['name'],
        description=firm_data['description'],
        countries_active=countries,
        sectors=sectors,
        services=services,
        strategic_focuses=focuses,
        prefered_project_timeline=firm_data[timeline_key]
    )

    print(f"  - Active in {len(countries)} countries")
    print(f"  - {len(sectors)} sectors, {len(services)} services")
    print(f"  - Preferred timeline: {firm.prefered_project_timeline} months")

    return firm


def parse_project(project_data):
    """Parse project data into Project entity."""
    print(f"\nParsing project: {project_data['name']}")

    country = Country(**project_data['country'])
    ops = [OperationType(**op) for op in project_data['ops_requirements']]
    entry = ProjectEntry(**project_data['entry_criteria'])
    exit_criteria = ProjectExit(**project_data['success_criteria'])

    project = Project(
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

    print(f"  - Country: {country.name}")
    print(f"  - Sector: {project.sector}")
    print(f"  - Timeline: {project.timeline} months")
    print(f"  - Operations: {len(ops)}")
    print(f"  - Entry node: {entry.entry_node_id}")
    print(f"  - Exit node: {exit_criteria.exit_node_id}")

    return project


def display_results(result):
    """Display analysis results in a readable format."""
    print("\n" + "=" * 80)
    print("ANALYSIS RESULTS")
    print("=" * 80)

    summary = result['summary']

    print(f"\nFirm: {summary['firm_id']}")
    print(f"Project: {summary['project_id']}")
    print(f"Nodes Analyzed: {summary['nodes_analyzed']}")
    print(f"Budget Used: {summary['budget_used']}")

    print(f"\n--- RISK METRICS ---")
    print(f"Overall Bankability: {summary['overall_bankability']:.1%}")
    print(f"Average Risk: {summary['average_risk']:.1%}")
    print(f"Maximum Risk: {summary['maximum_risk']:.1%}")

    print(f"\n--- ACTION MATRIX (2x2) ---")
    matrix = result['action_matrix']
    print(f"Mitigate (High Risk, High Influence): {len(matrix['mitigate'])} nodes")
    if matrix['mitigate']:
        print(f"  → {', '.join(matrix['mitigate'][:3])}")

    print(f"Contingency (High Risk, Low Influence): {len(matrix['contingency'])} nodes")
    if matrix['contingency']:
        print(f"  → {', '.join(matrix['contingency'][:3])}")

    print(f"Automate (Low Risk, High Influence): {len(matrix['automate'])} nodes")
    if matrix['automate']:
        print(f"  → {', '.join(matrix['automate'][:3])}")

    print(f"Delegate (Low Risk, Low Influence): {len(matrix['delegate'])} nodes")
    if matrix['delegate']:
        print(f"  → {', '.join(matrix['delegate'][:3])}")

    print(f"\n--- CRITICAL CHAINS ---")
    chains = result['critical_chains']
    print(f"Critical Chains Detected: {len(chains)}")
    for i, chain in enumerate(chains[:3], 1):
        print(f"\n  Chain {i}: {chain['chain_id']}")
        print(f"    Aggregate Risk: {chain['aggregate_risk']:.1%}")
        print(f"    Path Length: {len(chain['nodes'])} nodes")
        print(f"    Impact: {chain['impact_description']}")

    print(f"\n--- RECOMMENDATIONS ---")
    for i, rec in enumerate(summary['recommendations'], 1):
        print(f"  {i}. {rec}")

    print("\n" + "=" * 80)
    print("NODE ASSESSMENTS (Sample)")
    print("=" * 80)

    assessments = result['node_assessments']
    for node_id, assessment in list(assessments.items())[:5]:
        print(f"\n{node_id}:")
        print(f"  Influence: {assessment['influence']:.2f}")
        print(f"  Risk: {assessment['risk']:.2f}")
        print(f"  Reasoning: {assessment['reasoning'][:80]}...")

    print("\n" + "=" * 80)


def main():
    """Run end-to-end test."""
    print("=" * 80)
    print("FLORENT E2E ANALYSIS PIPELINE TEST")
    print("=" * 80)

    try:
        # Load data
        print("\n[1/4] Loading POC data...")
        firm_data, project_data = load_poc_data()

        # Parse entities
        print("\n[2/4] Parsing entities...")
        firm = parse_firm(firm_data)
        project = parse_project(project_data)

        # Run analysis
        print("\n[3/4] Running analysis pipeline...")
        print("  - Building infrastructure graph")
        print("  - Initializing AI orchestrator")
        print("  - Running exploration (budget: 100)")
        print("  - Propagating risk")
        print("  - Generating action matrix")
        print("  - Detecting critical chains")

        result = run_analysis(firm, project, budget=100)

        # Display results
        print("\n[4/4] Displaying results...")
        display_results(result)

        print("\n" + "=" * 80)
        print("E2E TEST COMPLETED SUCCESSFULLY")
        print("=" * 80)

        return 0

    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
