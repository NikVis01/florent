function results = mc_crossEncoderUncertainty(data, nIterations)
    % MC_CROSSENCODERUNCERTAINTY Monte Carlo simulation for cross-encoder score uncertainty
    %
    % Adds Gaussian noise to BGE-M3 scores: ce_score + N(0, σ²)
    % where σ = 0.1-0.3 (configurable)
    %
    % Tracks: influence score stability, quadrant flips
    %
    % Output: nodes with high variance (unstable classifications)
    
    % Ensure paths are set up
    ensurePaths(false);
    
    if nargin < 2
        nIterations = 10000;
    end
    
    fprintf('Cross-Encoder Uncertainty Analysis: %d iterations\n', nIterations);
    
    % Define perturbation function
    perturbFunc = @(data, iter) perturbCrossEncoderScores(data, iter);
    
    % Run Monte Carlo
    results = monteCarloFramework(data, perturbFunc, nIterations, true);
    
    % Identify unstable nodes
    results.unstableNodes = identifyUnstableNodes(data, results);
    
    fprintf('Cross-encoder uncertainty analysis completed\n');
end

function [perturbedData, params] = perturbCrossEncoderScores(data, iter)
    % Add Gaussian noise to cross-encoder scores
    
    % Copy data structure
    perturbedData = data;
    
    % Set random seed for reproducibility (optional)
    % rng(iter);
    
    % Noise standard deviation (configurable: 0.1 to 0.3)
    sigma_min = 0.1;
    sigma_max = 0.3;
    sigma = sigma_min + (sigma_max - sigma_min) * rand();
    
    nNodes = length(data.riskScores.nodeIds);
    
    % Add noise to cross-encoder scores (use influence as proxy if CE scores not available)
    if ~isfield(perturbedData.riskScores, 'ce_scores')
        % Initialize CE scores from influence scores
        perturbedData.riskScores.ce_scores = perturbedData.riskScores.influence;
    end
    
    % Add Gaussian noise
    noise = sigma * randn(nNodes, 1);
    perturbedData.riskScores.ce_scores = perturbedData.riskScores.ce_scores + noise;
    
    % Clip to reasonable bounds (CE scores typically in [-5, 5] or [0, 1])
    perturbedData.riskScores.ce_scores = max(-5, min(5, perturbedData.riskScores.ce_scores));
    
    % Store parameters used
    params = struct();
    params.sigma = sigma;
    params.noise = noise;
end

function unstableNodes = identifyUnstableNodes(data, results)
    % Identify nodes with unstable classifications
    
    unstableNodes = struct();
    unstableNodes.nodeIds = data.riskScores.nodeIds;
    
    % High variance threshold (top 25% of variance)
    riskVarThreshold = prctile(results.variance.risk, 75);
    influenceVarThreshold = prctile(results.variance.influence, 75);
    
    % High flip count threshold (top 25% of flips)
    flipThreshold = prctile(results.flipCounts, 75);
    
    % Low stability threshold (bottom 25% of stability)
    stabilityThreshold = prctile(results.stability.quadrantStability, 25);
    
    % Identify unstable nodes
    unstableNodes.highRiskVariance = results.variance.risk >= riskVarThreshold;
    unstableNodes.highInfluenceVariance = results.variance.influence >= influenceVarThreshold;
    unstableNodes.highFlipCount = results.flipCounts >= flipThreshold;
    unstableNodes.lowStability = results.stability.quadrantStability <= stabilityThreshold;
    
    % Combined instability flag (unstable if any condition met)
    unstableNodes.isUnstable = unstableNodes.highRiskVariance | ...
        unstableNodes.highInfluenceVariance | ...
        unstableNodes.highFlipCount | ...
        unstableNodes.lowStability;
    
    % Get indices of unstable nodes
    unstableNodes.indices = find(unstableNodes.isUnstable);
    unstableNodes.count = sum(unstableNodes.isUnstable);
    
    fprintf('Identified %d unstable nodes (%.1f%%)\n', ...
        unstableNodes.count, 100*unstableNodes.count/length(data.riskScores.nodeIds));
end

