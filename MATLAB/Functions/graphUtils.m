function adj = buildAdjacencyMatrix(nodes, edges)
    % BUILDADJACENCYMATRIX Builds adjacency matrix from graph nodes and edges
    %
    % Inputs:
    %   nodes - Cell array of node structs with 'id' field, or cell array of node IDs
    %   edges - Cell array of edge structs with 'source', 'target', 'weight' fields
    %
    % Output:
    %   adj - NxN adjacency matrix where adj(i,j) = weight of edge from i to j
    
    % Extract node IDs
    if iscell(nodes)
        if isstruct(nodes{1})
            nodeIds = cellfun(@(n) n.id, nodes, 'UniformOutput', false);
        else
            nodeIds = nodes;
        end
    else
        error('Nodes must be a cell array');
    end
    
    nNodes = length(nodeIds);
    adj = zeros(nNodes, nNodes);
    
    % Create node ID to index mapping
    nodeIdMap = containers.Map();
    for i = 1:nNodes
        nodeIdMap(nodeIds{i}) = i;
    end
    
    % Build adjacency matrix
    for i = 1:length(edges)
        edge = edges{i};
        if isstruct(edge)
            srcId = edge.source;
            tgtId = edge.target;
            weight = edge.weight;
        elseif iscell(edge)
            srcId = edge{1};
            tgtId = edge{2};
            weight = edge{3};
        end
        
        % Handle source/target as IDs or structs
        if isstruct(srcId)
            srcId = srcId.id;
        end
        if isstruct(tgtId)
            tgtId = tgtId.id;
        end
        
        if isKey(nodeIdMap, srcId) && isKey(nodeIdMap, tgtId)
            srcIdx = nodeIdMap(srcId);
            tgtIdx = nodeIdMap(tgtId);
            adj(srcIdx, tgtIdx) = weight;
        end
    end
end

function paths = findAllPaths(adj, startNode, endNode)
    % FINDALLPATHS Finds all paths from start node to end node in DAG
    %
    % Inputs:
    %   adj - Adjacency matrix
    %   startNode - Starting node index
    %   endNode - Ending node index (optional, if empty finds all paths from start)
    %
    % Output:
    %   paths - Cell array of paths, each path is a vector of node indices
    
    nNodes = size(adj, 1);
    paths = {};
    
    if nargin < 3 || isempty(endNode)
        % Find all reachable nodes from start
        endNodes = findReachableNodes(adj, startNode);
    else
        endNodes = endNode;
    end
    
    % Use DFS to find all paths
    if isscalar(endNodes)
        paths = dfsFindPaths(adj, startNode, endNodes, []);
    else
        for i = 1:length(endNodes)
            paths = [paths; dfsFindPaths(adj, startNode, endNodes(i), [])];
        end
    end
end

function paths = dfsFindPaths(adj, current, target, path)
    % DFS helper to find all paths
    path = [path, current];
    
    if current == target
        paths = {path};
        return;
    end
    
    paths = {};
    neighbors = find(adj(current, :) > 0);
    
    for neighbor = neighbors
        if ~ismember(neighbor, path) % Avoid cycles (shouldn't happen in DAG)
            subPaths = dfsFindPaths(adj, neighbor, target, path);
            paths = [paths; subPaths];
        end
    end
end

function reachable = findReachableNodes(adj, startNode)
    % FINDREACHABLENODES Finds all nodes reachable from start node
    %
    % Uses BFS to find all reachable nodes
    
    nNodes = size(adj, 1);
    visited = false(nNodes, 1);
    queue = startNode;
    visited(startNode) = true;
    
    while ~isempty(queue)
        current = queue(1);
        queue(1) = [];
        
        neighbors = find(adj(current, :) > 0);
        for neighbor = neighbors
            if ~visited(neighbor)
                visited(neighbor) = true;
                queue = [queue; neighbor];
            end
        end
    end
    
    reachable = find(visited);
end

function centrality = calculateEigenvectorCentrality(adj, maxIter, tol)
    % CALCULATEEIGENVECTORCENTRALITY Calculates eigenvector centrality for nodes
    %
    % Inputs:
    %   adj - Adjacency matrix
    %   maxIter - Maximum iterations (default: 100)
    %   tol - Convergence tolerance (default: 1e-6)
    %
    % Output:
    %   centrality - Vector of centrality scores (normalized to sum to 1)
    
    if nargin < 2
        maxIter = 100;
    end
    if nargin < 3
        tol = 1e-6;
    end
    
    nNodes = size(adj, 1);
    
    % Initialize with uniform values
    centrality = ones(nNodes, 1) / nNodes;
    
    % Power iteration
    for iter = 1:maxIter
        old_centrality = centrality;
        
        % Multiply by adjacency matrix
        centrality = adj' * centrality;
        
        % Normalize
        norm_val = norm(centrality);
        if norm_val > 0
            centrality = centrality / norm_val;
        else
            break;
        end
        
        % Check convergence
        if norm(centrality - old_centrality) < tol
            break;
        end
    end
    
    % Normalize to sum to 1
    centrality = centrality / sum(centrality);
end

function sorted = topologicalSort(adj)
    % TOPOLOGICALSORT Performs topological sort on DAG
    %
    % Input:
    %   adj - Adjacency matrix of DAG
    %
    % Output:
    %   sorted - Vector of node indices in topological order
    
    nNodes = size(adj, 1);
    inDegree = sum(adj, 1)'; % In-degree for each node
    sorted = [];
    queue = find(inDegree == 0); % Nodes with no incoming edges
    
    while ~isempty(queue)
        % Remove node with zero in-degree
        node = queue(1);
        queue(1) = [];
        sorted = [sorted; node];
        
        % Update in-degrees of neighbors
        neighbors = find(adj(node, :) > 0);
        for neighbor = neighbors
            inDegree(neighbor) = inDegree(neighbor) - 1;
            if inDegree(neighbor) == 0
                queue = [queue; neighbor];
            end
        end
    end
    
    % Check if all nodes were sorted (if not, there's a cycle)
    if length(sorted) ~= nNodes
        warning('Graph may contain cycles or disconnected components');
    end
end

function parents = getParentNodes(adj, nodeIdx)
    % GETPARENTNODES Gets all parent nodes of a given node
    %
    % Inputs:
    %   adj - Adjacency matrix
    %   nodeIdx - Node index
    %
    % Output:
    %   parents - Vector of parent node indices
    
    parents = find(adj(:, nodeIdx) > 0);
end

function children = getChildNodes(adj, nodeIdx)
    % GETCHILDNODES Gets all child nodes of a given node
    %
    % Inputs:
    %   adj - Adjacency matrix
    %   nodeIdx - Node index
    %
    % Output:
    %   children - Vector of child node indices
    
    children = find(adj(nodeIdx, :) > 0);
end

function adj = buildAdjacencyFromChains(chains, nodeIds)
    % BUILDADJACENCYFROMCHAINS Builds adjacency matrix from all_chains array
    %
    % DEPRECATED: Use graph_topology.adjacency_matrix from enhanced API instead.
    % This function is kept for backward compatibility only.
    %
    % Inputs:
    %   chains - Cell array or struct array of chains from analysis.all_chains
    %            Each chain has 'node_ids' (or 'nodes') and optionally 'cumulative_risk'
    %   nodeIds - Cell array of all node IDs (defines node order)
    %
    % Output:
    %   adj - NxN adjacency matrix
    %
    % Note: Enhanced API provides graph_topology.adjacency_matrix directly.
    %       Use openapiHelpers('getAdjacencyMatrix', analysis) instead.
    
    warning('buildAdjacencyFromChains is deprecated. Use graph_topology.adjacency_matrix from enhanced API.');
    
    nNodes = length(nodeIds);
    adj = zeros(nNodes, nNodes);
    
    % Create node ID to index mapping
    nodeIdMap = containers.Map();
    for i = 1:nNodes
        nodeIdMap(nodeIds{i}) = i;
    end
    
    % Process chains
    if iscell(chains)
        chainArray = chains;
    elseif isstruct(chains)
        if length(chains) == 1 && isscalar(chains)
            chainArray = {chains};
        else
            chainArray = cell(length(chains), 1);
            for i = 1:length(chains)
                chainArray{i} = chains(i);
            end
        end
    else
        return; % Empty or invalid
    end
    
    % Extract edges from each chain
    edges = {};
    for chainIdx = 1:length(chainArray)
        chain = chainArray{chainIdx};
        
        % Get node IDs from chain
        % Python API only sends node_ids
        chainNodes = [];
        if isfield(chain, 'node_ids') && ~isempty(chain.node_ids)
            chainNodes = chain.node_ids;
        end
        
        if isempty(chainNodes) || length(chainNodes) < 2
            continue;
        end
        
        % Get weight from chain (use cumulative_risk if available)
        chainWeight = 1.0;
        if isfield(chain, 'cumulative_risk')
            chainWeight = chain.cumulative_risk;
        elseif isfield(chain, 'aggregate_risk')
            chainWeight = chain.aggregate_risk;
        end
        
        % Create edges between consecutive nodes
        for i = 1:(length(chainNodes) - 1)
            % Handle both cell array and array formats
            if iscell(chainNodes)
                srcId = chainNodes{i};
                tgtId = chainNodes{i+1};
            else
                srcId = chainNodes(i);
                tgtId = chainNodes(i+1);
                if isnumeric(srcId)
                    srcId = num2str(srcId);
                end
                if isnumeric(tgtId)
                    tgtId = num2str(tgtId);
                end
            end
            
            % Convert to char if string
            if isstring(srcId)
                srcId = char(srcId);
            end
            if isstring(tgtId)
                tgtId = char(tgtId);
            end
            
            % Create edge
            edge = struct();
            edge.source = srcId;
            edge.target = tgtId;
            edge.weight = chainWeight;
            edges{end+1} = edge;
        end
    end
    
    % Build adjacency matrix from edges
    if ~isempty(edges)
        adj = buildAdjacencyMatrix(nodeIds, edges);
    end
end

