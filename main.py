#!/usr/bin/env python3
"""
Florent - Infrastructure Project Risk Analysis CLI

Usage:
    python main.py --firm firm.json --project project.json [--graph graph.json] [--budget 50]
"""
import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import Dict

from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
from rich import box

from src.models.base import Firm
from src.models.entities import Project
from src.models.graph import Graph, Node, Edge
from src.models.analysis import AnalysisOutput
from src.services.agent.core.orchestrator_v2 import RiskOrchestrator
from src.services.agent.analysis.matrix_classifier import RiskQuadrant
from src.services.logging import get_logger

logger = get_logger(__name__)
console = Console()


def load_json_file(filepath: str) -> Dict:
    """Load and parse JSON file."""
    path = Path(filepath)
    if not path.exists():
        console.print(f"[bold red]Error:[/bold red] File not found: {filepath}")
        sys.exit(1)

    try:
        with open(path, "r") as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        console.print(f"[bold red]Error:[/bold red] Invalid JSON in {filepath}: {e}")
        sys.exit(1)


def create_graph_from_project(project: Project) -> Graph:
    """Create a minimal graph from project data.

    In production, this would load from a separate graph.json file.
    For POC, we create a simple linear graph.
    """
    # Create nodes from ops_requirements
    nodes = []
    for i, req in enumerate(project.ops_requirements):
        node = Node(
            id=f"node_{i}_{req.name.lower().replace(' ', '_')}",
            name=req.name,
            type=req,
            embedding=[]
        )
        nodes.append(node)

    # Create linear edges
    edges = []
    for i in range(len(nodes) - 1):
        edge = Edge(
            source=nodes[i],
            target=nodes[i + 1],
            weight=1.0,
            relationship="leads to"
        )
        edges.append(edge)

    return Graph(nodes=nodes, edges=edges)


def print_header(firm: Firm, project: Project):
    """Print analysis header."""
    header = Text()
    header.append("🏗️  Florent Infrastructure Risk Analysis\n", style="bold cyan")
    header.append(f"Firm: {firm.name}\n", style="yellow")
    header.append(f"Project: {project.name}\n", style="yellow")
    header.append(f"Country: {project.country.name} ({project.country.a3})\n", style="yellow")

    console.print(Panel(header, border_style="cyan", box=box.ROUNDED))


def print_matrix_table(analysis: AnalysisOutput):
    """Print 2x2 risk matrix as a Rich table."""
    table = Table(title="📊 Risk Matrix (2×2)", box=box.ROUNDED, show_header=True, header_style="bold magenta")

    table.add_column("Quadrant", style="cyan", width=20)
    table.add_column("Count", justify="center", style="green", width=8)
    table.add_column("Nodes", style="white", width=60)

    quadrant_colors = {
        RiskQuadrant.SAFE_WINS: "green",
        RiskQuadrant.MANAGED_RISKS: "yellow",
        RiskQuadrant.BASELINE_UTILITY: "blue",
        RiskQuadrant.COOKED_ZONE: "red",
    }

    for quadrant in RiskQuadrant:
        nodes = analysis.matrix_classifications.get(quadrant, [])
        node_names = ", ".join(n.node_name for n in nodes[:5])
        if len(nodes) > 5:
            node_names += f" ... (+{len(nodes) - 5} more)"

        color = quadrant_colors.get(quadrant, "white")
        table.add_row(
            f"[{color}]{quadrant.value}[/{color}]",
            str(len(nodes)),
            node_names or "None"
        )

    console.print(table)


def print_critical_chains(analysis: AnalysisOutput):
    """Print critical chains."""
    table = Table(title="⛓️  Critical Chains (Top 3)", box=box.ROUNDED)

    table.add_column("Rank", justify="center", style="cyan", width=6)
    table.add_column("Risk", justify="center", style="red", width=10)
    table.add_column("Length", justify="center", style="yellow", width=8)
    table.add_column("Path", style="white")

    for i, chain in enumerate(analysis.critical_chains[:3], 1):
        path_str = " → ".join(chain.node_names)
        table.add_row(
            str(i),
            f"{chain.cumulative_risk:.1%}",
            str(chain.length),
            path_str
        )

    console.print(table)


def print_summary(analysis: AnalysisOutput):
    """Print summary metrics."""
    metrics = analysis.summary

    table = Table(title="📈 Summary Metrics", box=box.ROUNDED, show_header=False)
    table.add_column("Metric", style="cyan", width=35)
    table.add_column("Value", style="yellow", width=30)

    table.add_row("Aggregate Project Score", f"{metrics.aggregate_project_score:.2%}")
    table.add_row("Critical Failure Likelihood", f"[red]{metrics.critical_failure_likelihood:.2%}[/red]")
    table.add_row("Nodes Evaluated", f"{metrics.nodes_evaluated}/{metrics.total_nodes}")
    table.add_row("Cooked Zone %", f"[red]{metrics.cooked_zone_percentage:.1%}[/red]")
    table.add_row("Total Token Cost", f"{metrics.total_token_cost:,}")
    table.add_row("Traversal Status", f"[green]{analysis.traversal_status}[/green]")

    console.print(table)


def print_recommendation(analysis: AnalysisOutput):
    """Print bid recommendation."""
    rec = analysis.recommendation

    color = "green" if rec.should_bid else "red"
    decision = "✅ PROCEED WITH BID" if rec.should_bid else "🛑 DO NOT BID"

    text = Text()
    text.append(f"{decision}\n", style=f"bold {color}")
    text.append(f"Confidence: {rec.confidence:.0%}\n", style="yellow")
    text.append(f"\n{rec.reasoning}\n", style="white")

    if rec.key_risks:
        text.append("\n🔴 Key Risks:\n", style="bold red")
        for risk in rec.key_risks:
            text.append(f"  • {risk}\n", style="red")

    if rec.key_opportunities:
        text.append("\n🟢 Key Opportunities:\n", style="bold green")
        for opp in rec.key_opportunities:
            text.append(f"  • {opp}\n", style="green")

    console.print(Panel(text, title="🎯 Bid Recommendation", border_style=color, box=box.DOUBLE))


def save_json_output(analysis: AnalysisOutput, output_path: str):
    """Save analysis to JSON file."""
    output_dir = Path(output_path).parent
    output_dir.mkdir(parents=True, exist_ok=True)

    with open(output_path, "w") as f:
        json.dump(analysis.model_dump(mode="json"), f, indent=2)

    console.print(f"\n💾 Analysis saved to: [cyan]{output_path}[/cyan]")


def generate_dot_file(analysis: AnalysisOutput, dot_path: str):
    """Generate Graphviz DOT file for risk visualization."""
    output_dir = Path(dot_path).parent
    output_dir.mkdir(parents=True, exist_ok=True)

    # Build node color mapping based on quadrant
    node_colors = {}
    for quadrant, nodes in analysis.matrix_classifications.items():
        color = {
            RiskQuadrant.SAFE_WINS: "green",
            RiskQuadrant.MANAGED_RISKS: "yellow",
            RiskQuadrant.BASELINE_UTILITY: "lightblue",
            RiskQuadrant.COOKED_ZONE: "red",
        }.get(quadrant, "gray")

        for node in nodes:
            node_colors[node.node_id] = color

    with open(dot_path, "w") as f:
        f.write("digraph RiskAnalysis {\n")
        f.write('  rankdir=LR;\n')
        f.write('  node [shape=box, style=filled];\n\n')

        # Write nodes
        for node_id, assessment in analysis.node_assessments.items():
            color = node_colors.get(node_id, "gray")
            label = f"{assessment.node_name}\\nI:{assessment.influence_score:.2f} R:{assessment.risk_level:.2f}"
            f.write(f'  "{node_id}" [label="{label}", fillcolor={color}];\n')

        f.write("\n")

        # Write edges (would need graph structure - simplified for now)
        # In full implementation, iterate through graph.edges

        f.write("}\n")

    console.print(f"📊 DOT file saved to: [cyan]{dot_path}[/cyan]")
    console.print(f"   Render with: [yellow]dot -Tpng {dot_path} -o risk_graph.png[/yellow]")


async def main():
    """Main CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Florent Infrastructure Project Risk Analysis",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument("--firm", required=True, help="Path to firm.json")
    parser.add_argument("--project", required=True, help="Path to project.json")
    parser.add_argument("--graph", help="Path to graph.json (optional, auto-generated if missing)")
    parser.add_argument("--budget", type=int, default=50, help="Node evaluation budget (default: 50)")
    parser.add_argument("--output", default="outputs/analysis.json", help="Output JSON path")
    parser.add_argument("--dot", default="outputs/risk_graph.dot", help="Output DOT file path")

    args = parser.parse_args()

    # Load input data
    console.print("[cyan]Loading input data...[/cyan]")
    firm_data = load_json_file(args.firm)
    project_data = load_json_file(args.project)

    # Parse models
    firm = Firm(**firm_data)
    project = Project(**project_data)

    # Load or generate graph
    if args.graph:
        graph_data = load_json_file(args.graph)
        # TODO: Parse graph from JSON
        graph = create_graph_from_project(project)
    else:
        console.print("[yellow]No graph provided, generating from project...[/yellow]")
        graph = create_graph_from_project(project)

    # Print header
    print_header(firm, project)

    # Run analysis
    console.print(f"\n[cyan]Running risk analysis (budget: {args.budget} nodes)...[/cyan]\n")

    orchestrator = RiskOrchestrator(
        firm=firm,
        project=project,
        graph=graph,
        max_retries=3,
        cache_enabled=True,
    )

    try:
        analysis = await orchestrator.run_analysis(budget=args.budget)
    except Exception as e:
        console.print(f"\n[bold red]Analysis failed:[/bold red] {e}")
        logger.error("analysis_failed", error=str(e), exc_info=True)
        sys.exit(1)

    # Print results
    console.print("\n" + "=" * 80 + "\n")
    print_summary(analysis)
    console.print()
    print_matrix_table(analysis)
    console.print()
    print_critical_chains(analysis)
    console.print()
    print_recommendation(analysis)

    # Save outputs
    save_json_output(analysis, args.output)
    generate_dot_file(analysis, args.dot)

    console.print(f"\n[bold green]✅ Analysis complete![/bold green]\n")


if __name__ == "__main__":
    asyncio.run(main())
