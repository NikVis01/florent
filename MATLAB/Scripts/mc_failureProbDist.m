function results = mc_failureProbDist(data, nIterations)
    % MC_FAILUREPROBDIST Monte Carlo simulation for failure probability distributions
    %
    % Samples P(failure) from Beta(α, β) distributions per node
    % Uses different α,β per node based on risk level
    %
    % Tracks: risk score distributions, critical chain variance
    %
    % Output: confidence intervals (mean ± 2σ) per node
    
    % Ensure paths are set up
    ensurePaths(false);
    
    if nargin < 2
        nIterations = 10000;
    end
    
    fprintf('Failure Probability Distribution Analysis: %d iterations\n', nIterations);
    
    % Define perturbation function
    perturbFunc = @(data, iter) perturbFailureProbabilities(data, iter);
    
    % Run Monte Carlo
    results = monteCarloFramework(data, perturbFunc, nIterations, true);
    
    % Calculate distribution statistics
    results.distributions = calculateDistributionStats(data, results);
    
    fprintf('Failure probability distribution analysis completed\n');
end

function [perturbedData, params] = perturbFailureProbabilities(data, iter)
    % Sample failure probabilities from Beta distributions
    
    % Copy data structure
    perturbedData = data;
    
    % Set random seed for reproducibility (optional)
    % rng(iter);
    
    nNodes = length(data.riskScores.nodeIds);
    
    % Sample failure probabilities from Beta distributions
    % Beta parameters based on risk level:
    %   Low risk: α=2, β=8 (mean ~0.2)
    %   Medium risk: α=5, β=5 (mean ~0.5)
    %   High risk: α=8, β=2 (mean ~0.8)
    
    perturbedData.riskScores.localFailureProb = zeros(nNodes, 1);
    
    for i = 1:nNodes
        riskLevel = data.riskScores.risk(i);
        
        % Map risk level to Beta parameters
        if riskLevel < 0.33
            % Low risk
            alpha = 2;
            beta = 8;
        elseif riskLevel < 0.67
            % Medium risk
            alpha = 5;
            beta = 5;
        else
            % High risk
            alpha = 8;
            beta = 2;
        end
        
        % Sample from Beta distribution
        % MATLAB's betarnd requires Statistics and Machine Learning Toolbox
        % Fallback: use uniform if toolbox not available
        try
            p_failure = betarnd(alpha, beta);
        catch
            % Fallback: approximate Beta with normal (not ideal but works)
            mean_beta = alpha / (alpha + beta);
            var_beta = (alpha * beta) / ((alpha + beta)^2 * (alpha + beta + 1));
            p_failure = normrnd(mean_beta, sqrt(var_beta));
            p_failure = max(0, min(1, p_failure)); % Clip to [0, 1]
        end
        
        perturbedData.riskScores.localFailureProb(i) = p_failure;
    end
    
    % Store parameters
    params = struct();
    params.betaParams = struct();
    params.betaParams.alpha = alpha;
    params.betaParams.beta = beta;
end

function distributions = calculateDistributionStats(data, results)
    % Calculate distribution statistics for failure probabilities
    
    distributions = struct();
    distributions.nodeIds = data.riskScores.nodeIds;
    nNodes = length(distributions.nodeIds);
    
    % Mean and standard deviation (already in results)
    distributions.mean = results.meanScores.risk;
    distributions.stdDev = results.stdDev.risk;
    
    % Confidence intervals (95% = mean ± 1.96*std)
    distributions.confidenceInterval95 = results.confidenceIntervals.risk;
    
    % Percentiles (if we had all iterations stored)
    % For now, use normal approximation
    distributions.percentiles = struct();
    distributions.percentiles.p5 = distributions.mean - 1.645 * distributions.stdDev;
    distributions.percentiles.p25 = distributions.mean - 0.674 * distributions.stdDev;
    distributions.percentiles.p50 = distributions.mean; % Median ≈ mean for normal
    distributions.percentiles.p75 = distributions.mean + 0.674 * distributions.stdDev;
    distributions.percentiles.p95 = distributions.mean + 1.645 * distributions.stdDev;
    
    % Skewness and kurtosis (approximated)
    distributions.skewness = zeros(nNodes, 1); % Would calculate from data if available
    distributions.kurtosis = zeros(nNodes, 1); % Would calculate from data if available
    
    % Identify nodes with wide distributions (high uncertainty)
    ciWidth = distributions.confidenceInterval95(:,2) - distributions.confidenceInterval95(:,1);
    distributions.highUncertainty = ciWidth >= prctile(ciWidth, 75);
    distributions.uncertaintyRank = sortrows([(1:nNodes)', ciWidth], 2, 'descend');
end

