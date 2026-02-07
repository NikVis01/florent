function influence = calculate_influence_score(ce_score, distance, attenuation_factor)
    % CALCULATE_INFLUENCE_SCORE Calculates influence score using Cross-Encoder and graph distance
    %
    % I_n = sigma(CE) * delta^(-d)
    %
    % Inputs:
    %   ce_score - Cross-encoder score (raw logit or probability)
    %   distance - Graph distance (hops from source)
    %   attenuation_factor - Damping factor per degree of separation
    %
    % Output:
    %   influence - Influence score in [0, 1]
    
    % Apply sigmoid to ensure bounded output
    influence_base = sigmoid(ce_score);
    
    % Apply distance damping
    damping = attenuation_factor^(-distance);
    
    influence = influence_base * damping;
end

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

function total_score = calculate_weighted_alignment(agent_scores, weights)
    % CALCULATE_WEIGHTED_ALIGNMENT Calculates final weighted alignment score
    %
    % Score = Sum(AgentAttribute_i * Weight_i)
    %
    % Inputs:
    %   agent_scores - Struct or map with agent attribute scores
    %   weights - Struct or map with weights for each attribute
    %
    % Output:
    %   total_score - Weighted sum of alignment scores
    
    total_score = 0.0;
    
    if isstruct(agent_scores) && isstruct(weights)
        fields = fieldnames(agent_scores);
        for i = 1:length(fields)
            attr = fields{i};
            if isfield(weights, attr)
                score = agent_scores.(attr);
                weight = weights.(attr);
                total_score = total_score + score * weight;
            end
        end
    elseif isa(agent_scores, 'containers.Map') && isa(weights, 'containers.Map')
        keys = agent_scores.keys;
        for i = 1:length(keys)
            attr = keys{i};
            if isKey(weights, attr)
                score = agent_scores(attr);
                weight = weights(attr);
                total_score = total_score + score * weight;
            end
        end
    end
end

function y = sigmoid(x)
    % SIGMOID Standard sigmoid function for mapping raw scores to (0, 1)
    %
    % y = 1 / (1 + exp(-x))
    
    y = 1 ./ (1 + exp(-x));
end

