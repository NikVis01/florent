#!/usr/bin/env python3
"""
Test the /analyze API endpoint with POC data.

This script tests the HTTP API endpoint without needing to start the server,
by directly importing and calling the endpoint function.
"""

import sys
import asyncio
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.main import analyze_project, AnalysisRequest


async def test_api_with_file_paths():
    """Test the API with file paths to POC data."""
    print("=" * 80)
    print("Testing /analyze endpoint with file paths")
    print("=" * 80)

    poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"

    request = AnalysisRequest(
        firm_path=str(poc_dir / "firm.json"),
        project_path=str(poc_dir / "project.json"),
        budget=50
    )

    print(f"\nRequest:")
    print(f"  Firm path: {request.firm_path}")
    print(f"  Project path: {request.project_path}")
    print(f"  Budget: {request.budget}")

    print("\nCalling analyze_project()...")
    response = await analyze_project(request)

    print("\n" + "=" * 80)
    print("RESPONSE")
    print("=" * 80)

    print(f"\nStatus: {response['status']}")
    print(f"Message: {response['message']}")

    if response['status'] == 'success':
        analysis = response['analysis']
        summary = analysis['summary']

        print(f"\n--- SUMMARY ---")
        print(f"Firm: {summary['firm_id']}")
        print(f"Project: {summary['project_id']}")
        print(f"Nodes Analyzed: {summary['nodes_analyzed']}")
        print(f"Overall Bankability: {summary['overall_bankability']:.1%}")
        print(f"Average Risk: {summary['average_risk']:.1%}")
        print(f"Critical Chains: {summary['critical_chains_detected']}")

        print(f"\n--- ACTION MATRIX ---")
        matrix = analysis['action_matrix']
        print(f"Mitigate: {len(matrix['mitigate'])}")
        print(f"Automate: {len(matrix['automate'])}")
        print(f"Contingency: {len(matrix['contingency'])}")
        print(f"Delegate: {len(matrix['delegate'])}")

        print(f"\n--- RECOMMENDATIONS ---")
        for i, rec in enumerate(summary['recommendations'], 1):
            print(f"{i}. {rec}")

        print("\n" + "=" * 80)
        print("API TEST PASSED")
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
        "preferred_project_timeline": 36
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
            {"name": "Financing", "category": "financing", "description": "Capital"}
        ],
        "entry_criteria": {
            "pre_requisites": ["Permit"],
            "mobilization_time": 6,
            "entry_node_id": "entry"
        },
        "success_criteria": {
            "success_metrics": ["Complete"],
            "mandate_end_date": "2026-12-31",
            "exit_node_id": "exit"
        }
    }

    request = AnalysisRequest(
        firm_data=firm_data,
        project_data=project_data,
        budget=25
    )

    print("\nCalling analyze_project() with inline data...")
    response = await analyze_project(request)

    print(f"\nStatus: {response['status']}")

    if response['status'] == 'success':
        summary = response['analysis']['summary']
        print(f"Bankability: {summary['overall_bankability']:.1%}")
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
    print("FLORENT API ENDPOINT TESTS")
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
            print("\n❌ SOME TESTS FAILED")
            return 1

    except Exception as e:
        print(f"\n❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
