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
from typing import Dict, Any, List
import requests

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Rectangle
import seaborn as sns
import networkx as nx
import pandas as pd
import numpy as np

# Premium Aesthetics Configuration
COLORS = {
    "primary": "#1a73e8",    # Google Blue
    "success": "#0d904f",    # Forest Green
    "warning": "#f9ab00",    # Amber
    "danger": "#d93025",     # Crimson
    "type_a": "#0d904f",   # Type A (Mitigation)
    "type_b": "#1a73e8",   # Type B (Optimization)
    "type_c": "#d93025",   # Type C (Contingency)
    "type_d": "#dadce0",   # Type D (Delegation)
    "mitigate": "#d93025",    # Fallback/Legacy
    "automate": "#1a73e8",    # Fallback/Legacy
    "contingency": "#f9ab00", # Fallback/Legacy
    "delegate": "#dadce0",    # Fallback/Legacy
    "slate": "#3c4043",
    "light_gray": "#f8f9fa",
    "border": "#dadce0"
}

sns.set_theme(style="white", palette="muted")
plt.rcParams['figure.facecolor'] = 'white'
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Inter', 'Roboto', 'Arial', 'DejaVu Sans']
plt.rcParams['axes.labelcolor'] = COLORS['slate']
plt.rcParams['xtick.color'] = COLORS['slate']
plt.rcParams['ytick.color'] = COLORS['slate']
plt.rcParams['axes.edgecolor'] = COLORS['border']
plt.rcParams['font.size'] = 10
plt.rcParams['axes.titlesize'] = 14
plt.rcParams['axes.titleweight'] = 'bold'


def make_api_request(firm_path: str, project_path: str, budget: int, api_url: str) -> Dict[str, Any]:
    """Make API request similar to test_api.sh."""
    print(f"Making API request to {api_url}")
    print(f"   Firm: {firm_path}")
    print(f"   Project: {project_path}")
    print(f"   Budget: {budget}")

    # Construct payload - API now accepts paths directly
    payload = {
        "firm_path": firm_path,
        "project_path": project_path,
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

        # Check for error status
        if result.get("status") == "error":
            print(f"Error from API: {result.get('message')}")
            sys.exit(1)

        # Extract analysis from wrapped response
        if "analysis" in result:
            return normalize_analysis_format(result["analysis"])
        return normalize_analysis_format(result)

    except requests.exceptions.ConnectionError:
        print(f"Error: Could not connect to {api_url}")
        print("   Make sure the API server is running")
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


def normalize_analysis_format(analysis: Dict[str, Any]) -> Dict[str, Any]:
    """
    Normalize the API response to a consistent format for visualization.
    Handles both old and new API response formats.
    """
    # If it's already in the old format, return as-is
    if "action_matrix" in analysis and "node_assessments" in analysis:
        # Old format detected
        return analysis

    # New format - convert to old format for backward compatibility
    normalized = {}

    # Convert node_assessments
    node_assessments = {}
    for node_id, assessment in analysis.get("node_assessments", {}).items():
        node_assessments[node_id] = {
            "name": assessment.get("node_name", node_id),
            "influence": assessment.get("influence_score", 0.5),
            "risk": assessment.get("risk_level", 0.5),
            "reasoning": assessment.get("reasoning", ""),
            "is_on_critical_path": assessment.get("is_on_critical_path", False),
        }
    normalized["node_assessments"] = node_assessments

    # Pass through matrix_classifications as is
    normalized["matrix_classifications"] = analysis.get("matrix_classifications", {})

    # Convert all_chains to critical_chains
    critical_chains = []
    for chain in analysis.get("all_chains", []):
        critical_chains.append({
            "nodes": chain.get("node_ids", []),
            "node_names": chain.get("node_names", []),
            "aggregate_risk": chain.get("cumulative_risk", 0.0),
            "length": chain.get("length", 0),
        })
    normalized["critical_chains"] = critical_chains

    # Convert summary
    summary = analysis.get("summary", {})
    firm_data = analysis.get("firm", {})
    project_data = analysis.get("project", {})

    normalized["summary"] = {
        "firm_id": firm_data.get("id", "unknown"),
        "project_id": project_data.get("id", "unknown"),
        "nodes_analyzed": summary.get("nodes_evaluated", 0),
        "budget_used": summary.get("nodes_evaluated", 0),
        "overall_bankability": summary.get("aggregate_project_score", 0.0),
        "aggregate_project_score": summary.get("aggregate_project_score", 0.0),
        "average_risk": 1.0 - summary.get("aggregate_project_score", 0.0),
        "maximum_risk": summary.get("critical_failure_likelihood", 0.0),
        "critical_chains_detected": len(critical_chains),
        "high_risk_nodes": summary.get("critical_dependency_count", 0),
        "recommendations": _generate_recommendations(summary, len(critical_chains)),
    }

    # Convert recommendation
    recommendation = analysis.get("recommendation", {})
    normalized["recommendation"] = {
        "should_bid": recommendation.get("should_bid", False),
        "confidence": recommendation.get("confidence", 0.0),
        "key_risks": recommendation.get("key_risks", []),
        "key_opportunities": recommendation.get("key_opportunities", []),
    }

    return normalized


def _generate_recommendations(summary: Dict[str, Any], chain_count: int) -> List[str]:
    """Generate recommendation text from summary metrics."""
    recommendations = []

    bankability = summary.get("aggregate_project_score", 0.0)
    if bankability < 0.4:
        recommendations.append("Project has significant structural risk - consider restructuring or declining")
    elif bankability < 0.7:
        recommendations.append("Project has moderate risk profile - implement tight influence controls")
    else:
        recommendations.append("Project shows strong viability - high influence over critical paths")

    if chain_count == 0:
        recommendations.append("No critical paths detected - project has good structural distribution")
    else:
        recommendations.append(f"Monitor {chain_count} critical dependency chain(s)")

    return recommendations


def create_network_graph(analysis: Dict[str, Any], output_dir: Path):
    """Create network graph visualization with risk coloring."""
    print("\n📊 Creating network graph visualization...")

    # Create figure
    fig, ax = plt.subplots(figsize=(16, 12))

    # Create networkx graph
    G = nx.DiGraph()

    # Color mapping for action matrix quadrants
    quadrant_colors = {
        # Support full strings from RiskQuadrant enum
        "Type A (High Influence / High Importance)": COLORS["type_a"],
        "Type B (High Influence / Low Importance)": COLORS["type_b"],
        "Type C (Low Influence / High Importance)": COLORS["type_c"],
        "Type D (Low Influence / Low Importance)": COLORS["type_d"],
        # Support short strings from legacy/test logic
        "Type A": COLORS["type_a"],
        "Type B": COLORS["type_b"],
        "Type C": COLORS["type_c"],
        "Type D": COLORS["type_d"],
        # Legacy fallbacks
        "mitigate": COLORS["mitigate"],
        "automate": COLORS["automate"],
        "contingency": COLORS["contingency"],
        "delegate": COLORS["delegate"],
    }

    # Build node-to-quadrant mapping from classifications
    node_quadrants = {}
    for quadrant, entries in analysis.get("matrix_classifications", {}).items():
        for entry in entries:
                node_id = entry.get("node_id") if isinstance(entry, dict) else entry
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
        mpatches.Patch(color=COLORS["type_a"], label="Type A"),
        mpatches.Patch(color=COLORS["type_b"], label="Type B"),
        mpatches.Patch(color=COLORS["type_c"], label="Type C"),
        mpatches.Patch(color=COLORS["type_d"], label="Type D"),
    ]
    ax.legend(
        handles=legend_elements,
        loc='upper left',
        fontsize=10,
        title='Risk Framework',
        title_fontsize=11
    )

    ax.axis('off')
    plt.tight_layout()

    # Save
    output_path = output_dir / "network_graph.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_risk_matrix_2x2(analysis: Dict[str, Any], output_dir: Path):
    """Create 2x2 risk matrix visualization."""
    print("\n📊 Creating 2x2 risk matrix...")

    fig, ax = plt.subplots(figsize=(12, 10))

    # Quadrant backgrounds
    quadrants = {
        "Type B\n(High Influence, Low Importance)": {"x": 0.75, "y": 0.25, "color": COLORS["type_b"]},
        "Type A\n(High Influence, High Importance)": {"x": 0.75, "y": 0.75, "color": COLORS["type_a"]},
        "Type D\n(Low Influence, Low Importance)": {"x": 0.25, "y": 0.25, "color": COLORS["type_d"]},
        "Type C\n(Low Influence, High Importance)": {"x": 0.25, "y": 0.75, "color": COLORS["type_c"]},
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
    ax.set_xlabel('Influence Score ->', fontsize=12, color=COLORS['slate'])
    ax.set_ylabel('Risk Level ->', fontsize=12, color=COLORS['slate'])
    ax.axhline(y=0.5, color='black', linestyle='--', linewidth=1.5, alpha=0.5)
    ax.axvline(x=0.5, color='black', linestyle='--', linewidth=1.5, alpha=0.5)

    summary = analysis.get("summary", {})
    avg_risk = summary.get("average_risk", 0)
    ax.set_title(
        f'Action Matrix (2x2)\nAverage Risk: {avg_risk:.1%}',
        fontsize=16,
        fontweight='bold',
        pad=20
    )

    ax.grid(True, alpha=0.3)
    plt.tight_layout()

    # Save
    output_path = output_dir / "risk_matrix_2x2.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
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
        chain_str = f"Chain {i+1}: {' -> '.join(node_names)}"
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
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
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
    bankability_color = COLORS['success'] if bankability > 70 else COLORS['warning'] if bankability > 40 else COLORS['danger']

    # Background track
    ax1.barh([0], [100], color=COLORS['light_gray'], height=0.4, alpha=0.5)
    # Active track
    ax1.barh([0], [bankability], color=bankability_color, alpha=0.9, height=0.4)
    
    ax1.set_xlim(0, 100)
    ax1.set_ylim(-0.5, 0.5)
    ax1.set_yticks([])
    ax1.set_xlabel('Bankability Rating (%)', fontsize=11, color=COLORS['slate'])
    ax1.set_title(f'Overall Project Bankability: {bankability:.1f}%', fontsize=15, pad=15)
    
    # Threshold markers
    ax1.axvline(x=70, color=COLORS['success'], linestyle=':', alpha=0.3)
    ax1.axvline(x=40, color=COLORS['warning'], linestyle=':', alpha=0.3)
    
    # Value label
    ax1.text(bankability - 2 if bankability > 10 else 2, 0, f'{bankability:.1f}%', 
             va='center', ha='right' if bankability > 10 else 'left',
             fontsize=14, fontweight='bold', color='white' if bankability > 10 else COLORS['slate'])
    
    sns.despine(ax=ax1, left=True, bottom=False, offset=5)

    # 2. Risk Indicator
    ax2 = fig.add_subplot(gs[0, 2])
    avg_risk = summary.get("average_risk", 0) * 100
    max_risk = summary.get("maximum_risk", 0) * 100

    risk_color = COLORS['danger'] if avg_risk > 60 else COLORS['warning'] if avg_risk > 30 else COLORS['success']
    risk_status = "HIGH" if avg_risk > 60 else "MEDIUM" if avg_risk > 30 else "LOW"

    # Add a card background
    card = Rectangle((0.05, 0.05), 0.9, 0.9, facecolor=risk_color, alpha=0.1, 
                    edgecolor=risk_color, linewidth=2, transform=ax2.transAxes, clip_on=False)
    ax2.add_patch(card)

    ax2.text(
        0.5, 0.65, risk_status,
        ha='center', va='center',
        fontsize=22, fontweight='black',
        color=risk_color,
        transform=ax2.transAxes
    )
    ax2.text(0.5, 0.45, "RISK ASSESSMENT", ha='center', fontsize=9, fontweight='bold', color=COLORS['slate'], transform=ax2.transAxes)
    ax2.text(0.5, 0.25, f'Avg: {avg_risk:.1f}% | Max: {max_risk:.1f}%', ha='center', fontsize=11, color=COLORS['slate'], transform=ax2.transAxes)
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
        colors_pie = [COLORS[k.lower().replace(" ", "_")] for k in action_counts.keys()]
        ax3.pie(
            action_counts.values(),
            labels=[k for k in action_counts.keys()],
            autopct='%1.0f%%',
            colors=colors_pie,
            startangle=140,
            pctdistance=0.8,
            explode=[0.05] * len(action_counts)
        )
        # Draw center circle for donut chart
        centre_circle = plt.Circle((0,0), 0.60, fc='white')
        ax3.add_artist(centre_circle)
        ax3.set_title('Strategic Allocation', fontsize=12, fontweight='bold', pad=10)
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

    ax5.bar(['Chains', 'Risky Nodes'], [critical_chains, high_risk_nodes],
            color=[COLORS['danger'], COLORS['warning']], alpha=0.8, width=0.6)
    ax5.set_ylabel('Count', fontsize=9)
    ax5.set_title('Critical Exposure', fontsize=11, fontweight='bold')
    sns.despine(ax=ax5)

    ax6 = fig.add_subplot(gs[2, :])
    recommendations = summary.get("recommendations", [])
    if recommendations:
        rec_text = "Strategic Recommendations:\n" + "\n".join([
            f"  > {rec}" for rec in recommendations[:4]
        ])
    else:
        rec_text = "No specific strategic recommendations detected."

    ax6.text(0.02, 0.9, rec_text, transform=ax6.transAxes,
             fontsize=12, verticalalignment='top', linespacing=1.8,
             color=COLORS['slate'],
             bbox=dict(boxstyle='round,pad=1.5', facecolor=COLORS['light_gray'], alpha=0.3, edgecolor=COLORS['border']))
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
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_node_details_table(analysis: Dict[str, Any], output_dir: Path):
    """Create detailed node assessment table."""
    print("\n📊 Creating node details table...")

    # Prepare data
    data = []
    matrix_classifications = analysis.get("matrix_classifications", {})

    # Build reverse lookup for action
    node_to_action = {}
    for quadrant, entries in matrix_classifications.items():
        for entry in entries:
            node_id = entry.get("node_id") if isinstance(entry, dict) else entry
            node_to_action[node_id] = quadrant

    for node_id, assessment in analysis.get("node_assessments", {}).items():
        risk = assessment.get("risk", 0.5) if "risk" in assessment else assessment.get("risk_level", 0.5)
        data.append({
            "Node": node_id.replace("node_", "").replace("_", " ").title(),
            "Influence": assessment.get("influence", 0.5) if "influence" in assessment else assessment.get("influence_score", 0.5),
            "Risk": risk,
            "Classification": node_to_action.get(node_id, "Unknown"),
            "Critical": "Yes" if assessment.get("is_on_critical_path", False) else "No",
        })

    if not data:
        print("   ⚠️  No node data to visualize")
        return

    df = pd.DataFrame(data)
    df = df.sort_values("Risk", ascending=False)

    # Create figure
    fig, ax = plt.subplots(figsize=(16, max(8, len(df) * 0.5)))
    ax.axis('tight')
    ax.axis('off')

    def get_color(val, column):
        if column == "Influence":
            return COLORS['success'] if val > 0.7 else COLORS['warning'] if val > 0.4 else COLORS['danger']
        elif column == "Risk":
            return COLORS['danger'] if val > 0.7 else COLORS['warning'] if val > 0.4 else COLORS['success']
        return 'white'

    # Color cells
    cell_colors = []
    for _, row in df.iterrows():
        row_colors = [
            'white',  # Node
            get_color(row['Influence'], 'Influence'),
            get_color(row['Risk'], 'Risk'),
            'white',  # Action
            'white',  # Critical
        ]
        cell_colors.append(row_colors)

    # Format values for display
    df_display = df.copy()
    df_display['Influence'] = df['Influence'].apply(lambda x: f'{x:.2f}')
    df_display['Risk'] = df['Risk'].apply(lambda x: f'{x:.2f}')

    table = ax.table(
        cellText=df_display.values,
        colLabels=df_display.columns,
        cellLoc='center',
        loc='center',
        cellColours=cell_colors,
        colColours=[COLORS['primary']] * len(df_display.columns)
    )

    table.auto_set_font_size(False)
    table.set_fontsize(9)
    table.scale(1, 2)

    # Style header
    for i in range(len(df_display.columns)):
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
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_risk_influence_scatter(analysis: Dict[str, Any], output_dir: Path):
    """Create detailed scatter plot of risk vs influence."""
    print("\n📊 Creating risk vs influence scatter plot...")

    fig, ax = plt.subplots(figsize=(14, 10))

    # Collect data
    nodes_data = []
    action_matrix = analysis.get("action_matrix", {})
    node_to_action = {}
    for action, nodes in action_matrix.items():
        for node_id in nodes:
            node_to_action[node_id] = action

    for node_id, assessment in analysis.get("node_assessments", {}).items():
        influence = assessment.get("influence", 0.5)
        risk = assessment.get("risk", 0.5)
        action = node_to_action.get(node_id, "unknown")
        nodes_data.append({
            "id": node_id,
            "name": assessment.get("name", node_id),
            "influence": influence,
            "risk": risk,
            "action": action,
            "critical": assessment.get("is_on_critical_path", False)
        })

    if not nodes_data:
        print("   ⚠️  No data to visualize")
        return

    # Plot each node
    for node in nodes_data:
        color = COLORS.get(node["action"], "#95a5a6")
        marker = 'D' if node["critical"] else 'o'
        size = 400 if node["critical"] else 250

        ax.scatter(
            node["influence"], node["risk"],
            s=size, c=color, alpha=0.7,
            edgecolors='black', linewidth=2,
            marker=marker
        )

        # Add label
        ax.annotate(
            node["name"],
            (node["influence"], node["risk"]),
            xytext=(8, 8),
            textcoords='offset points',
            fontsize=9,
            fontweight='bold',
            bbox=dict(boxstyle='round,pad=0.5', facecolor='white', alpha=0.8, edgecolor=color, linewidth=2)
        )

    # Add quadrant lines
    ax.axhline(y=0.5, color='black', linestyle='--', linewidth=2, alpha=0.3)
    ax.axvline(x=0.5, color='black', linestyle='--', linewidth=2, alpha=0.3)

    # Quadrant labels
    ax.text(0.75, 0.95, 'Type A\n(High Risk, High Influence)', ha='center', va='top',
            fontsize=11, fontweight='bold', bbox=dict(boxstyle='round', facecolor=COLORS['type_a'], alpha=0.2))
    ax.text(0.75, 0.05, 'Type B\n(Low Risk, High Influence)', ha='center', va='bottom',
            fontsize=11, fontweight='bold', bbox=dict(boxstyle='round', facecolor=COLORS['type_b'], alpha=0.2))
    ax.text(0.25, 0.95, 'Type C\n(High Risk, Low Influence)', ha='center', va='top',
            fontsize=11, fontweight='bold', bbox=dict(boxstyle='round', facecolor=COLORS['type_c'], alpha=0.2))
    ax.text(0.25, 0.05, 'Type D\n(Low Risk, Low Influence)', ha='center', va='bottom',
            fontsize=11, fontweight='bold', bbox=dict(boxstyle='round', facecolor=COLORS['type_d'], alpha=0.2))

    ax.set_xlim(-0.05, 1.05)
    ax.set_ylim(-0.05, 1.05)
    ax.set_xlabel('Influence Score →', fontsize=13, fontweight='bold')
    ax.set_ylabel('Risk Level →', fontsize=13, fontweight='bold')
    ax.set_title('Risk vs Influence Analysis (Detailed)', fontsize=16, fontweight='bold', pad=20)
    ax.grid(True, alpha=0.2, linestyle=':')

    # Legend
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='gray', markersize=10, label='Standard Node'),
        Line2D([0], [0], marker='D', color='w', markerfacecolor='gray', markersize=10, label='Critical Path'),
    ]
    ax.legend(handles=legend_elements, loc='upper right', fontsize=10)

    plt.tight_layout()
    output_path = output_dir / "risk_influence_scatter.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_distribution_histograms(analysis: Dict[str, Any], output_dir: Path):
    """Create distribution histograms for risk and influence."""
    print("\n📊 Creating distribution histograms...")

    node_assessments = analysis.get("node_assessments", {})
    if not node_assessments:
        print("   ⚠️  No data to visualize")
        return

    risks = [a.get("risk", 0.5) for a in node_assessments.values()]
    influences = [a.get("influence", 0.5) for a in node_assessments.values()]

    fig, axes = plt.subplots(1, 2, figsize=(16, 6))

    # Risk distribution
    ax1 = axes[0]
    ax1.hist(risks, bins=15, color=COLORS['danger'], alpha=0.7, edgecolor='black', linewidth=1.5)
    ax1.axvline(np.mean(risks), color='black', linestyle='--', linewidth=2, label=f'Mean: {np.mean(risks):.2f}')
    ax1.axvline(np.median(risks), color='blue', linestyle=':', linewidth=2, label=f'Median: {np.median(risks):.2f}')
    ax1.set_xlabel('Risk Level', fontsize=12, fontweight='bold')
    ax1.set_ylabel('Frequency', fontsize=12, fontweight='bold')
    ax1.set_title('Risk Distribution', fontsize=14, fontweight='bold')
    ax1.legend()
    ax1.grid(axis='y', alpha=0.3)

    # Influence distribution
    ax2 = axes[1]
    ax2.hist(influences, bins=15, color=COLORS['success'], alpha=0.7, edgecolor='black', linewidth=1.5)
    ax2.axvline(np.mean(influences), color='black', linestyle='--', linewidth=2, label=f'Mean: {np.mean(influences):.2f}')
    ax2.axvline(np.median(influences), color='blue', linestyle=':', linewidth=2, label=f'Median: {np.median(influences):.2f}')
    ax2.set_xlabel('Influence Score', fontsize=12, fontweight='bold')
    ax2.set_ylabel('Frequency', fontsize=12, fontweight='bold')
    ax2.set_title('Influence Distribution', fontsize=14, fontweight='bold')
    ax2.legend()
    ax2.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    output_path = output_dir / "distributions.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_radar_chart(analysis: Dict[str, Any], output_dir: Path):
    """Create radar chart for overall project assessment."""
    print("\n📊 Creating radar chart...")

    summary = analysis.get("summary", {})

    # Metrics for radar chart
    categories = ['Bankability', 'Low Risk', 'High Influence', 'Chain Safety', 'Budget Efficiency']

    # Calculate scores (normalized to 0-1)
    bankability = summary.get("overall_bankability", 0)
    low_risk = 1 - summary.get("average_risk", 0)
    high_influence = np.mean([a.get("influence", 0) for a in analysis.get("node_assessments", {}).values()]) if analysis.get("node_assessments") else 0
    chain_safety = 1.0 if summary.get("critical_chains_detected", 0) == 0 else max(0, 1 - summary.get("critical_chains_detected", 0) / 10)
    budget_eff = min(1.0, summary.get("nodes_analyzed", 0) / max(1, summary.get("budget_used", 1)))

    values = [bankability, low_risk, high_influence, chain_safety, budget_eff]

    # Number of variables
    num_vars = len(categories)
    angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
    values += values[:1]  # Complete the circle
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(10, 10), subplot_kw=dict(projection='polar'))

    ax.plot(angles, values, 'o-', linewidth=3, color=COLORS['primary'], label='Project Score')
    ax.fill(angles, values, alpha=0.25, color=COLORS['primary'])

    # Add reference circle at 0.7 (good threshold)
    ax.plot(angles, [0.7] * len(angles), '--', linewidth=1.5, color=COLORS['success'], alpha=0.5, label='Target (70%)')

    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories, size=11, fontweight='bold')
    ax.set_ylim(0, 1)
    ax.set_yticks([0.2, 0.4, 0.6, 0.8, 1.0])
    ax.set_yticklabels(['20%', '40%', '60%', '80%', '100%'])
    ax.grid(True, linestyle=':', alpha=0.3)
    ax.set_title('Project Assessment Radar', fontsize=16, fontweight='bold', pad=30)
    ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.1))

    plt.tight_layout()
    output_path = output_dir / "radar_chart.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_node_comparison_bars(analysis: Dict[str, Any], output_dir: Path):
    """Create comparative bar chart for nodes."""
    print("\n📊 Creating node comparison chart...")

    node_assessments = analysis.get("node_assessments", {})
    if not node_assessments:
        print("   ⚠️  No data to visualize")
        return

    # Prepare data
    nodes = []
    influences = []
    risks = []

    for node_id, assessment in node_assessments.items():
        name = assessment.get("name", node_id.replace("node_", "").replace("_", " ").title())
        nodes.append(name)
        influences.append(assessment.get("influence", 0.5))
        risks.append(assessment.get("risk", 0.5))

    x = np.arange(len(nodes))
    width = 0.35

    fig, ax = plt.subplots(figsize=(14, 8))

    bars1 = ax.bar(x - width/2, influences, width, label='Influence',
                   color=COLORS['success'], alpha=0.8, edgecolor='black', linewidth=1.5)
    bars2 = ax.bar(x + width/2, risks, width, label='Risk',
                   color=COLORS['danger'], alpha=0.8, edgecolor='black', linewidth=1.5)

    # Add value labels on bars
    for bars in [bars1, bars2]:
        for bar in bars:
            height = bar.get_height()
            ax.text(bar.get_x() + bar.get_width()/2., height,
                   f'{height:.2f}',
                   ha='center', va='bottom', fontsize=9, fontweight='bold')

    ax.set_xlabel('Nodes', fontsize=12, fontweight='bold')
    ax.set_ylabel('Score', fontsize=12, fontweight='bold')
    ax.set_title('Node Comparison: Influence vs Risk', fontsize=16, fontweight='bold', pad=20)
    ax.set_xticks(x)
    ax.set_xticklabels(nodes, rotation=45, ha='right')
    ax.legend(fontsize=11)
    ax.set_ylim(0, 1.1)
    ax.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    output_path = output_dir / "node_comparison.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_recommendation_viz(analysis: Dict[str, Any], output_dir: Path):
    """Create recommendation visualization."""
    print("\n📊 Creating recommendation visualization...")

    recommendation = analysis.get("recommendation", {})
    summary = analysis.get("summary", {})

    should_bid = recommendation.get("should_bid", False)
    confidence = recommendation.get("confidence", 0) * 100

    fig = plt.figure(figsize=(14, 10))
    gs = fig.add_gridspec(2, 2, hspace=0.3, wspace=0.3)

    # 1. Decision Card
    ax1 = fig.add_subplot(gs[0, :])
    decision_color = COLORS['success'] if should_bid else COLORS['danger']
    decision_text = "RECOMMEND BID" if should_bid else "DO NOT BID"

    ax1.text(0.5, 0.6, decision_text, ha='center', va='center',
            fontsize=32, fontweight='black', color=decision_color,
            transform=ax1.transAxes)
    ax1.text(0.5, 0.35, f'Confidence: {confidence:.1f}%', ha='center', va='center',
            fontsize=18, fontweight='bold', color=COLORS['slate'],
            transform=ax1.transAxes)

    # Add confidence bar
    bar_width = 0.6
    bar_x = 0.5 - bar_width/2
    rect_bg = Rectangle((bar_x, 0.15), bar_width, 0.08,
                        facecolor=COLORS['light_gray'], transform=ax1.transAxes)
    ax1.add_patch(rect_bg)

    rect_fill = Rectangle((bar_x, 0.15), bar_width * (confidence/100), 0.08,
                          facecolor=decision_color, alpha=0.8, transform=ax1.transAxes)
    ax1.add_patch(rect_fill)

    ax1.set_xlim(0, 1)
    ax1.set_ylim(0, 1)
    ax1.axis('off')

    # 2. Key Risks
    ax2 = fig.add_subplot(gs[1, 0])
    key_risks = recommendation.get("key_risks", [])

    if key_risks:
        risk_text = "Key Risks:\n\n" + "\n\n".join([f"• {risk}" for risk in key_risks])
    else:
        risk_text = "No critical risks identified"

    ax2.text(0.05, 0.95, risk_text, transform=ax2.transAxes,
            fontsize=11, verticalalignment='top', linespacing=1.6,
            bbox=dict(boxstyle='round,pad=1', facecolor='#ffe6e6', alpha=0.8, edgecolor=COLORS['danger'], linewidth=2))
    ax2.set_xlim(0, 1)
    ax2.set_ylim(0, 1)
    ax2.axis('off')
    ax2.set_title('Risk Assessment', fontsize=13, fontweight='bold', pad=10)

    # 3. Key Opportunities
    ax3 = fig.add_subplot(gs[1, 1])
    key_opportunities = recommendation.get("key_opportunities", [])

    if key_opportunities:
        opp_text = "Key Opportunities:\n\n" + "\n\n".join([f"• {opp}" for opp in key_opportunities])
    else:
        opp_text = "Limited opportunities identified"

    ax3.text(0.05, 0.95, opp_text, transform=ax3.transAxes,
            fontsize=11, verticalalignment='top', linespacing=1.6,
            bbox=dict(boxstyle='round,pad=1', facecolor='#e6f7e6', alpha=0.8, edgecolor=COLORS['success'], linewidth=2))
    ax3.set_xlim(0, 1)
    ax3.set_ylim(0, 1)
    ax3.axis('off')
    ax3.set_title('Strategic Opportunities', fontsize=13, fontweight='bold', pad=10)

    fig.suptitle('Strategic Recommendation', fontsize=18, fontweight='bold', y=0.98)

    output_path = output_dir / "recommendation.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def _draw_gauge(ax, value: float, max_value: float, color: str, label: str):
    """Draw a simple gauge/progress bar visualization."""
    percentage = min(value / max_value if max_value > 0 else 0, 1.0)
    
    # Background bar
    ax.barh([0], [1.0], height=0.3, color=COLORS['light_gray'], alpha=0.3, left=0)
    # Filled bar
    ax.barh([0], [percentage], height=0.3, color=color, alpha=0.8, left=0)
    
    # Value text
    ax.text(0.5, 0.5, f'{value:.0f}', ha='center', va='center',
           fontsize=24, fontweight='bold', color=COLORS['slate'],
           transform=ax.transAxes)
    ax.text(0.5, 0.15, label, ha='center', va='center',
           fontsize=10, color=COLORS['slate'], transform=ax.transAxes)
    
    ax.set_xlim(0, 1)
    ax.set_ylim(-0.2, 0.2)
    ax.axis('off')


def _draw_risk_gauge(ax, risk_value: float, label: str):
    """Draw a risk gauge with color coding."""
    risk_pct = min(risk_value * 100, 100)
    
    # Determine color based on risk level
    if risk_pct > 70:
        color = COLORS['danger']
        risk_level = "HIGH"
    elif risk_pct > 40:
        color = COLORS['warning']
        risk_level = "MEDIUM"
    else:
        color = COLORS['success']
        risk_level = "LOW"
    
    # Circular gauge representation (simplified as progress bar)
    ax.barh([0], [1.0], height=0.4, color=COLORS['light_gray'], alpha=0.3, left=0)
    ax.barh([0], [risk_pct / 100], height=0.4, color=color, alpha=0.8, left=0)
    
    # Value and label
    ax.text(0.5, 0.6, f'{risk_pct:.1f}%', ha='center', va='center',
           fontsize=22, fontweight='bold', color=color, transform=ax.transAxes)
    ax.text(0.5, 0.3, label, ha='center', va='center',
           fontsize=10, color=COLORS['slate'], transform=ax.transAxes)
    ax.text(0.5, 0.1, risk_level, ha='center', va='center',
           fontsize=9, fontweight='bold', color=color, transform=ax.transAxes)
    
    ax.set_xlim(0, 1)
    ax.set_ylim(-0.3, 0.3)
    ax.axis('off')


def _draw_metric_card(ax, value, label: str, icon_color: str = None, show_bar: bool = False):
    """Draw an enhanced metric card with visual elements."""
    if icon_color is None:
        icon_color = COLORS['primary']
    
    # Background
    ax.set_facecolor(COLORS['light_gray'])
    
    # Value display
    if isinstance(value, (int, float)):
        value_str = f'{value:.0f}' if value == int(value) else f'{value:.1f}'
    else:
        value_str = str(value)
    
    ax.text(0.5, 0.65, value_str, ha='center', va='center',
           fontsize=26, fontweight='bold', color=icon_color,
           transform=ax.transAxes)
    
    # Label
    ax.text(0.5, 0.3, label, ha='center', va='center',
           fontsize=11, color=COLORS['slate'], transform=ax.transAxes)
    
    # Optional progress bar at bottom
    if show_bar and isinstance(value, (int, float)) and value > 0:
        max_val = max(value * 1.5, 100)  # Dynamic max
        bar_width = min(value / max_val, 1.0)
        ax.barh([0.05], [bar_width], height=0.03, color=icon_color, alpha=0.6,
               left=0.1, transform=ax.transAxes)
    
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')


def create_comprehensive_report(analysis: Dict[str, Any], output_dir: Path):
    """Create a comprehensive single-page report."""
    print("\n📊 Creating comprehensive report...")

    fig = plt.figure(figsize=(20, 24))
    gs = fig.add_gridspec(6, 3, hspace=0.4, wspace=0.3)

    summary = analysis.get("summary", {})
    recommendation = analysis.get("recommendation", {})
    
    # Extract firm and project names from nested structure
    firm_data = analysis.get("firm", {})
    project_data = analysis.get("project", {})
    firm_name = firm_data.get("name", summary.get("firm_id", "Unknown"))
    project_name = project_data.get("name", summary.get("project_id", "Unknown"))

    # Header Section
    ax_header = fig.add_subplot(gs[0, :])
    bankability = summary.get("overall_bankability", 0) * 100

    ax_header.text(0.5, 0.7, f'PROJECT RISK ANALYSIS REPORT',
                  ha='center', va='center', fontsize=24, fontweight='black',
                  transform=ax_header.transAxes, color=COLORS['primary'])
    ax_header.text(0.5, 0.4, f'Firm: {firm_name} | Project: {project_name}',
                  ha='center', va='center', fontsize=14,
                  transform=ax_header.transAxes, color=COLORS['slate'])
    ax_header.text(0.5, 0.15, f'Bankability Rating: {bankability:.1f}%',
                  ha='center', va='center', fontsize=16, fontweight='bold',
                  transform=ax_header.transAxes,
                  color=COLORS['success'] if bankability > 70 else COLORS['warning'] if bankability > 40 else COLORS['danger'])
    ax_header.axis('off')

    # Executive Summary Metrics
    # Figure 2: Nodes Analyzed
    ax2 = fig.add_subplot(gs[1, 0])
    nodes_analyzed = summary.get("nodes_analyzed", 0)
    total_nodes = len(analysis.get("node_assessments", {}))
    if total_nodes == 0:
        total_nodes = max(nodes_analyzed, 1)  # Fallback to avoid division by zero
    _draw_gauge(ax2, nodes_analyzed, total_nodes, COLORS['primary'], "Nodes Analyzed")
    
    # Figure 3: Avg Risk
    ax3 = fig.add_subplot(gs[1, 1])
    avg_risk = summary.get("average_risk", 0)
    _draw_risk_gauge(ax3, avg_risk, "Average Risk")
    
    # Figure 4: Max Risk
    ax4 = fig.add_subplot(gs[1, 2])
    max_risk = summary.get("maximum_risk", 0)
    _draw_risk_gauge(ax4, max_risk, "Maximum Risk")
    
    # Figure 5: Critical Chains
    ax5 = fig.add_subplot(gs[2, 0])
    critical_chains = summary.get("critical_chains_detected", 0)
    # Determine color based on chain count
    if critical_chains > 3:
        chain_color = COLORS['danger']
        chain_status = "CRITICAL"
    elif critical_chains > 0:
        chain_color = COLORS['warning']
        chain_status = "WARNING"
    else:
        chain_color = COLORS['success']
        chain_status = "SAFE"
    
    # Visual representation with icon-like indicator
    ax5.barh([0.3], [min(critical_chains / 10.0, 1.0)], height=0.15, 
            color=chain_color, alpha=0.8, left=0.1, transform=ax5.transAxes)
    ax5.text(0.5, 0.65, f'{critical_chains}', ha='center', va='center',
            fontsize=28, fontweight='bold', color=chain_color, transform=ax5.transAxes)
    ax5.text(0.5, 0.35, "Critical Chains", ha='center', va='center',
            fontsize=11, color=COLORS['slate'], transform=ax5.transAxes)
    ax5.text(0.5, 0.15, chain_status, ha='center', va='center',
            fontsize=9, fontweight='bold', color=chain_color, transform=ax5.transAxes)
    ax5.set_xlim(0, 1)
    ax5.set_ylim(0, 1)
    ax5.axis('off')
    ax5.set_facecolor(COLORS['light_gray'])
    
    # Figure 6: High Risk Nodes
    ax6 = fig.add_subplot(gs[2, 1])
    high_risk_nodes = summary.get("high_risk_nodes", 0)
    _draw_metric_card(ax6, high_risk_nodes, "High Risk Nodes", 
                     COLORS['danger'] if high_risk_nodes > 0 else COLORS['success'],
                     show_bar=True)
    
    # Budget Used
    ax_budget = fig.add_subplot(gs[2, 2])
    budget_used = summary.get("budget_used", 0)
    _draw_metric_card(ax_budget, budget_used, "Budget Used", COLORS['primary'], show_bar=True)

    # Figure 7: Recommendations Section (Redesigned)
    ax_recom = fig.add_subplot(gs[3:5, :])
    recommendations = summary.get("recommendations", [])
    
    if not recommendations:
        recommendations = ["No specific strategic recommendations detected."]
    
    # Improved layout with better spacing and visual hierarchy
    y_start = 0.95
    y_spacing = 0.15
    
    # Section header
    ax_recom.text(0.02, y_start, "Strategic Recommendations", 
                 transform=ax_recom.transAxes,
                 fontsize=16, fontweight='bold', color=COLORS['primary'])
    
    # Display recommendations in a cleaner format
    current_y = y_start - 0.08
    for i, rec in enumerate(recommendations[:5]):  # Limit to 5 for readability
        # Determine recommendation type and color
        rec_lower = rec.lower()
        if any(word in rec_lower for word in ['risk', 'danger', 'critical', 'decline', 'avoid']):
            bullet_color = COLORS['danger']
            bullet = "⚠"
        elif any(word in rec_lower for word in ['opportunity', 'proceed', 'optimize', 'automate']):
            bullet_color = COLORS['success']
            bullet = "✓"
        elif any(word in rec_lower for word in ['monitor', 'consider', 'mitigate']):
            bullet_color = COLORS['warning']
            bullet = "→"
        else:
            bullet_color = COLORS['primary']
            bullet = "•"
        
        # Wrap long text manually (simpler approach)
        max_chars = 70
        if len(rec) > max_chars:
            # Simple word wrap
            words = rec.split()
            lines = []
            current_line = []
            for word in words:
                test_line = ' '.join(current_line + [word])
                if len(test_line) <= max_chars:
                    current_line.append(word)
                else:
                    if current_line:
                        lines.append(' '.join(current_line))
                    current_line = [word]
            if current_line:
                lines.append(' '.join(current_line))
            rec_display = '\n'.join(lines)
        else:
            rec_display = rec
        
        # Calculate height needed for this recommendation
        num_lines = rec_display.count('\n') + 1
        rec_height = min(num_lines * 0.04, 0.12)
        
        # Bullet point with color
        ax_recom.text(0.05, current_y, bullet, transform=ax_recom.transAxes,
                     fontsize=16, color=bullet_color, fontweight='bold',
                     verticalalignment='top')
        
        # Recommendation text with better formatting
        ax_recom.text(0.12, current_y, rec_display, transform=ax_recom.transAxes,
                     fontsize=10, color=COLORS['slate'], verticalalignment='top',
                     bbox=dict(boxstyle='round,pad=0.6', 
                              facecolor='white', alpha=0.8, 
                              edgecolor=bullet_color, linewidth=1.5))
        
        current_y -= rec_height + 0.05
    
    # Background
    ax_recom.add_patch(Rectangle((0.01, 0.05), 0.98, 0.90, 
                                facecolor=COLORS['light_gray'], alpha=0.3,
                                edgecolor=COLORS['border'], linewidth=2,
                                transform=ax_recom.transAxes))
    ax_recom.set_xlim(0, 1)
    ax_recom.set_ylim(0, 1)
    ax_recom.axis('off')

    # Figure 8: Decision Box (Enhanced)
    ax_decision = fig.add_subplot(gs[5, :])
    
    # Extract decision data with proper fallbacks
    should_bid = recommendation.get("should_bid", False)
    confidence = recommendation.get("confidence", 0.0) * 100
    key_risks = recommendation.get("key_risks", [])
    key_opportunities = recommendation.get("key_opportunities", [])
    
    decision_color = COLORS['success'] if should_bid else COLORS['danger']
    decision_text = "✓ RECOMMEND BID" if should_bid else "✗ DO NOT RECOMMEND"
    decision_icon = "✓" if should_bid else "✗"
    
    # Main decision text
    ax_decision.text(0.5, 0.75, decision_text, ha='center', va='center',
                    fontsize=24, fontweight='black', color=decision_color,
                    transform=ax_decision.transAxes)
    
    # Confidence level
    if confidence > 0:
        ax_decision.text(0.5, 0.55, f'Confidence: {confidence:.1f}%', 
                        ha='center', va='center',
                        fontsize=14, fontweight='bold', color=COLORS['slate'],
                        transform=ax_decision.transAxes)
        
        # Confidence bar
        bar_width = confidence / 100.0
        ax_decision.barh([0.4], [bar_width], height=0.08, color=decision_color, 
                        alpha=0.6, left=0.25, transform=ax_decision.transAxes)
        ax_decision.barh([0.4], [1.0], height=0.08, color=COLORS['light_gray'], 
                        alpha=0.3, left=0.25, transform=ax_decision.transAxes)
    
    # Key risks and opportunities (if available)
    info_y = 0.25
    if key_risks:
        risks_text = "Key Risks: " + ", ".join(key_risks[:3])
        ax_decision.text(0.5, info_y, risks_text, ha='center', va='center',
                        fontsize=10, color=COLORS['danger'], 
                        transform=ax_decision.transAxes,
                        bbox=dict(boxstyle='round,pad=0.5', facecolor='#ffe6e6', 
                                 alpha=0.8, edgecolor=COLORS['danger'], linewidth=1))
        info_y -= 0.12
    
    if key_opportunities:
        opps_text = "Opportunities: " + ", ".join(key_opportunities[:3])
        ax_decision.text(0.5, info_y, opps_text, ha='center', va='center',
                        fontsize=10, color=COLORS['success'],
                        transform=ax_decision.transAxes,
                        bbox=dict(boxstyle='round,pad=0.5', facecolor='#e6f7e6', 
                                 alpha=0.8, edgecolor=COLORS['success'], linewidth=1))
    
    # Decision box border
    ax_decision.add_patch(Rectangle((0.05, 0.05), 0.90, 0.90,
                                   facecolor=decision_color, alpha=0.1,
                                   edgecolor=decision_color, linewidth=4,
                                   transform=ax_decision.transAxes))
    
    ax_decision.set_xlim(0, 1)
    ax_decision.set_ylim(0, 1)
    ax_decision.axis('off')

    output_path = output_dir / "comprehensive_report.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
    print(f"   Saved: {output_path}")
    plt.close()


def create_heatmap_correlation(analysis: Dict[str, Any], output_dir: Path):
    """Create correlation heatmap for nodes."""
    print("\n📊 Creating correlation heatmap...")

    node_assessments = analysis.get("node_assessments", {})
    if len(node_assessments) < 2:
        print("   ⚠️  Not enough nodes for correlation")
        return

    # Prepare data matrix
    nodes = []
    data_matrix = []

    for node_id, assessment in node_assessments.items():
        name = assessment.get("name", node_id.replace("node_", "").replace("_", " ").title())
        nodes.append(name)
        data_matrix.append([
            assessment.get("influence", 0.5),
            assessment.get("risk", 0.5),
            1 if assessment.get("is_on_critical_path", False) else 0
        ])

    # Create correlation matrix
    df = pd.DataFrame(data_matrix, columns=['Influence', 'Risk', 'Critical'])
    correlation = df.T.corr()

    fig, ax = plt.subplots(figsize=(12, 10))

    im = ax.imshow(correlation, cmap='RdYlGn', aspect='auto', vmin=-1, vmax=1)

    # Set ticks
    ax.set_xticks(np.arange(len(nodes)))
    ax.set_yticks(np.arange(len(nodes)))
    ax.set_xticklabels(nodes, rotation=45, ha='right')
    ax.set_yticklabels(nodes)

    # Add correlation values
    for i in range(len(nodes)):
        for j in range(len(nodes)):
            text = ax.text(j, i, f'{correlation.iloc[i, j]:.2f}',
                         ha="center", va="center", color="black", fontsize=9, fontweight='bold')

    ax.set_title('Node Correlation Heatmap', fontsize=16, fontweight='bold', pad=20)

    # Colorbar
    cbar = plt.colorbar(im, ax=ax)
    cbar.set_label('Correlation', rotation=270, labelpad=20, fontweight='bold')

    plt.tight_layout()
    output_path = output_dir / "correlation_heatmap.png"
    plt.savefig(output_path, dpi=300, bbox_inches='tight', facecolor='white')
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
    print("Florent Analysis Visualizer")
    print("=" * 70)

    # Make API request
    analysis = make_api_request(args.firm, args.project, args.budget, args.api_url)

    # Save raw JSON
    save_analysis_json(analysis, output_dir)

    # Generate visualizations
    print("\n" + "=" * 70)
    print("Generating Visualizations")
    print("=" * 70)

    try:
        # Core visualizations
        create_summary_dashboard(analysis, output_dir)
        create_risk_matrix_2x2(analysis, output_dir)
        create_network_graph(analysis, output_dir)
        create_critical_chains_viz(analysis, output_dir)
        create_node_details_table(analysis, output_dir)

        # Enhanced visualizations
        create_risk_influence_scatter(analysis, output_dir)
        create_distribution_histograms(analysis, output_dir)
        create_radar_chart(analysis, output_dir)
        create_node_comparison_bars(analysis, output_dir)
        create_recommendation_viz(analysis, output_dir)
        create_heatmap_correlation(analysis, output_dir)
        create_comprehensive_report(analysis, output_dir)

        print("\n" + "=" * 70)
        print("✅ All visualizations completed!")
        print("=" * 70)
        print(f"\n📁 Output directory: {output_dir.absolute()}")
        print(f"\n📊 Generated Visualizations:")
        print(f"\n  Core Analytics:")
        print(f"    • analysis_output.json - Raw analysis data")
        print(f"    • summary_dashboard.png - Executive overview dashboard")
        print(f"    • comprehensive_report.png - Complete analysis report")
        print(f"\n  Risk Analysis:")
        print(f"    • risk_matrix_2x2.png - Action matrix (2x2 quadrant)")
        print(f"    • risk_influence_scatter.png - Detailed scatter plot")
        print(f"    • distributions.png - Risk & influence distributions")
        print(f"\n  Network & Chains:")
        print(f"    • network_graph.png - Risk network visualization")
        print(f"    • critical_chains.png - Critical dependency chains")
        print(f"    • correlation_heatmap.png - Node correlation matrix")
        print(f"\n  Node Details:")
        print(f"    • node_details_table.png - Detailed assessments table")
        print(f"    • node_comparison.png - Comparative bar charts")
        print(f"    • radar_chart.png - Overall project assessment")
        print(f"\n  Strategic:")
        print(f"    • recommendation.png - Bid recommendation & insights")
        print(f"\n🎯 Total: 13 visualizations generated")

    except Exception as e:
        print(f"\n❌ Error during visualization: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
