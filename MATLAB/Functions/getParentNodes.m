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

