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

