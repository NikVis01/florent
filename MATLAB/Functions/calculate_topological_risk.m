function p_success = calculate_topological_risk(local_failure_prob, multiplier, parent_success_probs)
    % CALCULATE_TOPOLOGICAL_RISK Calculates cascading probability of success for a node
    %
    % P(S_n) = (1 - P(f_local) * mu) * Product(P(S_i) for i in parents)
    %
    % Inputs:
    %   local_failure_prob - Local failure probability of the node
    %   multiplier - Risk multiplier (mu)
    %   parent_success_probs - Vector of parent success probabilities
    %
    % Output:
    %   p_success - Probability of success for the node
    
    % Scale local failure probability by multiplier and clip to [0, 1]
    local_p_failure = min(1.0, local_failure_prob * multiplier);
    local_p_success = 1.0 - local_p_failure;
    
    % Calculate cumulative parent success (product)
    if isempty(parent_success_probs)
        parent_success_total = 1.0;
    else
        parent_success_total = prod(parent_success_probs);
    end
    
    p_success = local_p_success * parent_success_total;
end

