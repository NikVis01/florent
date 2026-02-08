#!/usr/bin/env python3
"""
Risk Propagation Demonstration

This script demonstrates the risk propagation system with a realistic
business scenario: analyzing a software development pipeline.
"""

import sys
import os

# Add src to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.models.graph import Node, Edge, Graph
from src.models.base import OperationType
from src.services.analysis.propagation import propagate_risk
from src.services.analysis.matrix import generate_matrix


def create_software_pipeline():
    """
    Create a software development pipeline graph.

    Pipeline stages:
    1. Requirements -> 2. Design -> 3. Development -> 4. Testing -> 5. Deployment

    With a parallel QA review path from Development to Testing.
    """
    # Create operation type
    op_type = OperationType(
        name="Software Development Stage",
        category="technical",
        description="A stage in the software development lifecycle"
    )

    # Create nodes for each stage
    nodes = [
        Node(id="requirements", name="Requirements Gathering", type=op_type),
        Node(id="design", name="System Design", type=op_type),
        Node(id="development", name="Code Development", type=op_type),
        Node(id="qa_review", name="QA Review", type=op_type),
        Node(id="testing", name="Integration Testing", type=op_type),
        Node(id="deployment", name="Production Deployment", type=op_type)
    ]

    # Create edges representing dependencies
    edges = [
        Edge(source=nodes[0], target=nodes[1], weight=0.9, relationship="informs"),
        Edge(source=nodes[1], target=nodes[2], weight=0.85, relationship="guides"),
        Edge(source=nodes[2], target=nodes[3], weight=0.7, relationship="reviewed_by"),
        Edge(source=nodes[2], target=nodes[4], weight=0.8, relationship="tested_in"),
        Edge(source=nodes[3], target=nodes[4], weight=0.75, relationship="validates"),
        Edge(source=nodes[4], target=nodes[5], weight=0.95, relationship="enables")
    ]

    return Graph(nodes=nodes, edges=edges)


def main():
    print("=" * 70)
    print("RISK PROPAGATION DEMONSTRATION")
    print("Scenario: Software Development Pipeline")
    print("=" * 70)
    print()

    # Create the graph
    graph = create_software_pipeline()
    print(f"Created graph with {len(graph.nodes)} nodes and {len(graph.edges)} edges")
    print()

    # Define initial assessments
    # Each node has a local failure risk and influence score
    assessments = {
        "requirements": {
            "local_risk": 0.3,   # Moderate risk - unclear requirements
            "influence": 0.95,   # Very high influence - affects everything
            "description": "Requirements are somewhat ambiguous"
        },
        "design": {
            "local_risk": 0.2,   # Lower risk - experienced architects
            "influence": 0.9,    # High influence - guides implementation
            "description": "Design team is experienced but time-constrained"
        },
        "development": {
            "local_risk": 0.25,  # Moderate risk - complex codebase
            "influence": 0.85,   # High influence - core deliverable
            "description": "Large codebase with some technical debt"
        },
        "qa_review": {
            "local_risk": 0.15,  # Low risk - thorough process
            "influence": 0.7,    # Moderate influence - can catch issues
            "description": "Comprehensive QA process in place"
        },
        "testing": {
            "local_risk": 0.2,   # Moderate risk - time pressure
            "influence": 0.8,    # High influence - quality gate
            "description": "Testing under tight deadlines"
        },
        "deployment": {
            "local_risk": 0.1,   # Low local risk - automated process
            "influence": 0.75,   # High influence - final production step
            "description": "Well-tested deployment automation"
        }
    }

    print("Initial Assessments (Local Risk & Influence):")
    print("-" * 70)
    for node_id, data in assessments.items():
        print(f"{node_id:15} | Risk: {data['local_risk']:.2f} | "
              f"Influence: {data['influence']:.2f}")
    print()

    # Propagate risk through the graph
    print("Propagating risk through dependency graph...")
    print(f"Using critical path multiplier μ = 1.2")
    print()

    result = propagate_risk(graph, assessments, multiplier=1.2)

    # Display results
    print("=" * 70)
    print("RISK PROPAGATION RESULTS")
    print("=" * 70)
    print()
    print(f"{'Stage':<15} | {'Local Risk':<11} | {'Propagated Risk':<16} | {'Influence':<9}")
    print("-" * 70)

    for node_id in ["requirements", "design", "development", "qa_review", "testing", "deployment"]:
        data = result[node_id]
        local = data['local_risk']
        propagated = data['risk']
        influence = data['influence']
        risk_increase = propagated - local

        print(f"{node_id:<15} | {local:>10.3f} | {propagated:>15.3f} | {influence:>8.2f}  "
              f"({'↑' if risk_increase > 0.1 else ' '}{risk_increase:+.3f})")

    print()
    print("Key Observations:")
    print("-" * 70)

    # Identify stages with highest risk
    sorted_by_risk = sorted(result.items(), key=lambda x: x[1]['risk'], reverse=True)
    print(f"1. Highest risk stage: {sorted_by_risk[0][0]} ({sorted_by_risk[0][1]['risk']:.3f})")
    print(f"   - This stage accumulates the most upstream risk")

    # Identify stages with biggest risk increase
    biggest_increase = max(
        [(k, v['risk'] - v['local_risk']) for k, v in result.items()],
        key=lambda x: x[1]
    )
    print(f"\n2. Largest risk amplification: {biggest_increase[0]} (+{biggest_increase[1]:.3f})")
    print(f"   - Shows how upstream failures cascade downstream")

    print()

    # Generate strategic action matrix
    print("=" * 70)
    print("STRATEGIC ACTION MATRIX")
    print("=" * 70)
    print()

    matrix = generate_matrix(result)

    quadrants = {
        "mitigate": "MITIGATE (High Risk, High Influence) - Immediate attention required",
        "automate": "AUTOMATE (Low Risk, High Influence) - Streamline and optimize",
        "contingency": "CONTINGENCY (High Risk, Low Influence) - Prepare backup plans",
        "delegate": "DELEGATE (Low Risk, Low Influence) - Routine operations"
    }

    for quadrant, description in quadrants.items():
        stages = matrix[quadrant]
        print(f"{description}")
        if stages:
            for stage in stages:
                risk = result[stage]['risk']
                influence = result[stage]['influence']
                print(f"  • {stage:<15} (Risk: {risk:.3f}, Influence: {influence:.2f})")
        else:
            print(f"  • None")
        print()

    print("=" * 70)
    print("RECOMMENDATIONS")
    print("=" * 70)
    print()

    # Generate recommendations based on matrix
    if matrix["mitigate"]:
        print("[WARNING]  CRITICAL ACTION REQUIRED:")
        for stage in matrix["mitigate"]:
            print(f"   • {stage}: High risk and high influence - needs immediate mitigation")
            print(f"     → {result[stage]['description']}")

    if matrix["automate"]:
        print("\n[OK]  OPTIMIZATION OPPORTUNITIES:")
        for stage in matrix["automate"]:
            print(f"   • {stage}: Low risk and high influence - candidate for automation")

    if matrix["contingency"]:
        print("\n CONTINGENCY PLANNING:")
        for stage in matrix["contingency"]:
            print(f"   • {stage}: High risk but lower influence - prepare backup plans")

    print()
    print("=" * 70)
    print("Analysis complete.")
    print("=" * 70)


if __name__ == "__main__":
    main()
