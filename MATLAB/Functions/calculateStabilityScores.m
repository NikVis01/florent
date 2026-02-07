function stabilityData = calculateStabilityScores(mcResults)
    % CALCULATESTABILITYSCORES Aggregates all MC results and calculates stability scores
    %
    % Combines results from all four MC simulations:
    %   - Quadrant stability: % iterations node stayed in same quadrant
    %   - Score variance: coefficient of variation
    %   - Parameter sensitivity rank per node
    %
    % Input:
    %   mcResults - Structure with results from all MC simulations:
    %     .parameterSensitivity
    %     .crossEncoderUncertainty
    %     .topologyStress
    %     .failureProbDist
    %
    % Output:
    %   stabilityData - Aggregated stability metrics
    
    fprintf('Aggregating Monte Carlo results...\n');
    
    stabilityData = struct();
    
    % Get node IDs from first result (assuming all have same nodes)
    if isfield(mcResults, 'parameterSensitivity')
        nodeIds = mcResults.parameterSensitivity.nodeIds;
    elseif isfield(mcResults, 'crossEncoderUncertainty')
        nodeIds = mcResults.crossEncoderUncertainty.nodeIds;
    else
        error('No MC results provided');
    end
    
    nNodes = length(nodeIds);
    stabilityData.nodeIds = nodeIds;
    
    % Initialize aggregated metrics
    stabilityData.quadrantStability = zeros(nNodes, 1);
    stabilityData.scoreVariance = struct();
    stabilityData.scoreVariance.risk = zeros(nNodes, 1);
    stabilityData.scoreVariance.influence = zeros(nNodes, 1);
    stabilityData.coefficientOfVariation = struct();
    stabilityData.coefficientOfVariation.risk = zeros(nNodes, 1);
    stabilityData.coefficientOfVariation.influence = zeros(nNodes, 1);
    stabilityData.parameterSensitivityRank = zeros(nNodes, 1);
    stabilityData.flipCount = zeros(nNodes, 1);
    stabilityData.overallStability = zeros(nNodes, 1);
    
    % Aggregate from each simulation
    simCount = 0;
    
    if isfield(mcResults, 'parameterSensitivity')
        results = mcResults.parameterSensitivity;
        stabilityData.quadrantStability = stabilityData.quadrantStability + ...
            results.stability.quadrantStability;
        stabilityData.scoreVariance.risk = stabilityData.scoreVariance.risk + ...
            results.variance.risk;
        stabilityData.scoreVariance.influence = stabilityData.scoreVariance.influence + ...
            results.variance.influence;
        stabilityData.coefficientOfVariation.risk = stabilityData.coefficientOfVariation.risk + ...
            results.stability.coefficientOfVariation.risk;
        stabilityData.coefficientOfVariation.influence = stabilityData.coefficientOfVariation.influence + ...
            results.stability.coefficientOfVariation.influence;
        stabilityData.flipCount = stabilityData.flipCount + results.flipCount;
        
        % Parameter sensitivity rank
        if isfield(results, 'sensitivityMatrix') && ...
            isfield(results.sensitivityMatrix, 'nodeSensitivity')
            [~, rank] = sort(results.sensitivityMatrix.nodeSensitivity.total, 'descend');
            stabilityData.parameterSensitivityRank = stabilityData.parameterSensitivityRank + rank;
        end
        
        simCount = simCount + 1;
    end
    
    if isfield(mcResults, 'crossEncoderUncertainty')
        results = mcResults.crossEncoderUncertainty;
        stabilityData.quadrantStability = stabilityData.quadrantStability + ...
            results.stability.quadrantStability;
        stabilityData.scoreVariance.risk = stabilityData.scoreVariance.risk + ...
            results.variance.risk;
        stabilityData.scoreVariance.influence = stabilityData.scoreVariance.influence + ...
            results.variance.influence;
        stabilityData.coefficientOfVariation.risk = stabilityData.coefficientOfVariation.risk + ...
            results.stability.coefficientOfVariation.risk;
        stabilityData.coefficientOfVariation.influence = stabilityData.coefficientOfVariation.influence + ...
            results.stability.coefficientOfVariation.influence;
        stabilityData.flipCount = stabilityData.flipCount + results.flipCount;
        
        % Store unstable nodes info
        if isfield(results, 'unstableNodes')
            stabilityData.unstableNodes = results.unstableNodes;
        end
        
        simCount = simCount + 1;
    end
    
    if isfield(mcResults, 'topologyStress')
        results = mcResults.topologyStress;
        stabilityData.quadrantStability = stabilityData.quadrantStability + ...
            results.stability.quadrantStability;
        stabilityData.scoreVariance.risk = stabilityData.scoreVariance.risk + ...
            results.variance.risk;
        stabilityData.scoreVariance.influence = stabilityData.scoreVariance.influence + ...
            results.variance.influence;
        stabilityData.coefficientOfVariation.risk = stabilityData.coefficientOfVariation.risk + ...
            results.stability.coefficientOfVariation.risk;
        stabilityData.coefficientOfVariation.influence = stabilityData.coefficientOfVariation.influence + ...
            results.stability.coefficientOfVariation.influence;
        stabilityData.flipCount = stabilityData.flipCount + results.flipCount;
        
        % Store critical edges info
        if isfield(results, 'criticalEdges')
            stabilityData.criticalEdges = results.criticalEdges;
        end
        
        simCount = simCount + 1;
    end
    
    if isfield(mcResults, 'failureProbDist')
        results = mcResults.failureProbDist;
        stabilityData.quadrantStability = stabilityData.quadrantStability + ...
            results.stability.quadrantStability;
        stabilityData.scoreVariance.risk = stabilityData.scoreVariance.risk + ...
            results.variance.risk;
        stabilityData.scoreVariance.influence = stabilityData.scoreVariance.influence + ...
            results.variance.influence;
        stabilityData.coefficientOfVariation.risk = stabilityData.coefficientOfVariation.risk + ...
            results.stability.coefficientOfVariation.risk;
        stabilityData.coefficientOfVariation.influence = stabilityData.coefficientOfVariation.influence + ...
            results.stability.coefficientOfVariation.influence;
        stabilityData.flipCount = stabilityData.flipCount + results.flipCount;
        
        % Store distribution info
        if isfield(results, 'distributions')
            stabilityData.distributions = results.distributions;
        end
        
        simCount = simCount + 1;
    end
    
    % Average across simulations
    if simCount > 0
        stabilityData.quadrantStability = stabilityData.quadrantStability / simCount;
        stabilityData.scoreVariance.risk = stabilityData.scoreVariance.risk / simCount;
        stabilityData.scoreVariance.influence = stabilityData.scoreVariance.influence / simCount;
        stabilityData.coefficientOfVariation.risk = stabilityData.coefficientOfVariation.risk / simCount;
        stabilityData.coefficientOfVariation.influence = stabilityData.coefficientOfVariation.influence / simCount;
        stabilityData.flipCount = stabilityData.flipCount / simCount;
        if any(stabilityData.parameterSensitivityRank > 0)
            stabilityData.parameterSensitivityRank = stabilityData.parameterSensitivityRank / simCount;
        end
    end
    
    % Calculate overall stability score (0-1, higher = more stable)
    % Combine: quadrant stability (high is good), low variance (low is good), low flips (low is good)
    normalizedVariance = (stabilityData.scoreVariance.risk + stabilityData.scoreVariance.influence) / 2;
    normalizedVariance = normalizedVariance / (max(normalizedVariance) + eps); % Normalize to [0, 1]
    
    normalizedFlips = stabilityData.flipCount / (max(stabilityData.flipCount) + eps); % Normalize to [0, 1]
    
    % Overall stability: weighted combination
    stabilityData.overallStability = 0.5 * stabilityData.quadrantStability + ...
        0.25 * (1 - normalizedVariance) + ...
        0.25 * (1 - normalizedFlips);
    
    % Rank nodes by stability
    [~, stabilityData.stabilityRank] = sort(stabilityData.overallStability, 'descend');
    
    % Store mean scores from first available result
    if isfield(mcResults, 'parameterSensitivity')
        stabilityData.meanScores = mcResults.parameterSensitivity.meanScores;
    elseif isfield(mcResults, 'crossEncoderUncertainty')
        stabilityData.meanScores = mcResults.crossEncoderUncertainty.meanScores;
    end
    
    % Store all results for reference
    stabilityData.allResults = mcResults;
    
    fprintf('Stability scores calculated for %d nodes\n', nNodes);
    fprintf('Average stability: %.3f\n', mean(stabilityData.overallStability));
end

