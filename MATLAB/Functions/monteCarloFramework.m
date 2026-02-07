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
    %   nIterations - Number of MC iterations (default: 10000)
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
        nIterations = 10000;
    end
    if nargin < 4
        useParallel = true;
    end
    
    % Check if parallel toolbox is available
    if useParallel
        try
            pool = gcp('nocreate');
            if isempty(pool)
                pool = parpool('local');
            end
            useParallel = true;
            
            % Add Functions directory to path on all workers
            % This ensures all functions are accessible in parfor loops
            % Get absolute path to Functions directory
            scriptPath = mfilename('fullpath');
            scriptDir = fileparts(scriptPath);
            functionsDir = scriptDir; % monteCarloFramework.m is already in Functions directory
            
            % Add path to all workers using spmd (must be done before parfor)
            spmd
                if ~isempty(functionsDir) && exist(functionsDir, 'dir')
                    addpath(functionsDir);
                end
            end
            
            % Also attach required function files to parallel pool
            % These functions are called within the parfor loop
            addAttachedFiles(pool, {
                fullfile(functionsDir, 'riskCalculations.m'), ...
                fullfile(functionsDir, 'calculateEigenvectorCentrality.m'), ...
                fullfile(functionsDir, 'getParentNodes.m'), ...
                fullfile(functionsDir, 'classifyQuadrant.m')
            });
        catch
            warning('Parallel Computing Toolbox not available, running sequentially');
            useParallel = false;
        end
    end
    
    % Initialize storage
    nNodes = length(data.riskScores.nodeIds);
    
    % Storage for all iterations (can be memory intensive)
    allRiskScores = zeros(nIterations, nNodes);
    allInfluenceScores = zeros(nIterations, nNodes);
    allQuadrants = cell(nIterations, nNodes);
    allParameters = cell(nIterations, 1);
    
    % Base classification for comparison
    baseQuadrants = classifyQuadrant(...
        data.riskScores.risk, ...
        data.riskScores.influence ...
    );
    
    fprintf('Running %d Monte Carlo iterations...\n', nIterations);
    tic;
    
    if useParallel
        % Parallel execution
        parfor iter = 1:nIterations
            [perturbedData, params] = feval(perturbFunc, data, iter);
            
            % Calculate risk scores with perturbed parameters
            scores = calculateScoresForIteration(perturbedData);
            
            % Store results
            allRiskScores(iter, :) = scores.risk;
            allInfluenceScores(iter, :) = scores.influence;
            
            quadrants = classifyQuadrant(scores.risk, scores.influence);
            for j = 1:nNodes
                allQuadrants{iter, j} = quadrants{j};
            end
            
            allParameters{iter} = params;
            
            if mod(iter, 1000) == 0
                fprintf('Completed %d iterations\n', iter);
            end
        end
    else
        % Sequential execution
        for iter = 1:nIterations
            [perturbedData, params] = perturbFunc(data, iter);
            
            % Calculate risk scores with perturbed parameters
            scores = calculateScoresForIteration(perturbedData);
            
            % Store results
            allRiskScores(iter, :) = scores.risk;
            allInfluenceScores(iter, :) = scores.influence;
            
            quadrants = classifyQuadrant(scores.risk, scores.influence);
            for j = 1:nNodes
                allQuadrants{iter, j} = quadrants{j};
            end
            
            allParameters{iter} = params;
            
            if mod(iter, 100) == 0
                fprintf('Completed %d iterations (%.1f%%)\n', iter, 100*iter/nIterations);
            end
        end
    end
    
    elapsed = toc;
    fprintf('Monte Carlo completed in %.2f seconds\n', elapsed);
    
    % Aggregate results
    results = aggregateResults(allRiskScores, allInfluenceScores, allQuadrants, ...
        baseQuadrants, data.riskScores.nodeIds, allParameters);
end

function scores = calculateScoresForIteration(data)
    % Calculate risk and influence scores for one iteration
    nNodes = length(data.riskScores.nodeIds);
    scores = struct();
    scores.risk = zeros(nNodes, 1);
    scores.influence = zeros(nNodes, 1);
    
    % Get graph structure
    adj = data.graph.adjacency;
    
    % Calculate centrality if not already present
    if ~isfield(data.graph, 'centrality')
        data.graph.centrality = calculateEigenvectorCentrality(adj);
    end
    
    % Calculate scores for each node
    for i = 1:nNodes
        % Influence score (simplified - would use actual CE scores in real implementation)
        if isfield(data.riskScores, 'ce_scores') && length(data.riskScores.ce_scores) >= i
            ce_score = data.riskScores.ce_scores(i);
        else
            % Use influence as proxy for CE score
            ce_score = data.riskScores.influence(i);
        end
        
        % Calculate distance (simplified - would use actual graph distance)
        distance = 1; % Default distance
        
        % Calculate influence
        scores.influence(i) = calculate_influence_score(...
            ce_score, ...
            distance, ...
            data.parameters.attenuation_factor ...
        );
        
        % Risk score (cascading)
        local_failure_prob = data.riskScores.localFailureProb(i);
        
        % Get parent nodes
        parents = getParentNodes(adj, i);
        if ~isempty(parents)
            parent_success_probs = 1 - data.riskScores.localFailureProb(parents);
        else
            parent_success_probs = [];
        end
        
        p_success = calculate_topological_risk(...
            local_failure_prob, ...
            data.parameters.risk_multiplier, ...
            parent_success_probs ...
        );
        
        scores.risk(i) = 1 - p_success; % Risk = 1 - P(success)
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

