#!/usr/bin/env python3
"""
Florent Analysis Visualizer

Makes API request and creates comprehensive visualizations of the risk analysis.

Usage:
    python visualize_analysis.py [--firm firm.json] [--project project.json] [--budget 100]
"""
import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Any
import requests

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Rectangle
import seaborn as sns
import networkx as nx
import pandas as pd
import numpy as np
from datetime import datetime

# Set style
sns.set_theme(style="whitegrid", palette="muted")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10


def make_api_request(firm_path: str, project_path: str, budget: int, api_url: str) -> Dict[str, Any]:
    """Make API request similar to test_api.sh."""
    print(f"Making API request to {api_url}")
    print(f"   Firm: {firm_path}")
    print(f"   Project: {project_path}")
    print(f"   Budget: {budget}")

    # Load input files
    try:
        with open(firm_path, 'r') as f:
            firm_data = json.load(f)
        with open(project_path, 'r') as f:
            project_data = json.load(f)
    except FileNotFoundError as e:
        print(f"Error: File not found - {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON - {e}")
        sys.exit(1)

    # Construct payload
    payload = {
        "firm_data": firm_data,
        "project_data": project_data,
        "budget": budget
    }

    # Make request
    try:
        response = requests.post(
            api_url,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=300  # 5 minute timeout for analysis
        )
        response.raise_for_status()

        result = response.json()
        print(f"Request successful! Status: {response.status_code}")
        return result

    except requests.exceptions.ConnectionError:
        print(f"Error: Could not connect to {api_url}")
        print("   Make sure the API server is running (python main.py --serve)")
        sys.exit(1)
    except requests.exceptions.Timeout:
        print(f"Error: Request timed out after 5 minutes")
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"Error: HTTP {response.status_code}")
        print(f"   {response.text}")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def create_network_graph(analysis: Dict[str, Any], output_dir: Path):
    """Create network graph visualization with risk coloring."""
    print("\nCreating network graph visualization...")

    # Create figure
    fig, ax = plt.subplots(figsize=(16, 12))

    # Create networkx graph
    G = nx.DiGraph()

    # Color mapping
    quadrant_colors = {
        "Safe Wins": "#2ecc71",  # green
        "Managed Risks": "#f39c12",  # orange
        "Baseline Utility": "#3498db",  # blue
        "Cooked Zone": "#e74c3c",  # red
    }

    # Build node-to-quadrant mapping
    node_quadrants = {}
    for quadrant, nodes in analysis["matrix_classifications"].items():
        for node in nodes:
            node_quadrants[node["node_id"]] = quadrant

    # Add nodes with attributes
    node_colors = []
    node_labels = {}
    node_sizes = []

    for node_id, assessment in analysis["node_assessments"].items():
        G.add_node(node_id)

        # Color by quadrant
        quadrant = node_quadrants.get(node_id, "Baseline Utility")
        color = quadrant_colors.get(quadrant, "gray")
        node_colors.append(color)

        # Label
        node_labels[node_id] = assessment["node_name"]

        # Size by influence score
        size = 1000 + (assessment["influence_score"] * 2000)
        node_sizes.append(size)

    # Try to infer edges from critical chains
    for chain in analysis["critical_chains"]:
        node_ids = chain["node_ids"]
        for i in range(len(node_ids) - 1):
            G.add_edge(node_ids[i], node_ids[i + 1])

    # If no edges from chains, create a layout-friendly structure
    if G.number_of_edges() == 0:
        nodes = list(G.nodes())
        for i in range(len(nodes) - 1):
            G.add_edge(nodes[i], nodes[i + 1])

    # Layout
    try:
        pos = nx.spring_layout(G, k=2, iterations=50, seed=42)
    except:
        pos = nx.circular_layout(G)

    # Draw network
    nx.draw_networkx_nodes(
        G, pos,
        node_color=node_colors,
        node_size=node_sizes,
        alpha=0.9,
        ax=ax
    )

    nx.draw_networkx_edges(
        G, pos,
        edge_color='gray',
        arrows=True,
        arrowsize=20,
        width=2,
        alpha=0.5,
        ax=ax
    )

    nx.draw_networkx_labels(
        G, pos,
        labels=node_labels,
        font_size=8,
        font_weight='bold',
        ax=ax
    )

    # Title and legend
    project_name = analysis["project"]["name"]
    score = analysis["summary"]["aggregate_project_score"]
    ax.set_title(
        f'Risk Analysis Network: {project_name}\nAggregate Score: {score:.1%}',
        fontsize=16,
        fontweight='bold',
        pad=20
    )

    # Create legend
    legend_elements = [
        mpatches.Patch(color=color, label=quadrant)
        for quadrant, color in quadrant_colors.items()
    ]
    ax.legend(
        handles=legend_elements,
        loc='upper left',
        fontsize=10,
        title='Risk Quadrants',
        title_fontsize=11
    )

    ax.axis('off')
    plt.tight_layout()

    # Save
    output_path = output_dir / "network_graph.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   Saved: {output_path}")
    plt.close()


def create_risk_matrix_2x2(analysis: Dict[str, Any], output_dir: Path):
    """Create 2x2 risk matrix visualization."""
    print("\nCreating 2x2 risk matrix...")

    fig, ax = plt.subplots(figsize=(12, 10))

    # Quadrant definitions (Influence, Risk)
    quadrants = {
        "Safe Wins": {"x": 0.75, "y": 0.25, "color": "#2ecc71"},
        "Managed Risks": {"x": 0.75, "y": 0.75, "color": "#f39c12"},
        "Baseline Utility": {"x": 0.25, "y": 0.25, "color": "#3498db"},
        "Cooked Zone": {"x": 0.25, "y": 0.75, "color": "#e74c3c"},
    }

    # Draw quadrant backgrounds
    for quadrant, props in quadrants.items():
        x_pos = 0 if props["x"] < 0.5 else 0.5
        y_pos = 0 if props["y"] < 0.5 else 0.5

        rect = Rectangle(
            (x_pos, y_pos), 0.5, 0.5,
            facecolor=props["color"],
            alpha=0.2,
            edgecolor='black',
            linewidth=2
        )
        ax.add_patch(rect)

        # Quadrant label
        label_x = x_pos + 0.25
        label_y = y_pos + 0.45
        count = len(analysis["matrix_classifications"].get(quadrant, []))
        ax.text(
            label_x, label_y,
            f"{quadrant}\n({count} nodes)",
            ha='center',
            va='top',
            fontsize=12,
            fontweight='bold',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.8)
        )

    # Plot nodes
    for node_id, assessment in analysis["node_assessments"].items():
        influence = assessment["influence_score"]
        risk = assessment["risk_level"]
        name = assessment["node_name"]

        # Find quadrant
        if influence >= 0.5 and risk < 0.5:
            color = quadrants["Safe Wins"]["color"]
        elif influence >= 0.5 and risk >= 0.5:
            color = quadrants["Managed Risks"]["color"]
        elif influence < 0.5 and risk < 0.5:
            color = quadrants["Baseline Utility"]["color"]
        else:
            color = quadrants["Cooked Zone"]["color"]

        # Plot point
        ax.scatter(influence, risk, s=200, c=color, alpha=0.7, edgecolors='black', linewidth=1.5)

        # Label (only if not too crowded)
        if len(analysis["node_assessments"]) <= 15:
            ax.annotate(
                name,
                (influence, risk),
                xytext=(5, 5),
                textcoords='offset points',
                fontsize=8,
                bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.7)
            )

    # Labels and formatting
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_xlabel('Influence Score →', fontsize=14, fontweight='bold')
    ax.set_ylabel('Risk Level →', fontsize=14, fontweight='bold')
    ax.axhline(y=0.5, color='black', linestyle='--', linewidth=1.5, alpha=0.5)
    ax.axvline(x=0.5, color='black', linestyle='--', linewidth=1.5, alpha=0.5)

    project_name = analysis["project"]["name"]
    cooked_pct = analysis["summary"]["cooked_zone_percentage"]
    ax.set_title(
        f'Risk Matrix (2×2): {project_name}\nCooked Zone: {cooked_pct:.1%}',
        fontsize=16,
        fontweight='bold',
        pad=20
    )

    ax.grid(True, alpha=0.3)
    plt.tight_layout()

    # Save
    output_path = output_dir / "risk_matrix_2x2.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   Saved: {output_path}")
    plt.close()


def create_critical_chains_viz(analysis: Dict[str, Any], output_dir: Path):
    """Visualize critical chains."""
    print("\nCreating critical chains visualization...")

    chains = analysis["critical_chains"][:5]  # Top 5

    if not chains:
        print("   No critical chains to visualize")
        return

    fig, ax = plt.subplots(figsize=(14, 8))

    # Prepare data
    chain_labels = [f"Chain {i+1}" for i in range(len(chains))]
    risks = [chain["cumulative_risk"] * 100 for chain in chains]
    lengths = [chain["length"] for chain in chains]

    # Color by risk level
    colors = ['#e74c3c' if r > 70 else '#f39c12' if r > 40 else '#3498db' for r in risks]

    # Create bars
    y_pos = np.arange(len(chains))
    bars = ax.barh(y_pos, risks, color=colors, alpha=0.8, edgecolor='black', linewidth=1.5)

    # Add length annotations
    for i, (bar, length) in enumerate(zip(bars, lengths)):
        width = bar.get_width()
        ax.text(
            width + 1,
            bar.get_y() + bar.get_height() / 2,
            f'{length} nodes',
            ha='left',
            va='center',
            fontweight='bold',
            fontsize=10
        )

    # Add risk percentages on bars
    for i, (bar, risk) in enumerate(zip(bars, risks)):
        width = bar.get_width()
        ax.text(
            width / 2,
            bar.get_y() + bar.get_height() / 2,
            f'{risk:.1f}%',
            ha='center',
            va='center',
            fontweight='bold',
            fontsize=11,
            color='white'
        )

    ax.set_yticks(y_pos)
    ax.set_yticklabels(chain_labels)
    ax.set_xlabel('Cumulative Risk (%)', fontsize=12, fontweight='bold')
    ax.set_title(
        'Top Critical Chains (Highest Risk Paths)',
        fontsize=16,
        fontweight='bold',
        pad=20
    )
    ax.set_xlim(0, 105)

    # Add chain details as text
    chain_text = "Chain Paths:\n" + "\n".join([
        f"Chain {i+1}: {' → '.join(chain['node_names'][:3])}{'...' if len(chain['node_names']) > 3 else ''}"
        for i, chain in enumerate(chains)
    ])

    ax.text(
        1.02, 0.5,
        chain_text,
        transform=ax.transAxes,
        fontsize=9,
        verticalalignment='center',
        bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5)
    )

    plt.tight_layout()

    # Save
    output_path = output_dir / "critical_chains.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   Saved: {output_path}")
    plt.close()


def create_summary_dashboard(analysis: Dict[str, Any], output_dir: Path):
    """Create summary metrics dashboard."""
    print("\nCreating summary dashboard...")

    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(3, 3, hspace=0.4, wspace=0.3)

    summary = analysis["summary"]
    recommendation = analysis["recommendation"]

    # 1. Aggregate Score (big gauge)
    ax1 = fig.add_subplot(gs[0, :2])
    score = summary["aggregate_project_score"] * 100
    score_color = '#2ecc71' if score > 70 else '#f39c12' if score > 40 else '#e74c3c'

    ax1.barh([0], [score], color=score_color, alpha=0.8, height=0.5)
    ax1.set_xlim(0, 100)
    ax1.set_ylim(-0.5, 0.5)
    ax1.set_yticks([])
    ax1.set_xlabel('Score (%)', fontsize=12, fontweight='bold')
    ax1.set_title(f'Aggregate Project Score: {score:.1f}%', fontsize=14, fontweight='bold')
    ax1.axvline(x=70, color='green', linestyle='--', alpha=0.5, label='Good')
    ax1.axvline(x=40, color='orange', linestyle='--', alpha=0.5, label='Moderate')
    ax1.text(score + 2, 0, f'{score:.1f}%', va='center', fontsize=14, fontweight='bold')
    ax1.grid(axis='x', alpha=0.3)

    # 2. Bid Recommendation
    ax2 = fig.add_subplot(gs[0, 2])
    should_bid = recommendation["should_bid"]
    confidence = recommendation["confidence"] * 100
    rec_color = '#2ecc71' if should_bid else '#e74c3c'
    rec_text = "BID" if should_bid else "NO BID"

    ax2.text(
        0.5, 0.6, rec_text,
        ha='center', va='center',
        fontsize=18, fontweight='bold',
        color=rec_color,
        transform=ax2.transAxes
    )
    ax2.text(
        0.5, 0.3, f'Confidence: {confidence:.0f}%',
        ha='center', va='center',
        fontsize=12,
        transform=ax2.transAxes
    )
    ax2.set_xlim(0, 1)
    ax2.set_ylim(0, 1)
    ax2.axis('off')
    ax2.set_facecolor('#f8f9fa')

    # 3. Quadrant Distribution (pie chart)
    ax3 = fig.add_subplot(gs[1, 0])
    quadrant_counts = {
        q: len(nodes) for q, nodes in analysis["matrix_classifications"].items()
    }
    colors_pie = ['#2ecc71', '#f39c12', '#3498db', '#e74c3c']
    ax3.pie(
        quadrant_counts.values(),
        labels=quadrant_counts.keys(),
        autopct='%1.0f%%',
        colors=colors_pie,
        startangle=90
    )
    ax3.set_title('Node Distribution by Quadrant', fontsize=11, fontweight='bold')

    # 4. Failure Likelihood
    ax4 = fig.add_subplot(gs[1, 1])
    failure = summary["critical_failure_likelihood"] * 100
    failure_color = '#e74c3c' if failure > 50 else '#f39c12' if failure > 25 else '#2ecc71'

    ax4.barh([0], [failure], color=failure_color, alpha=0.8, height=0.5)
    ax4.set_xlim(0, 100)
    ax4.set_ylim(-0.5, 0.5)
    ax4.set_yticks([])
    ax4.set_xlabel('Likelihood (%)', fontsize=10)
    ax4.set_title(f'Critical Failure Likelihood: {failure:.1f}%', fontsize=11, fontweight='bold')
    ax4.text(failure + 2, 0, f'{failure:.1f}%', va='center', fontsize=11, fontweight='bold')
    ax4.grid(axis='x', alpha=0.3)

    # 5. Coverage
    ax5 = fig.add_subplot(gs[1, 2])
    nodes_eval = summary["nodes_evaluated"]
    total_nodes = summary["total_nodes"]
    coverage = (nodes_eval / total_nodes * 100) if total_nodes > 0 else 0

    ax5.bar(['Evaluated', 'Total'], [nodes_eval, total_nodes], color=['#3498db', '#95a5a6'], alpha=0.8)
    ax5.set_ylabel('Node Count', fontsize=10)
    ax5.set_title(f'Coverage: {coverage:.0f}%', fontsize=11, fontweight='bold')
    ax5.grid(axis='y', alpha=0.3)

    # 6. Key Risks (text)
    ax6 = fig.add_subplot(gs[2, :2])
    risks_text = "Key Risks:\n" + "\n".join([
        f"  • {risk}" for risk in recommendation["key_risks"][:5]
    ])
    ax6.text(0.05, 0.95, risks_text, transform=ax6.transAxes,
             fontsize=10, verticalalignment='top',
             bbox=dict(boxstyle='round', facecolor='#ffe6e6', alpha=0.8))
    ax6.axis('off')

    # 7. Key Opportunities (text)
    ax7 = fig.add_subplot(gs[2, 2])
    opps_text = "Opportunities:\n" + "\n".join([
        f"  • {opp}" for opp in recommendation["key_opportunities"][:5]
    ])
    ax7.text(0.05, 0.95, opps_text, transform=ax7.transAxes,
             fontsize=10, verticalalignment='top',
             bbox=dict(boxstyle='round', facecolor='#e6ffe6', alpha=0.8))
    ax7.axis('off')

    # Main title
    project_name = analysis["project"]["name"]
    firm_name = analysis["firm"]["name"]
    fig.suptitle(
        f'Risk Analysis Dashboard: {project_name}\nFirm: {firm_name}',
        fontsize=18,
        fontweight='bold',
        y=0.98
    )

    # Save
    output_path = output_dir / "summary_dashboard.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   Saved: {output_path}")
    plt.close()


def create_node_details_table(analysis: Dict[str, Any], output_dir: Path):
    """Create detailed node assessment table."""
    print("\nCreating node details table...")

    # Prepare data
    data = []
    for node_id, assessment in analysis["node_assessments"].items():
        # Find quadrant
        quadrant = "Unknown"
        for q, nodes in analysis["matrix_classifications"].items():
            if any(n["node_id"] == node_id for n in nodes):
                quadrant = q
                break

        data.append({
            "Node": assessment["node_name"],
            "Influence": assessment["influence_score"],
            "Risk": assessment["risk_level"],
            "Quadrant": quadrant,
            "Critical Path": "✓" if assessment.get("is_on_critical_path", False) else "",
        })

    df = pd.DataFrame(data)
    df = df.sort_values("Risk", ascending=False)

    # Create figure
    fig, ax = plt.subplots(figsize=(14, max(8, len(df) * 0.4)))
    ax.axis('tight')
    ax.axis('off')

    # Color mapping
    def get_color(val, column):
        if column == "Influence":
            return '#2ecc71' if val > 0.7 else '#f39c12' if val > 0.4 else '#e74c3c'
        elif column == "Risk":
            return '#e74c3c' if val > 0.7 else '#f39c12' if val > 0.4 else '#2ecc71'
        return 'white'

    # Color cells
    cell_colors = []
    for _, row in df.iterrows():
        row_colors = [
            'white',  # Node
            get_color(row['Influence'], 'Influence'),
            get_color(row['Risk'], 'Risk'),
            'white',  # Quadrant
            '#ffeb3b' if row['Critical Path'] == '✓' else 'white',  # Critical Path
        ]
        cell_colors.append(row_colors)

    # Format values
    df['Influence'] = df['Influence'].apply(lambda x: f'{x:.2f}')
    df['Risk'] = df['Risk'].apply(lambda x: f'{x:.2f}')

    # Create table
    table = ax.table(
        cellText=df.values,
        colLabels=df.columns,
        cellLoc='center',
        loc='center',
        cellColours=cell_colors,
        colColours=['#3498db'] * len(df.columns)
    )

    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 2)

    # Style header
    for i in range(len(df.columns)):
        table[(0, i)].set_text_props(weight='bold', color='white')

    project_name = analysis["project"]["name"]
    ax.set_title(
        f'Node Assessment Details: {project_name}',
        fontsize=14,
        fontweight='bold',
        pad=20
    )

    plt.tight_layout()

    # Save
    output_path = output_dir / "node_details_table.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   Saved: {output_path}")
    plt.close()


def save_analysis_json(analysis: Dict[str, Any], output_dir: Path):
    """Save raw analysis JSON."""
    print("\nSaving analysis JSON...")
    output_path = output_dir / "analysis_output.json"

    with open(output_path, 'w') as f:
        json.dump(analysis, f, indent=2)

    print(f"   Saved: {output_path}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Visualize Florent risk analysis by making API request and generating plots"
    )
    parser.add_argument(
        "--firm",
        default="src/data/poc/firm.json",
        help="Path to firm JSON file (default: src/data/poc/firm.json)"
    )
    parser.add_argument(
        "--project",
        default="src/data/poc/project.json",
        help="Path to project JSON file (default: src/data/poc/project.json)"
    )
    parser.add_argument(
        "--budget",
        type=int,
        default=100,
        help="Analysis budget (default: 100)"
    )
    parser.add_argument(
        "--api-url",
        default="http://localhost:8000/analyze",
        help="API endpoint URL (default: http://localhost:8000/analyze)"
    )
    parser.add_argument(
        "--output-dir",
        default="output/visualizations",
        help="Output directory for visualizations (default: output/visualizations)"
    )

    args = parser.parse_args()

    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print("🎨 Florent Analysis Visualizer")
    print("=" * 70)

    # Make API request
    analysis = make_api_request(args.firm, args.project, args.budget, args.api_url)

    # Save raw JSON
    save_analysis_json(analysis, output_dir)

    # Generate visualizations
    print("\n" + "=" * 70)
    print("🎨 Generating Visualizations")
    print("=" * 70)

    try:
        create_summary_dashboard(analysis, output_dir)
        create_risk_matrix_2x2(analysis, output_dir)
        create_network_graph(analysis, output_dir)
        create_critical_chains_viz(analysis, output_dir)
        create_node_details_table(analysis, output_dir)

        print("\n" + "=" * 70)
        print("All visualizations completed!")
        print("=" * 70)
        print(f"\nOutput directory: {output_dir.absolute()}")
        print(f"\nGenerated files:")
        print(f"  • analysis_output.json - Raw analysis data")
        print(f"  • summary_dashboard.png - Overview dashboard")
        print(f"  • risk_matrix_2x2.png - 2x2 risk matrix")
        print(f"  • network_graph.png - Risk network visualization")
        print(f"  • critical_chains.png - Critical chains analysis")
        print(f"  • node_details_table.png - Detailed node assessments")

    except Exception as e:
        print(f"\nError during visualization: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
