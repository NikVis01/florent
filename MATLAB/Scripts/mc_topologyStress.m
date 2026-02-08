function results = mc_topologyStress(analysis, nIterations)
    % MC_TOPOLOGYSTRESS Monte Carlo simulation for graph topology stress tests
    %
    % Uses enhanced API format with graph_topology
    %
    % Randomly adds/removes 5-15% of edges per iteration
    % Validates DAG constraint (no cycles)
    %
    % Tracks: cascading risk recalculation magnitude
    %
    % Output: critical edges (removal causes catastrophic changes)
    
    % Ensure paths are set up
    ensurePaths(false);
    
    % Validate enhanced format
    if ~isfield(analysis, 'node_assessments')
        error('mc_topologyStress: analysis must be in enhanced API format');
    end
    
    % Get graph topology from enhanced schema
    graphTopo = openapiHelpers('getGraphTopology', analysis);
    if isempty(graphTopo)
        error('mc_topologyStress: graph_topology section required');
    end
    
    % Get adjacency matrix
    originalAdj = openapiHelpers('getAdjacencyMatrix', analysis);
    if isempty(originalAdj)
        error('mc_topologyStress: adjacency_matrix not found in graph_topology');
    end
    
    nEdges = sum(originalAdj(:) > 0);
    
    % Get MC parameters
    mcParams = openapiHelpers('getMonteCarloParameters', analysis);
    if ~isempty(mcParams) && isfield(mcParams, 'simulation_config')
        if isfield(mcParams.simulation_config, 'recommended_samples') && nargin < 2
            nIterations = mcParams.simulation_config.recommended_samples;
        end
    end
    
    if nargin < 2
        nIterations = 10000;
    end
    
    fprintf('Topology Stress Test: %d iterations\n', nIterations);
    
    % Define perturbation function
    perturbFunc = @(analysis, iter) perturbTopology(analysis, iter, originalAdj, nEdges);
    
    % Run Monte Carlo (framework will use enhanced schemas for sampling)
    results = monteCarloFramework(analysis, perturbFunc, nIterations, true);
    
    % Identify critical edges
    results.criticalEdges = identifyCriticalEdges(analysis, results, originalAdj);
    
    fprintf('Topology stress test completed\n');
end

function [perturbedAnalysis, params] = perturbTopology(analysis, iter, originalAdj, nEdges)
    % Randomly add/remove edges while maintaining DAG constraint
    % Note: This modifies the graph_topology, but the framework uses enhanced schemas for sampling
    
    % Copy analysis structure
    perturbedAnalysis = analysis;
    
    % Set random seed for reproducibility (optional)
    % rng(iter);
    
    % Percentage of edges to modify (5-15%)
    edgeModPercent = 0.05 + 0.10 * rand(); % Random between 5% and 15%
    nModify = max(1, round(nEdges * edgeModPercent));
    
    % Start with original adjacency
    adj = originalAdj;
    nNodes = size(adj, 1);
    
    % Get all possible edges (excluding self-loops)
    [src, tgt] = find(adj > 0);
    existingEdges = [src, tgt];
    
    % Randomly modify edges
    for i = 1:nModify
        if rand() < 0.5 && ~isempty(existingEdges)
            % Remove an edge (50% chance)
            edgeIdx = randi(size(existingEdges, 1));
            edge = existingEdges(edgeIdx, :);
            adj(edge(1), edge(2)) = 0;
            existingEdges(edgeIdx, :) = [];
        else
            % Add an edge (50% chance)
            % Find potential new edges (not already existing)
            [allSrc, allTgt] = find(adj == 0);
            potentialEdges = [allSrc, allTgt];
            % Remove self-loops
            potentialEdges = potentialEdges(potentialEdges(:,1) ~= potentialEdges(:,2), :);
            
            if ~isempty(potentialEdges)
                edgeIdx = randi(size(potentialEdges, 1));
                edge = potentialEdges(edgeIdx, :);
                
                % Check if adding this edge creates a cycle
                testAdj = adj;
                testAdj(edge(1), edge(2)) = 1;
                
                if ~hasCycle(testAdj)
                    adj(edge(1), edge(2)) = 0.5 + 0.5*rand(); % Random weight
                    existingEdges = [existingEdges; edge];
                end
            end
        end
    end
    
    % Update graph_topology in analysis (if framework needs it)
    % Note: The framework primarily uses monte_carlo_parameters for sampling
    % but we update topology for this specific stress test
    if isfield(perturbedAnalysis, 'graph_topology')
        perturbedAnalysis.graph_topology.adjacency_matrix = adj;
    end
    
    % Store parameters
    params = struct();
    params.edgeModPercent = edgeModPercent;
    params.nEdgesModified = nModify;
    params.nEdgesFinal = sum(adj(:) > 0);
end

function hasCycle = hasCycle(adj)
    % Check if graph has a cycle using DFS
    nNodes = size(adj, 1);
    visited = false(nNodes, 1);
    recStack = false(nNodes, 1);
    
    for i = 1:nNodes
        if ~visited(i)
            if dfsCycleCheck(adj, i, visited, recStack)
                hasCycle = true;
                return;
            end
        end
    end
    
    hasCycle = false;
end

function hasCycle = dfsCycleCheck(adj, node, visited, recStack)
    % DFS helper for cycle detection
    visited(node) = true;
    recStack(node) = true;
    
    neighbors = find(adj(node, :) > 0);
    for neighbor = neighbors
        if ~visited(neighbor)
            if dfsCycleCheck(adj, neighbor, visited, recStack)
                hasCycle = true;
                return;
            end
        elseif recStack(neighbor)
            hasCycle = true;
            return;
        end
    end
    
    recStack(node) = false;
    hasCycle = false;
end

function criticalEdges = identifyCriticalEdges(analysis, results, originalAdj)
    % Identify critical edges whose removal causes catastrophic changes
    
    criticalEdges = struct();
    
    % Calculate risk change magnitude
    % (Simplified - would compare against original risk scores)
    riskChange = results.variance.risk;
    
    % High change threshold (top 25%)
    changeThreshold = prctile(riskChange, 75);
    
    % Identify nodes with high risk change
    criticalNodes = find(riskChange >= changeThreshold);
    
    % Find edges connected to critical nodes
    [src, tgt] = find(originalAdj > 0);
    criticalEdgeIndices = [];
    
    for i = 1:length(criticalNodes)
        nodeIdx = criticalNodes(i);
        % Find incoming edges
        incoming = find(originalAdj(:, nodeIdx) > 0);
        % Find outgoing edges
        outgoing = find(originalAdj(nodeIdx, :) > 0);
        
        for j = 1:length(incoming)
            edgeIdx = find(src == incoming(j) & tgt == nodeIdx);
            criticalEdgeIndices = [criticalEdgeIndices; edgeIdx];
        end
        
        for j = 1:length(outgoing)
            edgeIdx = find(src == nodeIdx & tgt == outgoing(j));
            criticalEdgeIndices = [criticalEdgeIndices; edgeIdx];
        end
    end
    
    criticalEdgeIndices = unique(criticalEdgeIndices);
    
    criticalEdges.indices = criticalEdgeIndices;
    criticalEdges.sources = src(criticalEdgeIndices);
    criticalEdges.targets = tgt(criticalEdgeIndices);
    criticalEdges.count = length(criticalEdgeIndices);
    
    fprintf('Identified %d critical edges\n', criticalEdges.count);
end

