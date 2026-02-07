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
    % Note: sigmoid is now a separate file, so we can call it directly
    influence_base = sigmoid(ce_score);
    
    % Apply distance damping
    damping = attenuation_factor^(-distance);
    
    influence = influence_base * damping;
end

