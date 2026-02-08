#!/usr/bin/env python3
"""
Integration test for complete pipeline using POC data.

Simpler version that doesn't require API imports.
"""

import sys
import json
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from src.models.entities import Firm, Project, ProjectEntry, ProjectExit
from src.models.base import Country, Sectors, StrategicFocus, OperationType
from src.services.pipeline import run_analysis


def main():
    """Run integration test."""
    print("=" * 80)
    print("FLORENT INTEGRATION TEST - POC DATA")
    print("=" * 80)

    try:
        # Load POC data
        poc_dir = Path(__file__).parent.parent / "src" / "data" / "poc"

        with open(poc_dir / "firm.json") as f:
            firm_data = json.load(f)

        with open(poc_dir / "project.json") as f:
            project_data = json.load(f)

        print(f"\n[OK] Loaded firm: {firm_data['name']}")
        print(f"[OK] Loaded project: {project_data['name']}")

        # Parse firm
        timeline_key = 'preferred_project_timeline' if 'preferred_project_timeline' in firm_data else 'prefered_project_timeline'
        firm = Firm(
            id=firm_data['id'],
            name=firm_data['name'],
            description=firm_data['description'],
            countries_active=[Country(**c) for c in firm_data['countries_active']],
            sectors=[Sectors(**s) for s in firm_data['sectors']],
            services=[OperationType(**s) for s in firm_data['services']],
            strategic_focuses=[StrategicFocus(**f) for f in firm_data['strategic_focuses']],
            prefered_project_timeline=firm_data[timeline_key]
        )

        # Parse project
        project = Project(
            id=project_data['id'],
            name=project_data['name'],
            description=project_data['description'],
            country=Country(**project_data['country']),
            sector=project_data['sector'],
            service_requirements=project_data['service_requirements'],
            timeline=project_data['timeline'],
            ops_requirements=[OperationType(**op) for op in project_data['ops_requirements']],
            entry_criteria=ProjectEntry(**project_data['entry_criteria']),
            success_criteria=ProjectExit(**project_data['success_criteria'])
        )

        print(f"[OK] Parsed firm entity: {firm.id}")
        print(f"[OK] Parsed project entity: {project.id}")

        # Run analysis
        print("\nRunning analysis pipeline...")
        result = run_analysis(firm, project, budget=20)

        # Verify results
        print("\n" + "=" * 80)
        print("RESULTS VERIFICATION")
        print("=" * 80)

        assert 'node_assessments' in result, "Missing node_assessments"
        assert 'action_matrix' in result, "Missing action_matrix"
        assert 'critical_chains' in result, "Missing critical_chains"
        assert 'summary' in result, "Missing summary"
        print("[OK] All required fields present")

        summary = result['summary']
        assert summary['firm_id'] == firm.id, "Firm ID mismatch"
        assert summary['project_id'] == project.id, "Project ID mismatch"
        assert 0 <= summary['overall_bankability'] <= 1, "Invalid bankability"
        print("[OK] Summary data valid")

        matrix = result['action_matrix']
        assert all(key in matrix for key in ['mitigate', 'automate', 'contingency', 'delegate']), "Missing matrix quadrants"
        print("[OK] Action matrix valid")

        print("\n" + "=" * 80)
        print("SUMMARY")
        print("=" * 80)
        print(f"Firm: {summary['firm_id']}")
        print(f"Project: {summary['project_id']}")
        print(f"Nodes Analyzed: {summary['nodes_analyzed']}")
        print(f"Overall Bankability: {summary['overall_bankability']:.1%}")
        print(f"Average Risk: {summary['average_risk']:.1%}")
        print(f"Critical Chains: {summary['critical_chains_detected']}")
        print(f"High Risk Nodes: {summary['high_risk_nodes']}")

        print("\nAction Matrix:")
        print(f"  Mitigate: {len(matrix['mitigate'])}")
        print(f"  Automate: {len(matrix['automate'])}")
        print(f"  Contingency: {len(matrix['contingency'])}")
        print(f"  Delegate: {len(matrix['delegate'])}")

        print("\nRecommendations:")
        for i, rec in enumerate(summary['recommendations'], 1):
            print(f"  {i}. {rec}")

        print("\n" + "=" * 80)
        print("INTEGRATION TEST PASSED [OK]")
        print("=" * 80)

        return 0

    except Exception as e:
        print(f"\n[ERROR] TEST FAILED: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
