% RUNFLORENTDEMO Quick demo script for Florent risk analysis
%
% This script provides a quick demonstration of the Florent analysis pipeline
% with minimal iterations for fast feedback. Good for presentations and exploration.
%
% Usage:
%   runFlorentDemo()
%   runFlorentDemo('test')  % Explicit test mode

function runFlorentDemo(mode)
    if nargin < 1
        mode = 'test';
    end
    
    fprintf('=== Florent Risk Analysis Demo ===\n');
    fprintf('Mode: %s (quick demo with reduced iterations)\n\n', mode);
    
    % Load configuration in test mode
    config = loadFlorentConfig(mode);
    
    % Override for even faster demo
    config.monteCarlo.nIterations = 100; % Very quick for demo
    
    % Default project and firm IDs
    projectId = 'proj_001';
    firmId = 'firm_001';
    
    fprintf('Loading data for Project: %s, Firm: %s\n', projectId, firmId);
    
    % Load data
    try
        data = getRiskData(config.api.baseUrl, projectId, firmId);
        fprintf('Data loaded successfully\n\n');
    catch ME
        warning('Failed to load data from API: %s\nUsing mock data', ME.message);
        data = getRiskData(); % Will use mock data
    end
    
    % Run quick MC simulation
    fprintf('Running quick Monte Carlo simulation (%d iterations)...\n', ...
        config.monteCarlo.nIterations);
    
    try
        % Run just parameter sensitivity for demo
        results = struct();
        results.parameterSensitivity = mc_parameterSensitivity(data, ...
            config.monteCarlo.nIterations);
        
        % Quick aggregation
        stabilityData = calculateStabilityScores(results);
        fprintf('Analysis completed\n\n');
    catch ME
        warning('MC simulation failed: %s', ME.message);
        return;
    end
    
    % Generate key visualizations
    fprintf('Generating visualizations...\n');
    
    try
        % 2x2 Matrix
        fig1 = plot2x2MatrixWithEllipses(stabilityData, data, true);
        fprintf('  - 2x2 Matrix created\n');
        
        % 3D Landscape
        fig2 = plot3DRiskLandscape(stabilityData, data, true);
        fprintf('  - 3D Landscape created\n');
        
        % Globe (if geographic data available)
        try
            fig3 = displayGlobe(data, stabilityData, config);
            fprintf('  - Globe visualization created\n');
        catch
            warning('Globe visualization skipped');
        end
        
        fprintf('Visualizations complete\n\n');
    catch ME
        warning('Visualization generation failed: %s', ME.message);
    end
    
    % Display summary
    fprintf('=== Demo Summary ===\n');
    fprintf('Total Nodes: %d\n', length(stabilityData.nodeIds));
    fprintf('Average Stability: %.3f\n', mean(stabilityData.overallStability));
    fprintf('Average Risk: %.3f\n', mean(stabilityData.meanScores.risk));
    fprintf('Average Influence: %.3f\n', mean(stabilityData.meanScores.influence));
    
    % Quadrant distribution
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    quadrants = classifyQuadrant(risk, influence);
    
    fprintf('\nQuadrant Distribution:\n');
    fprintf('  Q1 (Mitigate): %d\n', sum(strcmp(quadrants, 'Q1')));
    fprintf('  Q2 (Automate): %d\n', sum(strcmp(quadrants, 'Q2')));
    fprintf('  Q3 (Contingency): %d\n', sum(strcmp(quadrants, 'Q3')));
    fprintf('  Q4 (Delegate): %d\n', sum(strcmp(quadrants, 'Q4')));
    
    fprintf('\nDemo complete! Figures saved to: %s\n', config.paths.figuresDir);
    fprintf('For full analysis, run: runFlorentAnalysis()\n');
end

