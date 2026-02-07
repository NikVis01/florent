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

