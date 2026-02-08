#!/usr/bin/env python3
"""
Florent Analysis Visualizer

Clean, efficient visualization of risk analysis from API.
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
import pandas as pd
import numpy as np

# Use plotly for better interactive graphs
try:
    import plotly.graph_objects as go
    import plotly.express as px
    from plotly.subplots import make_subplots
    HAS_PLOTLY = True
except ImportError:
    HAS_PLOTLY = False

# Color scheme
COLORS = {
    "type_a": "#d93025",  # High importance/risk - Red
    "type_b": "#1a73e8",  # High influence - Blue
    "type_c": "#f9ab00",  # Low influence, high importance - Amber
    "type_d": "#dadce0",  # Low priority - Gray
    "success": "#0d904f",
    "warning": "#f9ab00",
    "danger": "#d93025",
    "primary": "#1a73e8",
}

sns.set_theme(style="whitegrid", palette="muted")


def call_api(firm_path: str, project_path: str, budget: int, api_url: str) -> Dict[str, Any]:
    """Make API request and return analysis."""
    print(f"API Request: {api_url}")
    print(f"  Firm: {firm_path}")
    print(f"  Project: {project_path}")
    print(f"  Budget: {budget}\n")

    try:
        response = requests.post(
            api_url,
            json={"firm_path": firm_path, "project_path": project_path, "budget": budget},
            headers={"Content-Type": "application/json"},
            timeout=300
        )
        response.raise_for_status()
        result = response.json()

        if result.get("status") == "error":
            print(f"[ERROR] API Error: {result.get('message')}")
            sys.exit(1)

        print("Analysis received\n")
        return result.get("analysis", result)

    except requests.exceptions.ConnectionError:
        print(f"[ERROR] Cannot connect to {api_url}")
        print("  Make sure API server is running (./run.sh)")
        sys.exit(1)
    except requests.exceptions.Timeout:
        print("[ERROR] Request timeout (5 min)")
        sys.exit(1)
    except requests.exceptions.HTTPError as e:
        print(f"[ERROR] HTTP {response.status_code}: {response.text}")
        sys.exit(1)
    except Exception as e:
        print(f"[ERROR] {e}")
        sys.exit(1)


def create_summary_card(analysis: Dict[str, Any], output_dir: Path):
    """Create executive summary card."""
    print("Creating summary card...")

    summary = analysis.get("summary", {})
    recommendation = analysis.get("recommendation", {})

    fig, ax = plt.subplots(figsize=(14, 8))
    ax.axis('off')

    # Main metrics
    bankability = summary.get("aggregate_project_score", 0) * 100
    nodes_evaluated = summary.get("nodes_evaluated", 0)
    should_bid = recommendation.get("should_bid", False)
    confidence = recommendation.get("confidence", 0) * 100

    # Decision banner
    decision_color = COLORS['success'] if should_bid else COLORS['danger']
    decision_text = "[+] RECOMMEND BID" if should_bid else "[-] DO NOT RECOMMEND"

    rect = Rectangle((0.05, 0.7), 0.9, 0.2, facecolor=decision_color, alpha=0.15,
                     edgecolor=decision_color, linewidth=3)
    ax.add_patch(rect)

    ax.text(0.5, 0.8, decision_text, ha='center', va='center', fontsize=26,
            fontweight='black', color=decision_color, transform=ax.transAxes)
    ax.text(0.5, 0.73, f'Confidence: {confidence:.1f}%', ha='center', va='center',
            fontsize=14, color='#3c4043', transform=ax.transAxes)

    # Metrics grid
    metrics = [
        ("Bankability", f"{bankability:.1f}%",
         COLORS['success'] if bankability > 70 else COLORS['warning'] if bankability > 40 else COLORS['danger']),
        ("Nodes Evaluated", str(nodes_evaluated), COLORS['primary']),
        ("Critical Failure Risk", f"{summary.get('critical_failure_likelihood', 0)*100:.1f}%", COLORS['danger']),
        ("Critical Dependencies", str(summary.get('critical_dependency_count', 0)), COLORS['warning']),
    ]

    for i, (label, value, color) in enumerate(metrics):
        x = 0.15 + (i % 2) * 0.4
        y = 0.5 - (i // 2) * 0.2

        # Card background
        card_rect = Rectangle((x - 0.15, y - 0.08), 0.28, 0.14,
                              facecolor='#f8f9fa', edgecolor='#dadce0', linewidth=1.5)
        ax.add_patch(card_rect)

        ax.text(x, y + 0.04, value, ha='center', va='center', fontsize=22,
                fontweight='bold', color=color, transform=ax.transAxes)
        ax.text(x, y - 0.04, label, ha='center', va='center', fontsize=10,
                color='#5f6368', transform=ax.transAxes)

    # Key risks and opportunities
    risks = recommendation.get("key_risks", [])[:3]
    opps = recommendation.get("key_opportunities", [])[:3]

    if risks:
        risk_text = "Key Risks:\n" + "\n".join([f"• {r}" for r in risks])
        ax.text(0.05, 0.15, risk_text, va='top', fontsize=9, linespacing=1.6,
                bbox=dict(boxstyle='round,pad=0.8', facecolor='#ffe6e6', alpha=0.8),
                transform=ax.transAxes)

    if opps:
        opp_text = "Opportunities:\n" + "\n".join([f"• {o}" for o in opps])
        ax.text(0.55, 0.15, opp_text, va='top', fontsize=9, linespacing=1.6,
                bbox=dict(boxstyle='round,pad=0.8', facecolor='#e6f7e6', alpha=0.8),
                transform=ax.transAxes)

    # Title
    firm_name = analysis.get("firm", {}).get("name", "Unknown")
    project_name = analysis.get("project", {}).get("name", "Unknown")
    ax.text(0.5, 0.97, f'Risk Analysis: {firm_name}', ha='center', va='top',
            fontsize=16, fontweight='bold', transform=ax.transAxes)
    ax.text(0.5, 0.94, project_name, ha='center', va='top',
            fontsize=11, color='#5f6368', transform=ax.transAxes)

    plt.savefig(output_dir / "summary_card.png", dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()


def create_risk_matrix(analysis: Dict[str, Any], output_dir: Path):
    """Create 2x2 risk matrix with jitter to prevent overlap."""
    print("Creating risk matrix...")

    fig, ax = plt.subplots(figsize=(12, 10))

    # Quadrant backgrounds
    quadrants = {
        "Type A": (0.5, 0.5, COLORS['type_a']),
        "Type B": (0.5, 0, COLORS['type_b']),
        "Type C": (0, 0.5, COLORS['type_c']),
        "Type D": (0, 0, COLORS['type_d']),
    }

    for label, (x, y, color) in quadrants.items():
        rect = Rectangle((x, y), 0.5, 0.5, facecolor=color, alpha=0.1,
                        edgecolor='black', linewidth=1, linestyle='--')
        ax.add_patch(rect)
        ax.text(x + 0.25, y + 0.47, label, ha='center', va='top', fontsize=14,
                fontweight='black', alpha=0.6, color=color)

    # Plot nodes with jitter
    classifications = analysis.get("matrix_classifications", {})
    node_assessments = analysis.get("node_assessments", {})
    
    # Pre-calculate top risks for forced labeling
    top_risks = sorted(node_assessments.items(), 
                       key=lambda x: x[1].get("risk_level", 0), 
                       reverse=True)[:8]
    top_risk_ids = [item[0] for item in top_risks]

    np.random.seed(42) # Consistent jitter
    
    for quadrant, nodes in classifications.items():
        color = COLORS.get(f"type_{quadrant.lower().replace('type ', '').strip()}", 'gray')

        for node_entry in nodes:
            node_id = node_entry if isinstance(node_entry, str) else node_entry.get("node_id")
            assessment = node_assessments.get(node_id, {})

            # Base coordinates
            influence = assessment.get("influence_score", 0.5)
            risk = assessment.get("risk_level", 0.5)
            name = assessment.get("node_name", node_id)
            
            # Add subtle jitter (max 0.04 spread)
            influence_j = influence + (np.random.random() - 0.5) * 0.04
            risk_j = risk + (np.random.random() - 0.5) * 0.04
            
            # Clip to bounds
            influence_j = np.clip(influence_j, 0.02, 0.98)
            risk_j = np.clip(risk_j, 0.02, 0.98)

            ax.scatter(influence_j, risk_j, s=400, c=color, alpha=0.8,
                      edgecolors='white', linewidth=1.5, zorder=3)

            # Label if it's high risk or if the total node count is small
            if node_id in top_risk_ids or len(node_assessments) <= 10:
                ax.annotate(name, (influence_j, risk_j), xytext=(8, 8),
                           textcoords='offset points', fontsize=9,
                           fontweight='bold' if node_id in top_risk_ids else 'normal',
                           bbox=dict(boxstyle='round,pad=0.3', facecolor='white', alpha=0.8, edgecolor='none'),
                           zorder=4)

    # Formatting
    ax.axhline(y=0.5, color='#5f6368', linestyle='-', linewidth=1.5, alpha=0.3)
    ax.axvline(x=0.5, color='#5f6368', linestyle='-', linewidth=1.5, alpha=0.3)
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.set_xlabel('Firm Influence Score ->', fontsize=13, fontweight='bold', labelpad=15)
    ax.set_ylabel('Risk / Importance Level ->', fontsize=13, fontweight='bold', labelpad=15)
    ax.set_title('Risk Action Matrix (2×2)', fontsize=20, fontweight='black', pad=30)
    
    # Better grid
    ax.grid(True, linestyle=':', alpha=0.2, zorder=0)

    plt.savefig(output_dir / "risk_matrix.png", dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()


def create_network_graph_plotly(analysis: Dict[str, Any], output_dir: Path):
    """Create interactive network graph using plotly."""
    if not HAS_PLOTLY:
        print("  [SKIP] Plotly not installed - skipping interactive graph")
        return

    print("Creating network graph...")

    # Extract graph structure from chains
    node_assessments = analysis.get("node_assessments", {})
    classifications = analysis.get("matrix_classifications", {})

    # Build node-to-quadrant map
    node_to_quad = {}
    for quad, nodes in classifications.items():
        for n in nodes:
            node_id = n if isinstance(n, str) else n.get("node_id")
            node_to_quad[node_id] = quad

    # Extract edges from chains
    edges = set()
    for chain in analysis.get("all_chains", []):
        nodes = chain.get("node_ids", [])
        for i in range(len(nodes) - 1):
            edges.add((nodes[i], nodes[i+1]))

    # Build graph data
    node_ids = list(node_assessments.keys())
    node_x, node_y, node_colors, node_text = [], [], [], []

    # Simple hierarchical layout (could be improved with networkx)
    for i, node_id in enumerate(node_ids):
        assessment = node_assessments[node_id]
        influence = assessment.get("influence_score", 0.5)
        importance = assessment.get("risk_level", 0.5)

        # Position based on influence/importance
        node_x.append(influence)
        node_y.append(importance)

        # Color by quadrant
        quad = node_to_quad.get(node_id, "type d")
        color_key = f"type_{quad.lower().replace('type ', '').strip()}"
        node_colors.append(COLORS.get(color_key, 'gray'))

        node_text.append(f"{assessment.get('node_name', node_id)}<br>Influence: {influence:.2f}<br>Risk: {importance:.2f}")

    # Create edge traces
    edge_x, edge_y = [], []
    for source, target in edges:
        if source in node_assessments and target in node_assessments:
            src_idx = node_ids.index(source)
            tgt_idx = node_ids.index(target)
            edge_x.extend([node_x[src_idx], node_x[tgt_idx], None])
            edge_y.extend([node_y[src_idx], node_y[tgt_idx], None])

    # Create figure
    fig = go.Figure()

    # Add edges
    fig.add_trace(go.Scatter(
        x=edge_x, y=edge_y,
        mode='lines',
        line=dict(width=1.5, color='#bdc1c6'),
        hoverinfo='none',
        showlegend=False
    ))

    # Add nodes
    fig.add_trace(go.Scatter(
        x=node_x, y=node_y,
        mode='markers+text',
        marker=dict(size=15, color=node_colors, line=dict(width=2, color='black')),
        text=[a.get('node_name', '')[:15] for a in node_assessments.values()],
        textposition="top center",
        hovertext=node_text,
        hoverinfo='text',
        showlegend=False
    ))

    fig.update_layout(
        title='Infrastructure Risk Network',
        xaxis=dict(title='Influence', showgrid=True, gridcolor='#f1f3f4'),
        yaxis=dict(title='Importance/Risk', showgrid=True, gridcolor='#f1f3f4'),
        plot_bgcolor='white',
        width=1200,
        height=800
    )

    fig.write_html(output_dir / "network_graph.html")


def create_node_table(analysis: Dict[str, Any], output_dir: Path):
    """Create clean node assessment table with better density handling."""
    print("Creating node table...")

    node_assessments = analysis.get("node_assessments", {})
    if not node_assessments:
        return

    # Build dataframe
    data = []
    classifications = analysis.get("matrix_classifications", {})
    node_to_quad = {}
    for quad, nodes in classifications.items():
        for n in nodes:
            node_id = n if isinstance(n, str) else n.get("node_id")
            node_to_quad[node_id] = quad

    for node_id, assessment in node_assessments.items():
        data.append({
            "Node": assessment.get("node_name", node_id),
            "Influence": assessment.get("influence_score", 0.5),
            "Risk": assessment.get("risk_level", 0.5),
            "Classification": node_to_quad.get(node_id, "Unknown"),
        })

    df = pd.DataFrame(data).sort_values("Risk", ascending=False)
    
    # Handle very long tables by splitting or increasing height dramatically
    num_nodes = len(df)
    row_height = 0.35
    header_height = 1.0
    fig_height = max(8, num_nodes * row_height + header_height)
    
    # Create figure with extra space at top for title
    fig, ax = plt.subplots(figsize=(14, fig_height))
    ax.axis('off')

    # Color mapping for cells
    def get_color(val, col):
        if col == "Influence":
            if val > 0.7: return "#e6f4ea"  # Soft green
            if val > 0.4: return "#fef7e0"  # Soft yellow
            return "#fce8e6"  # Soft red
        elif col == "Risk":
            if val > 0.7: return "#fce8e6"
            if val > 0.4: return "#fef7e0"
            return "#e6f4ea"
        return 'white'

    # Build cell colors and display text
    cell_colors = []
    display_data = []
    
    for _, row in df.iterrows():
        display_data.append([
            row['Node'],
            f"{row['Influence']:.2f}",
            f"{row['Risk']:.2f}",
            row['Classification']
        ])
        cell_colors.append([
            'white',
            get_color(row['Influence'], 'Influence'),
            get_color(row['Risk'], 'Risk'),
            'white'
        ])

    # Create table
    table = ax.table(
        cellText=display_data,
        colLabels=["Node Name", "Influence Score", "Risk Level", "Matrix Category"],
        cellLoc='left',
        loc='upper center',
        cellColours=cell_colors,
        colColours=[COLORS['primary']] * 4,
        colWidths=[0.4, 0.15, 0.15, 0.3]
    )

    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 1.8)

    # Style header explicitly
    for i in range(4):
        table[(0, i)].set_text_props(weight='bold', color='white', ha='center')
        table[(0, i)].set_facecolor(COLORS['primary'])

    # Add padding to title to prevent overlap
    plt.title('Node Risk Assessments', fontsize=18, fontweight='bold', pad=40)
    
    plt.subplots_adjust(top=0.92) # Ensure title has space

    plt.savefig(output_dir / "node_table.png", dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()


def create_distributions(analysis: Dict[str, Any], output_dir: Path):
    """Create risk and influence distributions."""
    print("Creating distributions...")

    node_assessments = analysis.get("node_assessments", {})
    if not node_assessments:
        return

    risks = [a.get("risk_level", 0.5) for a in node_assessments.values()]
    influences = [a.get("influence_score", 0.5) for a in node_assessments.values()]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # Risk distribution
    ax1.hist(risks, bins=12, color=COLORS['danger'], alpha=0.7, edgecolor='black')
    ax1.axvline(np.mean(risks), color='black', linestyle='--', linewidth=2,
                label=f'Mean: {np.mean(risks):.2f}')
    ax1.set_xlabel('Risk Level', fontsize=11, fontweight='bold')
    ax1.set_ylabel('Count', fontsize=11, fontweight='bold')
    ax1.set_title('Risk Distribution', fontsize=13, fontweight='bold')
    ax1.legend()
    ax1.grid(axis='y', alpha=0.3)

    # Influence distribution
    ax2.hist(influences, bins=12, color=COLORS['success'], alpha=0.7, edgecolor='black')
    ax2.axvline(np.mean(influences), color='black', linestyle='--', linewidth=2,
                label=f'Mean: {np.mean(influences):.2f}')
    ax2.set_xlabel('Influence Score', fontsize=11, fontweight='bold')
    ax2.set_ylabel('Count', fontsize=11, fontweight='bold')
    ax2.set_title('Influence Distribution', fontsize=13, fontweight='bold')
    ax2.legend()
    ax2.grid(axis='y', alpha=0.3)

    plt.tight_layout()
    plt.savefig(output_dir / "distributions.png", dpi=300, bbox_inches='tight', facecolor='white')
    plt.close()


def create_radar_chart(analysis: Dict[str, Any], output_dir: Path):
    """Create radar chart for overall project assessment."""
    print("\n Creating radar chart...")

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
    print("\n Creating node comparison chart...")

    node_assessments = analysis.get("node_assessments", {})
    if not node_assessments:
        print("   [WARN]  No data to visualize")
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
    print("\n Creating recommendation visualization...")

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
    print("\n Creating comprehensive report...")

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
            bullet = "[!]"
        elif any(word in rec_lower for word in ['opportunity', 'proceed', 'optimize', 'automate']):
            bullet_color = COLORS['success']
            bullet = "[OK]"
        elif any(word in rec_lower for word in ['monitor', 'consider', 'mitigate']):
            bullet_color = COLORS['warning']
            bullet = "->"
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
    decision_text = "[OK] RECOMMEND BID" if should_bid else "[FAIL] DO NOT RECOMMEND"
    decision_icon = "[OK]" if should_bid else "[FAIL]"
    
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
    print("\n Creating correlation heatmap...")

    node_assessments = analysis.get("node_assessments", {})
    if len(node_assessments) < 2:
        print("   [WARN]  Not enough nodes for correlation")
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
    with open(output_dir / "analysis.json", 'w') as f:
        json.dump(analysis, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description="Visualize Florent risk analysis")
    parser.add_argument("--firm", default="src/data/poc/firm.json", help="Firm JSON path")
    parser.add_argument("--project", default="src/data/poc/project.json", help="Project JSON path")
    parser.add_argument("--budget", type=int, default=100, help="Analysis budget")
    parser.add_argument("--api-url", default="http://localhost:8000/analyze", help="API endpoint")
    parser.add_argument("--output", default="output/visualizations", help="Output directory")

    args = parser.parse_args()

    # Setup
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("=" * 70)
    print("Florent Analysis Visualizer")
    print("=" * 70 + "\n")

    # Get analysis from API
    analysis = call_api(args.firm, args.project, args.budget, args.api_url)

    # Save raw data
    save_analysis(analysis, output_dir)
    print("Saved analysis.json\n")

    # Generate visualizations
    print("Generating visualizations...\n")

    try:
        create_summary_card(analysis, output_dir)
        create_risk_matrix(analysis, output_dir)
        create_node_table(analysis, output_dir)
        create_distributions(analysis, output_dir)
        create_network_graph_plotly(analysis, output_dir)

        print("\n" + "=" * 70)
        print("[SUCCESS] Visualizations complete")
        print("=" * 70)
        print(f"\nOutput: {output_dir.absolute()}")
        print(f"\nGenerated:")
        print(f"   - analysis.json - Raw analysis data")
        print(f"   - summary_card.png - Executive summary")
        print(f"   - risk_matrix.png - 2x2 action matrix")
        print(f"   - node_table.png - Node assessments")
        print(f"   - distributions.png - Risk/influence distributions")
        if HAS_PLOTLY:
            print(f"   - network_graph.html - Interactive network (open in browser)")
        print()

    except Exception as e:
        print(f"\n[ERROR] Visualization error: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
