function results = monteCarloFramework(data, perturbFunc, nIterations, useParallel)
    % MONTECARLOFRAMEWORK Generic Monte Carlo runner for risk analysis
    %
    % This framework runs N iterations with parameter perturbations and tracks:
    %   - Node classifications per iteration
    %   - Risk/influence score variance
    %   - Quadrant flip counts
    %   - Stability metrics
    %
    % Inputs:
    %   data - Base data structure from getRiskData()
    %   perturbFunc - Function handle: [perturbedData, params] = perturbFunc(data, iter)
    %   nIterations - Number of MC iterations (default: 100)
    %   useParallel - Use parallel processing (default: true if available)
    %
    % Output:
    %   results - Structure with:
    %     .meanScores - Mean risk/influence scores per node
    %     .variance - Variance of scores per node
    %     .quadrantCounts - Count of each quadrant per node
    %     .flipCounts - Number of quadrant changes per node
    %     .stability - Stability metrics per node
    %     .allIterations - All scores from all iterations (optional, large)
    %     .parameters - Parameter values used in each iteration
    
    if nargin < 3
        nIterations = 1000;
    end
    if nargin < 4
        useParallel = true;
    end
    
    % Ensure paths are set BEFORE any processing (critical for both parallel and sequential)
    ensurePaths(false);  % Quiet mode
    
    % Verify that critical functions are accessible by actually testing them
    % Note: calculate_influence_score is in riskCalculations.m, and which() may not find it
    % if the first function name doesn't match the filename, so we test by calling it
    try
        testResult = calculate_influence_score(0.5, 1.0, 1.2);
        if ~isnumeric(testResult) || isempty(testResult)
            error('calculate_influence_score returned invalid result');
        end
    catch ME
        % Function not accessible - try to help user
        matlabDir = fileparts(fileparts(mfilename('fullpath')));
        riskCalcFile = fullfile(matlabDir, 'Functions', 'riskCalculations.m');
        if ~exist(riskCalcFile, 'file')
            error('riskCalculations.m not found at: %s\nPlease run initializeFlorent() first.', riskCalcFile);
        end
        % Force path refresh and try again
        rehash path;
        try
            testResult = calculate_influence_score(0.5, 1.0, 1.2);
            if ~isnumeric(testResult) || isempty(testResult)
                error('calculate_influence_score returned invalid result');
            end
        catch ME2
            error('calculate_influence_score is not accessible.\nFile exists at: %s\nError: %s\n\nPlease run initializeFlorent() to set up paths.', riskCalcFile, ME2.message);
        end
    end
    
    % Check if parallel toolbox is available
    if useParallel
        try
            
            % Verify main session paths
            mainPathCheck = pathManager('verifyPaths');
            if ~mainPathCheck.success
                warning('Main session path verification failed. Missing: %s', ...
                    strjoin([mainPathCheck.missingDirs, mainPathCheck.missingFunctions], ', '));
                warning('Attempting to setup paths...');
                pathManager('setupPaths', false);
                mainPathCheck = pathManager('verifyPaths');
                if ~mainPathCheck.success
                    error('Cannot setup paths. Please run initializeFlorent() first.');
                end
            end
            
            % Reuse existing pool if available, otherwise create one
            pool = gcp('nocreate');
            if isempty(pool)
                % No existing pool - create one
                fprintf('Creating parallel pool...\n');
                pool = parpool('local');
                useParallel = true;
                
                % Setup paths on all workers using centralized path manager
                fprintf('Configuring parallel workers with required paths...\n');
                workerPathResult = pathManager('setupWorkerPaths', pool);
                
                if ~workerPathResult.success
                    warning('Worker path setup had issues: %s', strjoin(workerPathResult.errors, '; '));
                    warning('Attempting verification...');
                    
                    % Verify worker paths
                    workerVerifyResult = pathManager('verifyWorkerPaths', pool);
                    
                    if ~workerVerifyResult.success
                        warning('Worker path verification failed: %s', strjoin(workerVerifyResult.errors, '; '));
                        warning('Falling back to sequential execution.');
                        useParallel = false;
                        try
                            delete(pool);
                        catch
                        end
                    else
                        fprintf('Worker paths verified successfully\n');
                    end
                else
                    fprintf('Worker paths configured successfully\n');
                end
            else
                % Pool exists - reuse it
                fprintf('Reusing existing parallel pool with %d workers\n', pool.NumWorkers);
                useParallel = true;
                
                % Verify worker paths are still configured
                workerVerifyResult = pathManager('verifyWorkerPaths', pool);
                if ~workerVerifyResult.success
                    % Paths not configured - set them up
                    fprintf('Configuring parallel workers with required paths...\n');
                    workerPathResult = pathManager('setupWorkerPaths', pool);
                    if ~workerPathResult.success
                        warning('Worker path setup had issues: %s', strjoin(workerPathResult.errors, '; '));
                    else
                        fprintf('Worker paths configured successfully\n');
                    end
                end
            end
            
        catch ME
            warning('Parallel Computing Toolbox setup failed: %s. Running sequentially.', ME.message);
            useParallel = false;
            % Don't delete pool - let it persist for future use
        end
    end
    
    % Validate that data is in enhanced API format
    if ~isstruct(data) || ~isfield(data, 'node_assessments')
        error('monteCarloFramework: data must be in enhanced API format with node_assessments');
    end
    
    % Get node IDs from enhanced schema
    nodeIds = openapiHelpers('getNodeIds', data);
    nNodes = length(nodeIds);
    
    if nNodes == 0
        error('monteCarloFramework: no nodes found in analysis data');
    end
    
    % Get enhanced sections
    mcParams = openapiHelpers('getMonteCarloParameters', data);
    riskDist = openapiHelpers('getRiskDistributions', data);
    graphTopo = openapiHelpers('getGraphTopology', data);
    
    if isempty(mcParams)
        warning('monteCarloFramework: monte_carlo_parameters not found, using defaults');
    end
    if isempty(graphTopo)
        warning('monteCarloFramework: graph_topology not found, adjacency will be empty');
    end
    
    % Storage for all iterations (can be memory intensive)
    allRiskScores = zeros(nIterations, nNodes);
    allInfluenceScores = zeros(nIterations, nNodes);
    allQuadrants = cell(nIterations, nNodes);
    allParameters = cell(nIterations, 1);
    
    % Get base scores for classification
    baseRisk = openapiHelpers('getAllRiskLevels', data);
    baseInfluence = openapiHelpers('getAllInfluenceScores', data);
    
    % Base classification for comparison
    baseQuadrants = classifyQuadrant(baseRisk, baseInfluence);
    
    fprintf('Running %d Monte Carlo iterations...\n', nIterations);
    tic;
    
    if useParallel
        % Parallel execution
        parfor iter = 1:nIterations
            % Sample from enhanced MC parameters
            [importanceSamples, influenceSamples] = sampleFromMCParameters(mcParams, nodeIds, iter);
            
            % Calculate risk scores from samples
            scores = calculateScoresFromSamples(importanceSamples, influenceSamples, data, graphTopo);
            
            % Store results
            allRiskScores(iter, :) = scores.risk;
            allInfluenceScores(iter, :) = scores.influence;
            
            quadrants = classifyQuadrant(scores.risk, scores.influence);
            for j = 1:nNodes
                allQuadrants{iter, j} = quadrants{j};
            end
            
            allParameters{iter} = struct('importance', importanceSamples, 'influence', influenceSamples);
            
            if mod(iter, 1000) == 0
                fprintf('Completed %d iterations\n', iter);
            end
        end
    else
        % Sequential execution
        for iter = 1:nIterations
            % Sample from enhanced MC parameters
            [importanceSamples, influenceSamples] = sampleFromMCParameters(mcParams, nodeIds, iter);
            
            % Calculate risk scores from samples
            scores = calculateScoresFromSamples(importanceSamples, influenceSamples, data, graphTopo);
            
            % Store results
            allRiskScores(iter, :) = scores.risk;
            allInfluenceScores(iter, :) = scores.influence;
            
            quadrants = classifyQuadrant(scores.risk, scores.influence);
            for j = 1:nNodes
                allQuadrants{iter, j} = quadrants{j};
            end
            
            allParameters{iter} = struct('importance', importanceSamples, 'influence', influenceSamples);
            
            if mod(iter, 100) == 0
                fprintf('Completed %d iterations (%.1f%%)\n', iter, 100*iter/nIterations);
            end
        end
    end
    
    elapsed = toc;
    fprintf('Monte Carlo completed in %.2f seconds\n', elapsed);
    
    % Aggregate results
    results = aggregateResults(allRiskScores, allInfluenceScores, allQuadrants, ...
        baseQuadrants, nodeIds, allParameters);
end

function [importanceSamples, influenceSamples] = sampleFromMCParameters(mcParams, nodeIds, seed)
    % SAMPLEFROMMCPARAMETERS Sample importance and influence from MC parameters
    %
    % Args:
    %   mcParams - MonteCarloParameters structure
    %   nodeIds - Cell array of node IDs
    %   seed - Random seed for this iteration
    %
    % Returns:
    %   importanceSamples - Array of importance samples
    %   influenceSamples - Array of influence samples
    
    nNodes = length(nodeIds);
    importanceSamples = zeros(nNodes, 1);
    influenceSamples = zeros(nNodes, 1);
    
    % Set random seed
    rng(seed);
    
    if isempty(mcParams) || ~isfield(mcParams, 'sampling_distributions')
        % Fallback: use uniform distribution
        importanceSamples = rand(nNodes, 1);
        influenceSamples = rand(nNodes, 1);
        return;
    end
    
    samplingDists = mcParams.sampling_distributions;
    
    % Sample for each node
    for i = 1:nNodes
        nodeId = nodeIds{i};
        
        if isfield(samplingDists, nodeId)
            nodeDist = samplingDists.(nodeId);
            
            % Sample importance
            if isfield(nodeDist, 'importance')
                impDist = nodeDist.importance;
                if strcmp(impDist.type, 'beta') && isfield(impDist.params, 'alpha') && isfield(impDist.params, 'beta')
                    importanceSamples(i) = betarnd(impDist.params.alpha, impDist.params.beta);
                    % Clamp to bounds
                    if isfield(impDist, 'bounds') && length(impDist.bounds) == 2
                        importanceSamples(i) = max(impDist.bounds(1), min(impDist.bounds(2), importanceSamples(i)));
                    end
                else
                    % Fallback to uniform
                    importanceSamples(i) = rand();
                end
            else
                importanceSamples(i) = rand();
            end
            
            % Sample influence
            if isfield(nodeDist, 'influence')
                infDist = nodeDist.influence;
                if strcmp(infDist.type, 'beta') && isfield(infDist.params, 'alpha') && isfield(infDist.params, 'beta')
                    influenceSamples(i) = betarnd(infDist.params.alpha, infDist.params.beta);
                    % Clamp to bounds
                    if isfield(infDist, 'bounds') && length(infDist.bounds) == 2
                        influenceSamples(i) = max(infDist.bounds(1), min(infDist.bounds(2), influenceSamples(i)));
                    end
                else
                    % Fallback to uniform
                    influenceSamples(i) = rand();
                end
            else
                influenceSamples(i) = rand();
            end
        else
            % Node not in sampling distributions, use uniform
            importanceSamples(i) = rand();
            influenceSamples(i) = rand();
        end
    end
    
    % Apply covariance if available
    if isfield(mcParams, 'covariance_matrix') && ~isempty(mcParams.covariance_matrix)
        % For correlated sampling, would use Cholesky decomposition
        % Simplified version: just use samples as-is for now
        % TODO: Implement proper correlated sampling
    end
end

function scores = calculateScoresFromSamples(importanceSamples, influenceSamples, analysis, graphTopo)
    % CALCULATESCORESFROMSAMPLES Calculate risk and influence scores from samples
    %
    % Args:
    %   importanceSamples - Array of importance samples
    %   influenceSamples - Array of influence samples
    %   analysis - Analysis structure (enhanced API format)
    %   graphTopo - GraphTopology structure
    %
    % Returns:
    %   scores - Structure with risk and influence arrays
    
    nNodes = length(importanceSamples);
    scores = struct();
    scores.risk = zeros(nNodes, 1);
    scores.influence = zeros(nNodes, 1);
    
    % Get adjacency matrix
    adjMatrix = openapiHelpers('getAdjacencyMatrix', analysis);
    if isempty(adjMatrix) && ~isempty(graphTopo) && isfield(graphTopo, 'adjacency_matrix')
        adjMatrix = graphTopo.adjacency_matrix;
        % Python always sends numeric array (List[List[float]]), no conversion needed
    end
    
    % Calculate risk = importance * (1 - influence)
    scores.risk = importanceSamples .* (1 - influenceSamples);
    
    % Use sampled influence directly
    scores.influence = influenceSamples;
    
    % Propagate risk through graph if adjacency is available
    if ~isempty(adjMatrix) && size(adjMatrix, 1) == nNodes && size(adjMatrix, 2) == nNodes
        % Get propagation trace for propagation factors
        propTrace = openapiHelpers('getPropagationTrace', analysis);
        
        % Simple propagation: risk propagates from parents
        for i = 1:nNodes
            % Find parents (incoming edges)
            parents = find(adjMatrix(:, i) > 0);
            
            if ~isempty(parents)
                % Get max parent risk
                maxParentRisk = max(scores.risk(parents));
                
                % Apply propagation (simplified)
                localRisk = scores.risk(i);
                scores.risk(i) = localRisk + (maxParentRisk * localRisk * 0.5);
            end
        end
    end
end

function results = aggregateResults(allRiskScores, allInfluenceScores, allQuadrants, ...
    baseQuadrants, nodeIds, allParameters)
    % Aggregate Monte Carlo results
    
    nNodes = length(nodeIds);
    nIterations = size(allRiskScores, 1);
    
    results = struct();
    results.nodeIds = nodeIds;
    results.nIterations = nIterations;
    
    % Mean and variance
    results.meanScores = struct();
    results.meanScores.risk = mean(allRiskScores, 1)';
    results.meanScores.influence = mean(allInfluenceScores, 1)';
    
    results.variance = struct();
    results.variance.risk = var(allRiskScores, 0, 1)';
    results.variance.influence = var(allInfluenceScores, 0, 1)';
    
    results.stdDev = struct();
    results.stdDev.risk = std(allRiskScores, 0, 1)';
    results.stdDev.influence = std(allInfluenceScores, 0, 1)';
    
    % Quadrant analysis
    results.quadrantCounts = struct();
    results.quadrantCounts.Q1 = zeros(nNodes, 1);
    results.quadrantCounts.Q2 = zeros(nNodes, 1);
    results.quadrantCounts.Q3 = zeros(nNodes, 1);
    results.quadrantCounts.Q4 = zeros(nNodes, 1);
    
    results.flipCounts = zeros(nNodes, 1);
    results.stability = struct();
    results.stability.quadrantStability = zeros(nNodes, 1);
    results.stability.coefficientOfVariation = struct();
    results.stability.coefficientOfVariation.risk = zeros(nNodes, 1);
    results.stability.coefficientOfVariation.influence = zeros(nNodes, 1);
    
    for i = 1:nNodes
        % Count quadrants
        quadrants = allQuadrants(:, i);
        results.quadrantCounts.Q1(i) = sum(strcmp(quadrants, 'Q1'));
        results.quadrantCounts.Q2(i) = sum(strcmp(quadrants, 'Q2'));
        results.quadrantCounts.Q3(i) = sum(strcmp(quadrants, 'Q3'));
        results.quadrantCounts.Q4(i) = sum(strcmp(quadrants, 'Q4'));
        
        % Count flips (changes from base quadrant)
        baseQuad = baseQuadrants{i};
        flips = sum(~strcmp(quadrants, baseQuad));
        results.flipCounts(i) = flips;
        
        % Quadrant stability (% iterations in most common quadrant)
        counts = [results.quadrantCounts.Q1(i), results.quadrantCounts.Q2(i), ...
            results.quadrantCounts.Q3(i), results.quadrantCounts.Q4(i)];
        results.stability.quadrantStability(i) = max(counts) / nIterations;
        
        % Coefficient of variation
        mean_risk = results.meanScores.risk(i);
        mean_influence = results.meanScores.influence(i);
        
        if mean_risk > 0
            results.stability.coefficientOfVariation.risk(i) = ...
                results.stdDev.risk(i) / mean_risk;
        end
        
        if mean_influence > 0
            results.stability.coefficientOfVariation.influence(i) = ...
                results.stdDev.influence(i) / mean_influence;
        end
    end
    
    % Confidence intervals (95% = mean ± 1.96*std)
    results.confidenceIntervals = struct();
    results.confidenceIntervals.risk = [
        results.meanScores.risk - 1.96 * results.stdDev.risk, ...
        results.meanScores.risk + 1.96 * results.stdDev.risk
    ];
    results.confidenceIntervals.influence = [
        results.meanScores.influence - 1.96 * results.stdDev.influence, ...
        results.meanScores.influence + 1.96 * results.stdDev.influence
    ];
    
    % Store parameters (sample)
    results.parameters = allParameters;
    
    % Store all iterations (optional - can be large, comment out if memory constrained)
    % results.allIterations = struct();
    % results.allIterations.risk = allRiskScores;
    % results.allIterations.influence = allInfluenceScores;
    % results.allIterations.quadrants = allQuadrants;
end


