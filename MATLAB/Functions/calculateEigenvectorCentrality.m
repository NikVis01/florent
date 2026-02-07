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

