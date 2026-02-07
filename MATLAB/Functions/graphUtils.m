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

