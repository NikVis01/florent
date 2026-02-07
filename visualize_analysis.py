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

# Set style
sns.set_theme(style="whitegrid", palette="muted")
plt.rcParams['figure.figsize'] = (12, 8)
plt.rcParams['font.size'] = 10


def make_api_request(firm_path: str, project_path: str, budget: int, api_url: str) -> Dict[str, Any]:
    """Make API request similar to test_api.sh."""
    print(f"📡 Making API request to {api_url}")
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
        print(f"❌ Error: File not found - {e}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"❌ Error: Invalid JSON - {e}")
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
        print(f"✅ Request successful! Status: {response.status_code}")

        # Extract analysis from wrapped response
        if "analysis" in result:
            return result["analysis"]
        return result

    except requests.exceptions.ConnectionError:
        print(f"❌ Error: Could not connect to {api_url}")
        print("   Make sure the API server is running")
        sys.exit(1)
    except requests.exceptions.Timeout:
        print(f"❌ Error: Request timed out after 5 minutes")
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"❌ Error: HTTP {response.status_code}")
        print(f"   {response.text}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


def create_network_graph(analysis: Dict[str, Any], output_dir: Path):
    """Create network graph visualization with risk coloring."""
    print("\n📊 Creating network graph visualization...")

    # Create figure
    fig, ax = plt.subplots(figsize=(16, 12))

    # Create networkx graph
    G = nx.DiGraph()

    # Color mapping for action matrix quadrants
    quadrant_colors = {
        "mitigate": "#e74c3c",      # red - high risk, high influence
        "automate": "#2ecc71",       # green - low risk, high influence
        "contingency": "#f39c12",    # orange - high risk, low influence
        "delegate": "#3498db",       # blue - low risk, low influence
    }

    # Build node-to-quadrant mapping from action matrix
    node_quadrants = {}
    for quadrant, nodes in analysis.get("action_matrix", {}).items():
        for node_id in nodes:
            node_quadrants[node_id] = quadrant

    # Add nodes
    node_colors = []
    node_labels = {}
    node_sizes = []

    for node_id, assessment in analysis.get("node_assessments", {}).items():
        G.add_node(node_id)

        # Color by action matrix quadrant
        quadrant = node_quadrants.get(node_id, "delegate")
        color = quadrant_colors.get(quadrant, "gray")
        node_colors.append(color)

        # Label - clean up node_id
        label = node_id.replace("node_", "").replace("_", " ").title()
        node_labels[node_id] = label

        # Size by influence (default to 0.5 if not present)
        influence = assessment.get("influence", 0.5)
        size = 1000 + (influence * 2000)
        node_sizes.append(size)

    # Build edges from critical chains
    for chain in analysis.get("critical_chains", []):
        nodes = chain.get("nodes", [])
        for i in range(len(nodes) - 1):
            if nodes[i] in G.nodes() and nodes[i + 1] in G.nodes():
                G.add_edge(nodes[i], nodes[i + 1])

    # Layout
    try:
        if G.number_of_edges() > 0:
            pos = nx.spring_layout(G, k=2, iterations=50, seed=42)
        else:
            pos = nx.circular_layout(G)
    except:
        pos = nx.circular_layout(G)

    # Draw network
    if len(G.nodes()) > 0:
        nx.draw_networkx_nodes(
            G, pos,
            node_color=node_colors,
            node_size=node_sizes,
            alpha=0.9,
            ax=ax
        )

        if G.number_of_edges() > 0:
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

    # Title
    summary = analysis.get("summary", {})
    bankability = summary.get("overall_bankability", 0)
    ax.set_title(
        f'Risk Analysis Network\nOverall Bankability: {bankability:.1%}',
        fontsize=16,
        fontweight='bold',
        pad=20
    )

    # Create legend
    legend_elements = [
        mpatches.Patch(color=quadrant_colors["mitigate"], label="Mitigate (High Risk)"),
        mpatches.Patch(color=quadrant_colors["automate"], label="Automate (Safe)"),
        mpatches.Patch(color=quadrant_colors["contingency"], label="Contingency Plan"),
        mpatches.Patch(color=quadrant_colors["delegate"], label="Delegate"),
    ]
    ax.legend(
        handles=legend_elements,
        loc='upper left',
        fontsize=10,
        title='Action Matrix',
        title_fontsize=11
    )

    ax.axis('off')
    plt.tight_layout()

    # Save
    output_path = output_dir / "network_graph.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   ✅ Saved: {output_path}")
    plt.close()


def create_risk_matrix_2x2(analysis: Dict[str, Any], output_dir: Path):
    """Create 2x2 risk matrix visualization."""
    print("\n📊 Creating 2x2 risk matrix...")

    fig, ax = plt.subplots(figsize=(12, 10))

    # Quadrant backgrounds (action matrix)
    quadrants = {
        "Automate\n(Low Risk, High Influence)": {"x": 0.75, "y": 0.25, "color": "#2ecc71"},
        "Mitigate\n(High Risk, High Influence)": {"x": 0.75, "y": 0.75, "color": "#e74c3c"},
        "Delegate\n(Low Risk, Low Influence)": {"x": 0.25, "y": 0.25, "color": "#3498db"},
        "Contingency\n(High Risk, Low Influence)": {"x": 0.25, "y": 0.75, "color": "#f39c12"},
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
        ax.text(
            label_x, label_y,
            quadrant,
            ha='center',
            va='top',
            fontsize=11,
            fontweight='bold',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.8)
        )

    # Plot nodes
    for node_id, assessment in analysis.get("node_assessments", {}).items():
        influence = assessment.get("influence", 0.5)
        risk = assessment.get("risk", 0.5)

        # Determine color by quadrant
        if influence >= 0.5 and risk < 0.5:
            color = "#2ecc71"  # automate
        elif influence >= 0.5 and risk >= 0.5:
            color = "#e74c3c"  # mitigate
        elif influence < 0.5 and risk < 0.5:
            color = "#3498db"  # delegate
        else:
            color = "#f39c12"  # contingency

        # Plot point
        ax.scatter(influence, risk, s=200, c=color, alpha=0.7, edgecolors='black', linewidth=1.5)

        # Label
        label = node_id.replace("node_", "").replace("_", " ").title()
        if len(analysis.get("node_assessments", {})) <= 15:
            ax.annotate(
                label,
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

    summary = analysis.get("summary", {})
    avg_risk = summary.get("average_risk", 0)
    ax.set_title(
        f'Action Matrix (2×2)\nAverage Risk: {avg_risk:.1%}',
        fontsize=16,
        fontweight='bold',
        pad=20
    )

    ax.grid(True, alpha=0.3)
    plt.tight_layout()

    # Save
    output_path = output_dir / "risk_matrix_2x2.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   ✅ Saved: {output_path}")
    plt.close()


def create_critical_chains_viz(analysis: Dict[str, Any], output_dir: Path):
    """Visualize critical chains."""
    print("\n📊 Creating critical chains visualization...")

    chains = analysis.get("critical_chains", [])

    if not chains:
        print("   ⚠️  No critical chains to visualize")
        return

    fig, ax = plt.subplots(figsize=(14, 8))

    # Prepare data
    chain_labels = [f"Chain {i+1}" for i in range(len(chains))]
    risks = [chain.get("aggregate_risk", 0) * 100 for chain in chains]

    # Color by risk level
    colors = ['#e74c3c' if r > 70 else '#f39c12' if r > 40 else '#3498db' for r in risks]

    # Create bars
    y_pos = np.arange(len(chains))
    bars = ax.barh(y_pos, risks, color=colors, alpha=0.8, edgecolor='black', linewidth=1.5)

    # Add node count annotations
    for i, (bar, chain) in enumerate(zip(bars, chains)):
        width = bar.get_width()
        node_count = len(chain.get("nodes", []))
        ax.text(
            width + 1,
            bar.get_y() + bar.get_height() / 2,
            f'{node_count} nodes',
            ha='left',
            va='center',
            fontweight='bold',
            fontsize=10
        )

    # Add risk percentages on bars
    for i, (bar, risk) in enumerate(zip(bars, risks)):
        width = bar.get_width()
        if width > 10:  # Only show if bar is wide enough
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
    ax.set_xlabel('Aggregate Risk (%)', fontsize=12, fontweight='bold')
    ax.set_title(
        'Critical Dependency Chains',
        fontsize=16,
        fontweight='bold',
        pad=20
    )
    ax.set_xlim(0, min(105, max(risks) * 1.2))

    # Add chain details as text
    chain_details = []
    for i, chain in enumerate(chains[:5]):
        nodes = chain.get("nodes", [])
        node_names = [n.replace("node_", "").replace("_", " ").title() for n in nodes[:3]]
        chain_str = f"Chain {i+1}: {' → '.join(node_names)}"
        if len(nodes) > 3:
            chain_str += "..."
        chain_details.append(chain_str)

    chain_text = "Chain Paths:\n" + "\n".join(chain_details)

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
    print(f"   ✅ Saved: {output_path}")
    plt.close()


def create_summary_dashboard(analysis: Dict[str, Any], output_dir: Path):
    """Create summary metrics dashboard."""
    print("\n📊 Creating summary dashboard...")

    fig = plt.figure(figsize=(16, 10))
    gs = fig.add_gridspec(3, 3, hspace=0.4, wspace=0.3)

    summary = analysis.get("summary", {})

    # 1. Overall Bankability (big gauge)
    ax1 = fig.add_subplot(gs[0, :2])
    bankability = summary.get("overall_bankability", 0) * 100
    bankability_color = '#2ecc71' if bankability > 70 else '#f39c12' if bankability > 40 else '#e74c3c'

    ax1.barh([0], [bankability], color=bankability_color, alpha=0.8, height=0.5)
    ax1.set_xlim(0, 100)
    ax1.set_ylim(-0.5, 0.5)
    ax1.set_yticks([])
    ax1.set_xlabel('Bankability (%)', fontsize=12, fontweight='bold')
    ax1.set_title(f'Overall Bankability: {bankability:.1f}%', fontsize=14, fontweight='bold')
    ax1.axvline(x=70, color='green', linestyle='--', alpha=0.5)
    ax1.axvline(x=40, color='orange', linestyle='--', alpha=0.5)
    ax1.text(bankability + 2, 0, f'{bankability:.1f}%', va='center', fontsize=14, fontweight='bold')
    ax1.grid(axis='x', alpha=0.3)

    # 2. Risk Indicator
    ax2 = fig.add_subplot(gs[0, 2])
    avg_risk = summary.get("average_risk", 0) * 100
    max_risk = summary.get("maximum_risk", 0) * 100

    risk_color = '#e74c3c' if avg_risk > 60 else '#f39c12' if avg_risk > 30 else '#2ecc71'
    risk_status = "🔴 HIGH" if avg_risk > 60 else "🟡 MEDIUM" if avg_risk > 30 else "🟢 LOW"

    ax2.text(
        0.5, 0.6, risk_status,
        ha='center', va='center',
        fontsize=16, fontweight='bold',
        color=risk_color,
        transform=ax2.transAxes
    )
    ax2.text(
        0.5, 0.35, f'Avg: {avg_risk:.1f}%',
        ha='center', va='center',
        fontsize=11,
        transform=ax2.transAxes
    )
    ax2.text(
        0.5, 0.2, f'Max: {max_risk:.1f}%',
        ha='center', va='center',
        fontsize=11,
        transform=ax2.transAxes
    )
    ax2.set_xlim(0, 1)
    ax2.set_ylim(0, 1)
    ax2.axis('off')
    ax2.set_facecolor('#f8f9fa')

    # 3. Action Matrix Distribution (pie chart)
    ax3 = fig.add_subplot(gs[1, 0])
    action_matrix = analysis.get("action_matrix", {})
    action_counts = {
        action: len(nodes) for action, nodes in action_matrix.items() if nodes
    }

    if action_counts:
        colors_pie = ['#e74c3c', '#2ecc71', '#f39c12', '#3498db']
        ax3.pie(
            action_counts.values(),
            labels=[k.title() for k in action_counts.keys()],
            autopct='%1.0f%%',
            colors=colors_pie[:len(action_counts)],
            startangle=90
        )
        ax3.set_title('Action Matrix Distribution', fontsize=11, fontweight='bold')
    else:
        ax3.text(0.5, 0.5, 'No Data', ha='center', va='center', transform=ax3.transAxes)
        ax3.axis('off')

    # 4. Budget Usage
    ax4 = fig.add_subplot(gs[1, 1])
    nodes_analyzed = summary.get("nodes_analyzed", 0)
    budget_used = summary.get("budget_used", 0)

    ax4.bar(['Analyzed', 'Budget'], [nodes_analyzed, budget_used],
            color=['#3498db', '#95a5a6'], alpha=0.8)
    ax4.set_ylabel('Count', fontsize=10)
    ax4.set_title(f'Analysis Coverage', fontsize=11, fontweight='bold')
    ax4.grid(axis='y', alpha=0.3)

    # 5. Critical Chains
    ax5 = fig.add_subplot(gs[1, 2])
    critical_chains = summary.get("critical_chains_detected", 0)
    high_risk_nodes = summary.get("high_risk_nodes", 0)

    ax5.bar(['Critical\nChains', 'High Risk\nNodes'], [critical_chains, high_risk_nodes],
            color=['#e74c3c', '#f39c12'], alpha=0.8)
    ax5.set_ylabel('Count', fontsize=10)
    ax5.set_title('Risk Indicators', fontsize=11, fontweight='bold')
    ax5.grid(axis='y', alpha=0.3)

    # 6. Recommendations (text)
    ax6 = fig.add_subplot(gs[2, :])
    recommendations = summary.get("recommendations", [])
    if recommendations:
        rec_text = "📋 Recommendations:\n" + "\n".join([
            f"  • {rec}" for rec in recommendations[:5]
        ])
    else:
        rec_text = "📋 No specific recommendations"

    ax6.text(0.05, 0.95, rec_text, transform=ax6.transAxes,
             fontsize=10, verticalalignment='top',
             bbox=dict(boxstyle='round', facecolor='#fff4e6', alpha=0.8))
    ax6.axis('off')

    # Main title
    firm_id = summary.get("firm_id", "Unknown")
    project_id = summary.get("project_id", "Unknown")
    fig.suptitle(
        f'Risk Analysis Dashboard\nFirm: {firm_id} | Project: {project_id}',
        fontsize=18,
        fontweight='bold',
        y=0.98
    )

    # Save
    output_path = output_dir / "summary_dashboard.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   ✅ Saved: {output_path}")
    plt.close()


def create_node_details_table(analysis: Dict[str, Any], output_dir: Path):
    """Create detailed node assessment table."""
    print("\n📊 Creating node details table...")

    # Prepare data
    data = []
    action_matrix = analysis.get("action_matrix", {})

    # Build reverse lookup for action
    node_to_action = {}
    for action, nodes in action_matrix.items():
        for node_id in nodes:
            node_to_action[node_id] = action.title()

    for node_id, assessment in analysis.get("node_assessments", {}).items():
        data.append({
            "Node": node_id.replace("node_", "").replace("_", " ").title(),
            "Influence": assessment.get("influence", 0.5),
            "Risk": assessment.get("risk", 0.5),
            "Action": node_to_action.get(node_id, "Unknown"),
        })

    if not data:
        print("   ⚠️  No node data to visualize")
        return

    df = pd.DataFrame(data)
    df = df.sort_values("Risk", ascending=False)

    # Create figure
    fig, ax = plt.subplots(figsize=(14, max(8, len(df) * 0.5)))
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
            'white',  # Action
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

    ax.set_title(
        'Node Assessment Details',
        fontsize=14,
        fontweight='bold',
        pad=20
    )

    plt.tight_layout()

    # Save
    output_path = output_dir / "node_details_table.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"   ✅ Saved: {output_path}")
    plt.close()


def save_analysis_json(analysis: Dict[str, Any], output_dir: Path):
    """Save raw analysis JSON."""
    print("\n💾 Saving analysis JSON...")
    output_path = output_dir / "analysis_output.json"

    with open(output_path, 'w') as f:
        json.dump(analysis, f, indent=2)

    print(f"   ✅ Saved: {output_path}")


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
        print("✅ All visualizations completed!")
        print("=" * 70)
        print(f"\n📁 Output directory: {output_dir.absolute()}")
        print(f"\nGenerated files:")
        print(f"  • analysis_output.json - Raw analysis data")
        print(f"  • summary_dashboard.png - Overview dashboard")
        print(f"  • risk_matrix_2x2.png - Action matrix (2x2)")
        print(f"  • network_graph.png - Risk network visualization")
        print(f"  • critical_chains.png - Critical chains analysis")
        print(f"  • node_details_table.png - Detailed node assessments")

    except Exception as e:
        print(f"\n❌ Error during visualization: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
