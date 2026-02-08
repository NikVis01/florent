#!/usr/bin/env python3
"""
Test the /analyze API endpoint with POC data.
Updated for Influence vs Importance framework and Orchestrator V2.
"""

import sys
import asyncio
from pathlib import Path
import json

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.main import analyze_project, AnalysisRequest


async def test_api_with_file_paths():
    """Test the API with file paths to POC data."""
    print("=" * 80)
    print("Testing /analyze endpoint with file paths (Orchestrator V2)")
    print("=" * 80)

    poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"

    request = AnalysisRequest(
        firm_path=str(poc_dir / "firm.json"),
        project_path=str(poc_dir / "project.json"),
        budget=10
    )

    print("\nCalling analyze_project()...")
    if hasattr(analyze_project, "fn"):
        response = await analyze_project.fn(request)
    else:
        response = await analyze_project(request)

    print("\n" + "=" * 80)
    print("RESPONSE")
    print("=" * 80)

    print(f"\nStatus: {response['status']}")
    if 'message' in response:
        print(f"Message: {response['message']}")

    if response['status'] == 'success':
        analysis = response['analysis']
        summary = analysis['summary']

        print(f"\n--- SUMMARY ---")
        print(f"Nodes Total: {summary['total_nodes']}")
        print(f"Nodes Evaluated: {summary['nodes_evaluated']}")
        print(f"Aggregate Project Score (Success Prob): {summary['aggregate_project_score']:.1%}")
        print(f"Critical Failure Likelihood: {summary['critical_failure_likelihood']:.1%}")
        print(f"Critical Dependencies: {summary['critical_dependency_count']}")

        print(f"\n--- ALL CHAINS (Ranked by Risk) ---")
        chains = analysis.get('all_chains', [])
        print(f"Chains found: {len(chains)}")
        for i, chain in enumerate(chains[:5], 1): # Show top 5
            print(f"{i}. Risk: {chain['cumulative_risk']:.2f} | Nodes: {' -> '.join(chain['node_names'])}")

        print(f"\n--- QUADRANT CLASSIFICATION ---")
        matrix = analysis['matrix_classifications']
        for quadrant, nodes in matrix.items():
            print(f"{quadrant}: {len(nodes)} nodes")

        print(f"\n--- BID RECOMMENDATION ---")
        rec = analysis['recommendation']
        print(f"Should Bid: {rec['should_bid']}")
        print(f"Confidence: {rec['confidence']:.1%}")
        print(f"Reasoning: {rec['reasoning']}")

        print("\n" + "=" * 80)
        print("API TEST PASSED (V2)")
        print("=" * 80)
    else:
        print(f"\nError: {response.get('message')}")
        return 1

    return 0


async def test_api_with_inline_data():
    """Test the API with inline JSON data."""
    print("\n\n" + "=" * 80)
    print("Testing /analyze endpoint with inline data")
    print("=" * 80)

    firm_data = {
        "id": "test_firm",
        "name": "Test Firm",
        "description": "Testing firm",
        "countries_active": [{
            "name": "Brazil",
            "a2": "BR",
            "a3": "BRA",
            "num": "076",
            "region": "Americas",
            "sub_region": "South America",
            "affiliations": ["BRICS"]
        }],
        "sectors": [{"name": "Energy", "description": "energy"}],
        "services": [{"name": "Financing", "category": "financing", "description": "Capital"}],
        "strategic_focuses": [{"name": "Sustainability", "description": "sustainability"}],
        "prefered_project_timeline": 36
    }

    project_data = {
        "id": "test_project",
        "name": "Test Project",
        "description": "Testing project",
        "country": {
            "name": "Brazil",
            "a2": "BR",
            "a3": "BRA",
            "num": "076",
            "region": "Americas",
            "sub_region": "South America",
            "affiliations": ["BRICS"]
        },
        "sector": "energy",
        "service_requirements": ["financing"],
        "timeline": 24,
        "ops_requirements": [
            {"id": "op1", "name": "Financing", "category": "financing", "description": "Capital"}
        ],
        "entry_criteria": {
            "pre_requisites": ["Permit"],
            "mobilization_time": 6,
            "entry_node_id": "op1"
        },
        "success_criteria": {
            "success_metrics": ["Complete"],
            "mandate_end_date": "2026-12-31",
            "exit_node_id": "op1"
        }
    }

    request = AnalysisRequest(
        firm_data=firm_data,
        project_data=project_data,
        budget=1
    )

    print("\nCalling analyze_project() with inline data...")
    if hasattr(analyze_project, "fn"):
        response = await analyze_project.fn(request)
    else:
        response = await analyze_project(request)

    print(f"\nStatus: {response['status']}")

    if response['status'] == 'success':
        summary = response['analysis']['summary']
        print(f"Aggregate Score: {summary['aggregate_project_score']:.1%}")
        print("\n" + "=" * 80)
        print("INLINE DATA TEST PASSED")
        print("=" * 80)
    else:
        print(f"Error: {response.get('message')}")
        return 1

    return 0


async def main():
    """Run all API tests."""
    print("\n" + "=" * 80)
    print("FLORENT API ENDPOINT TESTS (V2)")
    print("=" * 80)

    try:
        result1 = await test_api_with_file_paths()
        result2 = await test_api_with_inline_data()

        if result1 == 0 and result2 == 0:
            print("\n" + "=" * 80)
            print("ALL API TESTS PASSED")
            print("=" * 80)
            return 0
        else:
            print("\n[ERROR] SOME TESTS FAILED")
            return 1

    except Exception as e:
        print(f"\n[ERROR] ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
