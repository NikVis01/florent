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

