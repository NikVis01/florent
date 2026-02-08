# Enhanced API Output for MATLAB Integration

Complete guide to the enhanced analysis output with 8 additional sections for Monte Carlo simulation and visualization.

## Overview

The `/analyze` endpoint now returns significantly more data to support MATLAB-based Monte Carlo simulation and advanced visualization, while maintaining full backward compatibility.

## Enhanced Output Structure

```json
{
    "status": "success",
    "analysis": {
        // ========== EXISTING OUTPUT (unchanged) ==========
        "firm": {...},
        "project": {...},
        "node_assessments": {...},
        "all_chains": [...],
        "matrix_classifications": {...},
        "summary": {...},
        "recommendation": {...},

        // ========== NEW ENHANCED SECTIONS ==========
        "graph_topology": {...},           // Section 1
        "risk_distributions": {...},       // Section 2
        "propagation_trace": {...},        // Section 3
        "discovery_metadata": {...},       // Section 4
        "evaluation_metadata": {...},      // Section 5
        "configuration_snapshot": {...},   // Section 6
        "graph_statistics": {...},         // Section 7
        "monte_carlo_parameters": {...}    // Section 8
    }
}
```

## Section 1: Graph Topology

**Purpose:** Reconstruct the complete graph structure in MATLAB

**Contains:**
- `adjacency_matrix`: NxN matrix with edge weights
- `node_index`: Mapping from node IDs to matrix indices
- `edges`: Enhanced edge list with metadata
- `nodes`: Enhanced node list with topology info
- `statistics`: Graph metrics (density, avg degree, max depth, etc.)

**MATLAB Usage:**
```matlab
% Extract adjacency matrix
adj_matrix = analysis.graph_topology.adjacency_matrix;
node_ids = analysis.graph_topology.node_index;

% Visualize graph
G = digraph(adj_matrix, node_ids);
plot(G, 'Layout', 'layered');
```

## Section 2: Risk Distributions

**Purpose:** Statistical distributions for Monte Carlo sampling

**Contains:**
- Per-node importance/influence distributions (Beta parameters)
- Risk components (point estimate, propagated, local)
- Correlation pairs between adjacent nodes
- 95% confidence intervals

**MATLAB Usage:**
```matlab
% Get distribution for node_1
node1 = analysis.risk_distributions.nodes.node_1;
alpha = node1.importance.alpha;
beta_param = node1.importance.beta;

% Sample from Beta distribution
importance_samples = betarnd(alpha, beta_param, 10000, 1);
```

## Section 3: Propagation Trace

**Purpose:** Understand how risk flowed through the graph

**Contains:**
- Per-node propagation breakdown
- Incoming risk from parents
- Outgoing risk to children
- Propagation multipliers and formulas
- Configuration used

**MATLAB Usage:**
```matlab
% Analyze risk flow for node_1
trace = analysis.propagation_trace.nodes.node_1;
local_risk = trace.local_risk;
propagated = trace.propagated_risk;

fprintf('Local: %.2f, Propagated: %.2f\n', local_risk, propagated);
```

## Section 4: Discovery Metadata

**Purpose:** Track AI-discovered nodes and gaps

**Contains:**
- List of discovered nodes with reasoning
- Gap triggers that initiated discovery
- Persona used for each discovery
- Discovery summary statistics

**Status:** Placeholder (to be populated by graph builder)

## Section 5: Evaluation Metadata

**Purpose:** Performance tracking and cost analysis

**Contains:**
- Per-node evaluation time, tokens, cost
- Cache hits/misses
- Retry attempts
- Token breakdown by operation type

**Status:** Placeholder (to be populated by orchestrator)

## Section 6: Configuration Snapshot

**Purpose:** Complete reproducibility

**Contains:**
- All 41 configuration parameters
- Model versions (LLM, cross-encoder, DSPy)
- Timestamp and system version

**MATLAB Usage:**
```matlab
% Get configuration used
config = analysis.configuration_snapshot;
risk_factor = config.parameters.pipeline.risk_propagation_factor;
```

## Section 7: Graph Statistics

**Purpose:** Network analysis metrics

**Contains:**
- **Centrality measures** per node:
  - Betweenness centrality (bottleneck detection)
  - Closeness centrality (node connectivity)
  - Degree centrality
  - Eigenvector centrality
  - PageRank
- **Path analysis**:
  - Total paths, critical paths
  - Average/longest/shortest path length
  - Bottleneck nodes
- **Clustering coefficients**:
  - Global clustering
  - Per-node local clustering

**MATLAB Usage:**
```matlab
% Find bottleneck nodes
centrality = analysis.graph_statistics.centrality;
node_ids = fieldnames(centrality);

betweenness = [];
for i = 1:length(node_ids)
    betweenness(i) = centrality.(node_ids{i}).betweenness;
end

[~, idx] = sort(betweenness, 'descend');
bottlenecks = node_ids(idx(1:5));  % Top 5
```

## Section 8: Monte Carlo Parameters

**Purpose:** Pre-computed simulation parameters

**Contains:**
- **Sampling distributions** per node (Beta parameters)
- **Simulation config** (recommended samples, chains, seed)
- **Covariance matrix** (NxN for correlated sampling)
- **Conditional dependencies** (parent-child relationships)

**MATLAB Usage:**
```matlab
% Run Monte Carlo simulation
mc_params = analysis.monte_carlo_parameters;
n_samples = mc_params.simulation_config.recommended_samples;

% Sample importance scores for all nodes
importance_samples = zeros(n_samples, length(node_ids));
for i = 1:length(node_ids)
    node_id = node_ids{i};
    dist = mc_params.sampling_distributions.(node_id).importance;
    importance_samples(:,i) = betarnd(dist.params.alpha, ...
                                      dist.params.beta, n_samples, 1);
end

% Apply covariance structure
cov_matrix = mc_params.covariance_matrix;
% ... use Cholesky decomposition for correlated sampling
```

## Complete MATLAB Example

```matlab
% Load analysis result
analysis = jsondecode(fileread('analysis_result.json'));

% 1. Extract graph structure
adj_matrix = analysis.graph_topology.adjacency_matrix;
node_ids = analysis.graph_topology.node_index;

% 2. Get Monte Carlo parameters
mc = analysis.monte_carlo_parameters;
n_samples = mc.simulation_config.recommended_samples;
n_nodes = length(node_ids);

% 3. Sample importance and influence for all nodes
importance_samples = zeros(n_samples, n_nodes);
influence_samples = zeros(n_samples, n_nodes);

fields = fieldnames(mc.sampling_distributions);
for i = 1:length(fields)
    node_id = fields{i};
    idx = find(strcmp(node_ids, node_id));

    % Sample importance
    imp_dist = mc.sampling_distributions.(node_id).importance;
    importance_samples(:, idx) = betarnd(imp_dist.params.alpha, ...
                                         imp_dist.params.beta, n_samples, 1);

    % Sample influence
    inf_dist = mc.sampling_distributions.(node_id).influence;
    influence_samples(:, idx) = betarnd(inf_dist.params.alpha, ...
                                        inf_dist.params.beta, n_samples, 1);
end

% 4. Calculate risk for each sample
risk_samples = importance_samples .* (1 - influence_samples);

% 5. Propagate risk through graph (using topological order)
propagated_risk = zeros(n_samples, n_nodes);
for node_idx = 1:n_nodes
    % Get parents
    parents = find(adj_matrix(:, node_idx) > 0);

    if isempty(parents)
        % Entry node
        propagated_risk(:, node_idx) = risk_samples(:, node_idx);
    else
        % Propagate from parents
        parent_risks = propagated_risk(:, parents);
        max_parent_risk = max(parent_risks, [], 2);

        local = risk_samples(:, node_idx);
        propagated_risk(:, node_idx) = local + (max_parent_risk .* local * 0.5);
    end
end

% 6. Analyze results
mean_risk = mean(propagated_risk);
std_risk = std(propagated_risk);
ci_95 = prctile(propagated_risk, [2.5, 97.5]);

% 7. Visualize
figure;
histogram(propagated_risk(:, end), 50);  % Risk at exit node
title('Exit Node Risk Distribution');
xlabel('Risk Level');
ylabel('Frequency');

% 8. Critical path analysis
paths = analysis.all_chains;
critical_path = paths{1}.node_ids;

% Calculate path risk distribution
path_risk = zeros(n_samples, 1);
for i = 1:length(critical_path)
    node_id = critical_path{i};
    idx = find(strcmp(node_ids, node_id));
    path_risk = path_risk + propagated_risk(:, idx);
end

fprintf('Critical Path Risk: %.2f +/- %.2f\n', mean(path_risk), std(path_risk));
```

## API Request Example

```bash
curl -X POST http://localhost:8000/analyze \
  -H "Content-Type: application/json" \
  -d '{
    "firm_path": "data/firm.json",
    "project_path": "data/project.json",
    "budget": 100
  }' | jq '.analysis.graph_topology.statistics'
```

## Export to MATLAB

Use the OpenAPI schema exporter to generate MATLAB-friendly JSON:

```bash
# Export all schemas
uv run python scripts/export_openapi_schemas.py

# Load in MATLAB
addpath('docs/openapi_export/matlab');
schemas = load_florent_schemas();
```

## Data Sizes

Expected data sizes for typical projects:

| Section | Small (20 nodes) | Medium (50 nodes) | Large (100 nodes) |
|---------|------------------|-------------------|-------------------|
| Core Output | ~50 KB | ~150 KB | ~350 KB |
| Graph Topology | ~10 KB | ~50 KB | ~150 KB |
| Risk Distributions | ~15 KB | ~40 KB | ~90 KB |
| Propagation Trace | ~20 KB | ~80 KB | ~200 KB |
| Graph Statistics | ~15 KB | ~50 KB | ~120 KB |
| Monte Carlo Params | ~25 KB | ~100 KB | ~250 KB |
| **Total** | **~135 KB** | **~470 KB** | **~1.16 MB** |

## Benefits

1. **Complete Graph Reconstruction** - Build exact DAG in MATLAB
2. **Monte Carlo Ready** - All parameters for simulation included
3. **Full Traceability** - Understand every calculation
4. **Network Analysis** - Centrality, paths, clustering metrics
5. **Reproducibility** - Complete config snapshot
6. **Performance Insights** - Token costs and timing
7. **Backward Compatible** - All existing functionality preserved

## Next Steps

1. **Track Discovery Metadata** - Populate during graph building
2. **Track Evaluation Metadata** - Populate during node evaluation
3. **Add Risk Tensors** - Historical risk samples if available
4. **Optimize Performance** - Optional lazy loading of enhanced sections

## See Also

- [Configuration Guide](CONFIGURATION.md)
- [MATLAB Integration](../docs/openapi_export/README.md)
- [System Overview](SYSTEM_OVERVIEW.md)
