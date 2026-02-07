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
% Usage:
%   results = runFlorentAnalysis()
%   results = runFlorentAnalysis('proj_001', 'firm_001')
%   results = runFlorentAnalysis('proj_001', 'firm_001', 'production')
%   results = runFlorentAnalysis('proj_001', 'firm_001', 'production', customConfig)

function results = runFlorentAnalysis(projectId, firmId, mode, customConfig)
    % Parse inputs
    if nargin < 1
        projectId = 'proj_001';
    end
    if nargin < 2
        firmId = 'firm_001';
    end
    if nargin < 3
        mode = 'production';
    end
    if nargin < 4
        customConfig = struct();
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT RISK ANALYSIS PIPELINE\n');
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
    
    % Phase 2: Load data
    fprintf('Phase 2: Loading analysis data...\n');
    try
        data = runAnalysisPipeline('loadData', config, projectId, firmId);
        results.data = data;
        fprintf('Data loaded successfully\n\n');
    catch ME
        error('Failed to load data: %s', ME.message);
    end
    
    % Phase 3: Run MC simulations
    fprintf('Phase 3: Running Monte Carlo simulations...\n');
    try
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
    
    % Phase 5: Generate visualizations
    fprintf('Phase 5: Generating visualizations...\n');
    try
        figs = runAnalysisPipeline('visualize', data, stabilityData, config);
        results.figures = figs;
        fprintf('Visualizations generated\n\n');
    catch ME
        warning('Visualization generation had issues: %s', ME.message);
        results.figures = struct();
    end
    
    % Phase 6: Create dashboard
    fprintf('Phase 6: Creating dashboard...\n');
    try
        dashboard = runAnalysisPipeline('dashboard', data, stabilityData, figs, config);
        results.dashboard = dashboard;
        fprintf('Dashboard created\n\n');
    catch ME
        warning('Dashboard creation had issues: %s', ME.message);
        results.dashboard = struct();
    end
    
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
    % Display analysis summary
    
    if ~isfield(results, 'stabilityData')
        return;
    end
    
    stabilityData = results.stabilityData;
    
    fprintf('=== Analysis Summary ===\n');
    fprintf('Total Nodes: %d\n', length(stabilityData.nodeIds));
    fprintf('Average Stability: %.3f\n', mean(stabilityData.overallStability));
    fprintf('Average Risk: %.3f\n', mean(stabilityData.meanScores.risk));
    fprintf('Average Influence: %.3f\n', mean(stabilityData.meanScores.influence));
    
    % Quadrant distribution
    if isfield(stabilityData, 'meanScores')
        risk = stabilityData.meanScores.risk;
        influence = stabilityData.meanScores.influence;
        quadrants = classifyQuadrant(risk, influence);
        
        fprintf('\nQuadrant Distribution:\n');
        fprintf('  Q1 (Mitigate): %d (%.1f%%)\n', ...
            sum(strcmp(quadrants, 'Q1')), 100*sum(strcmp(quadrants, 'Q1'))/length(quadrants));
        fprintf('  Q2 (Automate): %d (%.1f%%)\n', ...
            sum(strcmp(quadrants, 'Q2')), 100*sum(strcmp(quadrants, 'Q2'))/length(quadrants));
        fprintf('  Q3 (Contingency): %d (%.1f%%)\n', ...
            sum(strcmp(quadrants, 'Q3')), 100*sum(strcmp(quadrants, 'Q3'))/length(quadrants));
        fprintf('  Q4 (Delegate): %d (%.1f%%)\n', ...
            sum(strcmp(quadrants, 'Q4')), 100*sum(strcmp(quadrants, 'Q4'))/length(quadrants));
    end
    
    fprintf('\n');
end

