% RUNALLMCSIMULATIONS Master script to orchestrate all Monte Carlo simulations
%
% This script runs all four MC simulations in parallel and aggregates results
%
% Usage:
%   runAllMCSimulations()
%   runAllMCSimulations(apiBaseUrl, projectId, firmId, nIterations)

function runAllMCSimulations(apiBaseUrl, projectId, firmId, nIterations)
    if nargin < 1
        apiBaseUrl = 'http://localhost:8000';
    end
    if nargin < 2
        projectId = 'proj_001';
    end
    if nargin < 3
        firmId = 'firm_001';
    end
    if nargin < 4
        nIterations = 100;
    end
    
    fprintf('=== Monte Carlo Simulation Suite ===\n');
    fprintf('Project: %s, Firm: %s\n', projectId, firmId);
    fprintf('Iterations per simulation: %d\n\n', nIterations);
    
    % Load base data
    fprintf('Loading base data...\n');
    data = getRiskData(apiBaseUrl, projectId, firmId);
    
    % Create output directory
    outputDir = fullfile(pwd, 'MATLAB', 'Data');
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    % Run all simulations in parallel
    fprintf('\n=== Starting parallel MC simulations ===\n');
    tic;
    
    % Ensure paths are set up
    ensurePaths(false);
    
    % Start parallel pool if available and setup worker paths
    try
        pool = gcp('nocreate');
        if isempty(pool)
            pool = parpool('local');
            fprintf('Created parallel pool with %d workers\n', pool.NumWorkers);
        else
            fprintf('Using existing parallel pool with %d workers\n', pool.NumWorkers);
        end
        
        % Setup paths on workers using centralized path manager
        fprintf('Configuring worker paths...\n');
        workerPathResult = pathManager('setupWorkerPaths', pool);
        if workerPathResult.success
            fprintf('Worker paths configured successfully\n');
        else
            warning('Worker path setup had issues: %s', strjoin(workerPathResult.errors, '; '));
        end
    catch ME
        warning('Parallel Computing Toolbox setup failed: %s. Simulations will run sequentially.', ME.message);
    end
    
    % Run simulations
    results = struct();
    
    fprintf('\n1. Parameter Sensitivity Analysis...\n');
    results.parameterSensitivity = mc_parameterSensitivity(data, nIterations);
    save(fullfile(outputDir, 'mc_parameterSensitivity.mat'), 'results', '-v7.3');
    
    fprintf('\n2. Cross-Encoder Uncertainty...\n');
    results.crossEncoderUncertainty = mc_crossEncoderUncertainty(data, nIterations);
    save(fullfile(outputDir, 'mc_crossEncoderUncertainty.mat'), 'results', '-v7.3');
    
    fprintf('\n3. Topology Stress Tests...\n');
    results.topologyStress = mc_topologyStress(data, nIterations);
    save(fullfile(outputDir, 'mc_topologyStress.mat'), 'results', '-v7.3');
    
    fprintf('\n4. Failure Probability Distributions...\n');
    results.failureProbDist = mc_failureProbDist(data, nIterations);
    save(fullfile(outputDir, 'mc_failureProbDist.mat'), 'results', '-v7.3');
    
    elapsed = toc;
    fprintf('\n=== All simulations completed in %.2f seconds ===\n', elapsed);
    
    % Aggregate results
    fprintf('\n=== Aggregating results ===\n');
    stabilityData = calculateStabilityScores(results);
    save(fullfile(outputDir, 'stabilityData.mat'), 'stabilityData', '-v7.3');
    
    fprintf('\nResults saved to: %s\n', outputDir);
    fprintf('Stability data saved to: stabilityData.mat\n');
end

