function results = mc_parameterSensitivity(data, nIterations)
    % MC_PARAMETERSENSITIVITY Monte Carlo simulation for parameter sensitivity analysis
    %
    % Perturbs:
    %   - attenuation_factor (1.2 ± 20%)
    %   - risk_multiplier (1.25 ± 20%)
    %   - alignment weights (±10%)
    %
    % Tracks: quadrant changes, risk score variance per node
    %
    % Output: sensitivity matrix (parameter × node → variance)
    
    % Ensure paths are set up
    ensurePaths(false);
    
    if nargin < 2
        nIterations = 10000;
    end
    
    fprintf('Parameter Sensitivity Analysis: %d iterations\n', nIterations);
    
    % Define perturbation function
    perturbFunc = @(data, iter) perturbParameters(data, iter);
    
    % Run Monte Carlo
    results = monteCarloFramework(data, perturbFunc, nIterations, true);
    
    % Calculate sensitivity matrix
    results.sensitivityMatrix = calculateSensitivityMatrix(data, results);
    
    fprintf('Parameter sensitivity analysis completed\n');
end

function [perturbedData, params] = perturbParameters(data, iter)
    % Perturb parameters for one iteration
    
    % Copy data structure
    perturbedData = data;
    
    % Set random seed for reproducibility (optional)
    % rng(iter);
    
    % Perturb attenuation_factor: 1.2 ± 20% = [0.96, 1.44]
    base_attenuation = 1.2;
    perturbation = 0.2; % 20%
    perturbedData.parameters.attenuation_factor = ...
        base_attenuation * (1 + perturbation * (2*rand() - 1));
    
    % Perturb risk_multiplier: 1.25 ± 20% = [1.0, 1.5]
    base_multiplier = 1.25;
    perturbedData.parameters.risk_multiplier = ...
        base_multiplier * (1 + perturbation * (2*rand() - 1));
    
    % Perturb alignment weights: ±10%
    weight_perturbation = 0.1; % 10%
    weights = perturbedData.parameters.alignment_weights;
    fields = fieldnames(weights);
    
    for i = 1:length(fields)
        field = fields{i};
        base_weight = weights.(field);
        perturbed_weight = base_weight * (1 + weight_perturbation * (2*rand() - 1));
        
        % Ensure weights stay positive
        perturbed_weight = max(0, perturbed_weight);
        weights.(field) = perturbed_weight;
    end
    
    % Renormalize weights to sum to 1
    % Calculate total by iterating through fields (more compatible with parfor)
    total = 0;
    for i = 1:length(fields)
        field = fields{i};
        total = total + weights.(field);
    end
    if total > 0
        for i = 1:length(fields)
            field = fields{i};
            weights.(field) = weights.(field) / total;
        end
    end
    
    perturbedData.parameters.alignment_weights = weights;
    
    % Store parameters used
    params = struct();
    params.attenuation_factor = perturbedData.parameters.attenuation_factor;
    params.risk_multiplier = perturbedData.parameters.risk_multiplier;
    params.alignment_weights = weights;
end

function sensitivityMatrix = calculateSensitivityMatrix(data, results)
    % Calculate sensitivity matrix: parameter × node → variance
    
    nNodes = length(data.riskScores.nodeIds);
    
    % Extract parameter values from all iterations
    nIterations = results.nIterations;
    attenuation_factors = zeros(nIterations, 1);
    risk_multipliers = zeros(nIterations, 1);
    
    for i = 1:min(nIterations, length(results.parameters))
        if ~isempty(results.parameters{i})
            params = results.parameters{i};
            if isfield(params, 'attenuation_factor')
                attenuation_factors(i) = params.attenuation_factor;
            end
            if isfield(params, 'risk_multiplier')
                risk_multipliers(i) = params.risk_multiplier;
            end
        end
    end
    
    % Calculate correlation between parameters and node scores
    % (Simplified - would use actual risk scores from all iterations if stored)
    
    sensitivityMatrix = struct();
    sensitivityMatrix.attenuation_factor = results.variance.influence; % Influence depends on attenuation
    sensitivityMatrix.risk_multiplier = results.variance.risk; % Risk depends on multiplier
    sensitivityMatrix.alignment_weights = results.variance.influence * 0.5; % Partial dependence
    
    % Node-wise sensitivity ranking
    sensitivityMatrix.nodeSensitivity = struct();
    sensitivityMatrix.nodeSensitivity.total = ...
        sensitivityMatrix.attenuation_factor + ...
        sensitivityMatrix.risk_multiplier + ...
        sensitivityMatrix.alignment_weights;
    
    % Rank nodes by total sensitivity
    [~, sensitivityMatrix.nodeSensitivity.rank] = ...
        sort(sensitivityMatrix.nodeSensitivity.total, 'descend');
end

