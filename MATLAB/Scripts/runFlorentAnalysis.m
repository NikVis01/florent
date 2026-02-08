% RUNFLORENTANALYSIS Main entry point for Florent risk analysis pipeline
%
% This is the master orchestrator that runs the complete analysis pipeline:
%   1. Load/validate data
%   2. Run MC simulations (with caching)
%   3. Aggregate results
%   4. Generate visualizations
%   5. Create dashboard
%   6. Export reports
%
% All data is fetched through OpenAPI calls - no local file scanning.
%
% Usage:
%   results = runFlorentAnalysis('project_id', 'firm_id')
%   results = runFlorentAnalysis('project_id', 'firm_id', 'production')
%   results = runFlorentAnalysis('project_id', 'firm_id', 'production', customConfig)
%   results = runFlorentAnalysis('src/data/poc/project.json', 'src/data/poc/firm.json')

function results = runFlorentAnalysis(projectId, firmId, mode, customConfig)
    % RUNFLORENTANALYSIS Main entry point for Florent risk analysis pipeline
    %
    % Uses API data from specified project and firm IDs/paths.
    % All data is fetched through OpenAPI calls - no local file scanning.
    %
    % Usage:
    %   results = runFlorentAnalysis('project_id', 'firm_id')
    %   results = runFlorentAnalysis('project_id', 'firm_id', 'production')
    %   results = runFlorentAnalysis('project_id', 'firm_id', 'production', customConfig)
    %   results = runFlorentAnalysis('src/data/poc/project.json', 'src/data/poc/firm.json')
    %
    % Arguments:
    %   projectId - Project identifier or path (required)
    %   firmId    - Firm identifier or path (required)
    %   mode      - Analysis mode: 'test', 'production', 'interactive' (default: 'production')
    %   customConfig - Custom configuration overrides (optional)
    
    % Require projectId and firmId
    if nargin < 1 || isempty(projectId)
        error('projectId is required. Usage: runFlorentAnalysis(projectId, firmId, [mode], [customConfig])');
    end
    if nargin < 2 || isempty(firmId)
        error('firmId is required. Usage: runFlorentAnalysis(projectId, firmId, [mode], [customConfig])');
    end
    
    % Optional parameters with defaults
    if nargin < 3 || isempty(mode)
        mode = 'production';
    end
    if nargin < 4
        customConfig = struct();
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT: INFRASTRUCTURE RISK ANALYSIS\n');
    fprintf('  Dependency Mapping & Risk Propagation\n');
    fprintf('========================================\n');
    fprintf('Project: %s\n', projectId);
    fprintf('Firm: %s\n', firmId);
    fprintf('Mode: %s\n', mode);
    fprintf('========================================\n\n');
    
    tic;
    
    % Load configuration
    fprintf('Phase 1: Loading configuration...\n');
    config = loadFlorentConfig(mode, customConfig);
    fprintf('Configuration loaded\n\n');
    
    % Initialize results structure
    results = struct();
    results.projectId = projectId;
    results.firmId = firmId;
    results.mode = mode;
    results.config = config;
    results.startTime = now;
    
    % Phase 2: Load data (returns enhanced API analysis structure)
    fprintf('Phase 2: Loading analysis data...\n');
    try
        data = runAnalysisPipeline('loadData', config, projectId, firmId);
        results.data = data; % Enhanced API analysis structure with node_assessments, 
                              % graph_topology, risk_distributions, monte_carlo_parameters, etc.
        fprintf('Data loaded successfully (enhanced API format)\n\n');
    catch ME
        error('Failed to load data: %s', ME.message);
    end
    
    % Phase 3: Run MC simulations (uses enhanced API analysis structure)
    fprintf('Phase 3: Running Monte Carlo simulations...\n');
    try
        % MC framework uses enhanced API structure with monte_carlo_parameters directly
        mcResults = runAnalysisPipeline('runMC', data, config);
        results.mcResults = mcResults;
        fprintf('MC simulations completed\n\n');
    catch ME
        warning('MC simulations failed: %s', ME.message);
        results.mcResults = struct();
    end
    
    % Phase 4: Aggregate results
    fprintf('Phase 4: Aggregating results...\n');
    try
        stabilityData = runAnalysisPipeline('aggregate', mcResults, config);
        results.stabilityData = stabilityData;
        fprintf('Results aggregated\n\n');
    catch ME
        error('Failed to aggregate results: %s', ME.message);
    end
    
    % Phase 5: Skip visualization generation (handled by runFlorentVisualization)
    fprintf('Phase 5: Skipping visualization generation (handled separately)\n');
    results.figures = [];
    fprintf('Visualization will be handled by runFlorentVisualization\n\n');
    
    % Phase 6: Skip dashboard creation (creates figures - handled separately)
    fprintf('Phase 6: Skipping dashboard creation (no figures)\n');
    results.dashboard = struct();
    dashboard = struct(); % For export phase
    fprintf('Dashboard creation skipped\n\n');
    
    % Phase 7: Export reports
    fprintf('Phase 7: Exporting reports...\n');
    try
        runAnalysisPipeline('export', dashboard, config);
        fprintf('Reports exported\n\n');
    catch ME
        warning('Report export had issues: %s', ME.message);
    end
    
    % Finalize
    results.endTime = now;
    results.duration = toc;
    
    fprintf('========================================\n');
    fprintf('  ANALYSIS COMPLETE\n');
    fprintf('========================================\n');
    fprintf('Total time: %.2f seconds\n', results.duration);
    fprintf('Results saved to: %s\n', config.paths.dataDir);
    fprintf('Figures saved to: %s\n', config.paths.figuresDir);
    fprintf('Reports saved to: %s\n', config.paths.reportsDir);
    fprintf('========================================\n\n');
    
    % Display summary
    displaySummary(results);
end

function displaySummary(results)
    % DISPLAYSUMMARY Display analysis summary from enhanced API structure
    %
    % Uses the enhanced API analysis structure and stabilityData to display
    % comprehensive summary information.
    
    fprintf('\n=== Analysis Summary ===\n');
    
    % Get analysis structure (enhanced API format)
    if ~isfield(results, 'data') || isempty(results.data)
        fprintf('No analysis data available\n\n');
        return;
    end
    
    analysis = results.data;
    
    % Validate enhanced API format
    if ~isstruct(analysis) || ~isfield(analysis, 'node_assessments')
        fprintf('Analysis data is not in enhanced API format\n\n');
        return;
    end
    
    % Extract basic node information
    nodeIds = openapiHelpers('getNodeIds', analysis);
    nNodes = length(nodeIds);
    fprintf('Total Nodes: %d\n', nNodes);
    
    % Extract scores
    risk = openapiHelpers('getAllRiskLevels', analysis);
    influence = openapiHelpers('getAllInfluenceScores', analysis);
    
    if ~isempty(risk) && ~isempty(influence)
        fprintf('Average Risk: %.3f\n', mean(risk));
        fprintf('Average Influence: %.3f\n', mean(influence));
    end
    
    % Get stability data if available
    if isfield(results, 'stabilityData') && ~isempty(results.stabilityData)
        stabilityData = results.stabilityData;
        if isfield(stabilityData, 'overallStability') && ~isempty(stabilityData.overallStability)
            fprintf('Average Stability: %.3f\n', mean(stabilityData.overallStability));
        end
    end
    
    % Get summary metrics from enhanced API structure
    if isfield(analysis, 'summary')
        summary = analysis.summary;
        fprintf('\n--- Project Summary ---\n');
        
        if isfield(summary, 'aggregate_project_score')
            fprintf('Aggregate Project Score: %.3f\n', summary.aggregate_project_score);
        end
        if isfield(summary, 'critical_failure_likelihood')
            fprintf('Critical Failure Likelihood: %.3f\n', summary.critical_failure_likelihood);
        end
        if isfield(summary, 'nodes_evaluated')
            fprintf('Nodes Evaluated: %d\n', summary.nodes_evaluated);
        end
        if isfield(summary, 'total_nodes')
            fprintf('Total Nodes: %d\n', summary.total_nodes);
        end
        if isfield(summary, 'critical_dependency_count')
            fprintf('Critical Dependencies: %d\n', summary.critical_dependency_count);
        end
        if isfield(summary, 'total_token_cost')
            fprintf('Token Cost: %d\n', summary.total_token_cost);
        end
    end
    
    % Get risk assessment details from enhanced API structure
    if isfield(analysis, 'recommendation')
        rec = analysis.recommendation;
        fprintf('\n--- Risk Assessment ---\n');
        
        if isfield(rec, 'confidence')
            fprintf('Assessment Confidence: %.3f\n', rec.confidence);
        end
        if isfield(rec, 'reasoning')
            fprintf('Reasoning: %s\n', rec.reasoning);
        end
        if isfield(rec, 'key_risks') && ~isempty(rec.key_risks)
            fprintf('Key Risks:\n');
            if iscell(rec.key_risks)
                for i = 1:min(5, length(rec.key_risks))
                    fprintf('  - %s\n', rec.key_risks{i});
                end
            end
        end
        if isfield(rec, 'key_opportunities') && ~isempty(rec.key_opportunities)
            fprintf('Key Opportunities:\n');
            if iscell(rec.key_opportunities)
                for i = 1:min(5, length(rec.key_opportunities))
                    fprintf('  - %s\n', rec.key_opportunities{i});
                end
            end
        end
    end
    
    % Get quadrant distribution from matrix_classifications
    if isfield(analysis, 'matrix_classifications')
        matrix = analysis.matrix_classifications;
        fprintf('\n--- Quadrant Distribution ---\n');
        
        % Count nodes in each quadrant
        q1Count = 0; q2Count = 0; q3Count = 0; q4Count = 0;
        
        if isfield(matrix, 'TYPE_A')
            if iscell(matrix.TYPE_A)
                q1Count = length(matrix.TYPE_A);
            elseif isstruct(matrix.TYPE_A)
                q1Count = length(matrix.TYPE_A);
            end
        end
        if isfield(matrix, 'TYPE_B')
            if iscell(matrix.TYPE_B)
                q2Count = length(matrix.TYPE_B);
            elseif isstruct(matrix.TYPE_B)
                q2Count = length(matrix.TYPE_B);
            end
        end
        if isfield(matrix, 'TYPE_C')
            if iscell(matrix.TYPE_C)
                q3Count = length(matrix.TYPE_C);
            elseif isstruct(matrix.TYPE_C)
                q3Count = length(matrix.TYPE_C);
            end
        end
        if isfield(matrix, 'TYPE_D')
            if iscell(matrix.TYPE_D)
                q4Count = length(matrix.TYPE_D);
            elseif isstruct(matrix.TYPE_D)
                q4Count = length(matrix.TYPE_D);
            end
        end
        
        totalClassified = q1Count + q2Count + q3Count + q4Count;
        if totalClassified > 0
            fprintf('Q1 (Mitigate - High Risk, High Influence): %d (%.1f%%)\n', ...
                q1Count, 100*q1Count/totalClassified);
            fprintf('Q2 (Automate - Low Risk, High Influence): %d (%.1f%%)\n', ...
                q2Count, 100*q2Count/totalClassified);
            fprintf('Q3 (Contingency - High Risk, Low Influence): %d (%.1f%%)\n', ...
                q3Count, 100*q3Count/totalClassified);
            fprintf('Q4 (Delegate - Low Risk, Low Influence): %d (%.1f%%)\n', ...
                q4Count, 100*q4Count/totalClassified);
        end
    else
        % Fallback: calculate quadrants from scores if matrix_classifications not available
        if ~isempty(risk) && ~isempty(influence)
            quadrants = classifyQuadrant(risk, influence);
            fprintf('\n--- Quadrant Distribution (Calculated) ---\n');
            fprintf('Q1 (Mitigate): %d (%.1f%%)\n', ...
                sum(strcmp(quadrants, 'Q1')), 100*sum(strcmp(quadrants, 'Q1'))/length(quadrants));
            fprintf('Q2 (Automate): %d (%.1f%%)\n', ...
                sum(strcmp(quadrants, 'Q2')), 100*sum(strcmp(quadrants, 'Q2'))/length(quadrants));
            fprintf('Q3 (Contingency): %d (%.1f%%)\n', ...
                sum(strcmp(quadrants, 'Q3')), 100*sum(strcmp(quadrants, 'Q3'))/length(quadrants));
            fprintf('Q4 (Delegate): %d (%.1f%%)\n', ...
                sum(strcmp(quadrants, 'Q4')), 100*sum(strcmp(quadrants, 'Q4'))/length(quadrants));
        end
    end
    
    fprintf('\n');
end

