% RUNFLORENTVISUALIZATION Simple script to run analysis and show figures
%
% Old-school MATLAB - just figures, no GUI bullshit
%
% Usage:
%   runFlorentVisualization()
%   runFlorentVisualization('proj_001', 'firm_001', 'test', 100)

function runFlorentVisualization(projectId, firmId, mode, nIterations)
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT RISK ANALYSIS\n');
    fprintf('========================================\n');
    
    % Defaults
    if nargin < 1
        projectId = 'proj_001';
    end
    if nargin < 2
        firmId = 'firm_001';
    end
    if nargin < 3
        mode = 'test';
    end
    if nargin < 4
        nIterations = 100;
    end
    
    fprintf('Project: %s\n', projectId);
    fprintf('Firm: %s\n', firmId);
    fprintf('Mode: %s\n', mode);
    fprintf('MC Iterations: %d\n', nIterations);
    fprintf('========================================\n\n');
    
    % Initialize
    try
        initializeFlorent(false);
        fprintf('Paths initialized\n');
    catch ME
        warning('Path init: %s', ME.message);
    end
    
    % Load config
    fprintf('Loading configuration...\n');
    try
        config = loadFlorentConfig(mode);
        config.monteCarlo.nIterations = nIterations;
        fprintf('Config loaded\n\n');
    catch ME
        warning('Config load failed: %s', ME.message);
        config = struct();
        config.monteCarlo = struct();
        config.monteCarlo.nIterations = nIterations;
    end
    
    % Run analysis
    fprintf('Running analysis...\n');
    
    % Suppress parallel pool warnings (we'll run sequentially)
    warning('off', 'parallel:convenience:LocalPoolStartup');
    warning('off', 'parallel:convenience:LocalPoolShutdown');
    
    try
        results = runFlorentAnalysis(projectId, firmId, mode, config);
        fprintf('Analysis complete!\n\n');
    catch ME
        error('Analysis failed: %s', ME.message);
    end
    
    % Re-enable warnings
    warning('on', 'parallel:convenience:LocalPoolStartup');
    warning('on', 'parallel:convenience:LocalPoolShutdown');
    
    % Extract data
    data = results.data;
    stabilityData = results.stabilityData;
    
    if isempty(stabilityData) || isempty(data)
        error('No data to visualize');
    end
    
    % Create visualizations in ONE figure window
    fprintf('Creating visualizations...\n');
    
    % Create single figure window with all axes
    fprintf('  - Creating single figure window\n');
    fig = figure('Name', 'Florent Risk Analysis', ...
        'Position', [100 100 1600 1200], ...
        'Renderer', 'opengl');
    
    % Create axes for each visualization
    ax1 = axes('Parent', fig, 'Position', [0.05 0.55 0.45 0.40]);
    ax2 = axes('Parent', fig, 'Position', [0.50 0.55 0.45 0.40]);
    ax3 = axes('Parent', fig, 'Position', [0.05 0.05 0.45 0.40]);
    ax4 = axes('Parent', fig, 'Position', [0.50 0.05 0.45 0.40]);
    
    % Plot directly into these axes (no figure creation in plotting functions)
    fprintf('    - 2x2 Matrix\n');
    try
        plot2x2MatrixWithEllipses(stabilityData, data, false, ax1);
    catch ME
        warning('2x2 Matrix failed: %s', ME.message);
    end
    
    fprintf('    - 3D Landscape\n');
    try
        plot3DRiskLandscape(stabilityData, data, false, ax2);
    catch ME
        warning('3D Landscape failed: %s', ME.message);
    end
    
    fprintf('    - Globe\n');
    try
        displayGlobe(data, stabilityData, config, ax3);
    catch ME
        warning('Globe failed: %s', ME.message);
    end
    
    fprintf('    - Stability Network\n');
    try
        plotStabilityNetwork(data, stabilityData, false, ax4);
    catch ME
        warning('Network failed: %s', ME.message);
    end
    
    fprintf('\n========================================\n');
    fprintf('  VISUALIZATIONS COMPLETE\n');
    fprintf('========================================\n');
    fprintf('All visualizations displayed in one figure window\n');
    fprintf('Close figure when done\n');
    fprintf('========================================\n\n');
    
    % Display summary
    if isfield(stabilityData, 'nodeIds')
        nNodes = length(stabilityData.nodeIds);
        avgStability = mean(stabilityData.overallStability);
        avgRisk = mean(stabilityData.meanScores.risk);
        avgInfluence = mean(stabilityData.meanScores.influence);
        
        fprintf('Summary:\n');
        fprintf('  Nodes: %d\n', nNodes);
        fprintf('  Avg Stability: %.3f\n', avgStability);
        fprintf('  Avg Risk: %.3f\n', avgRisk);
        fprintf('  Avg Influence: %.3f\n', avgInfluence);
        fprintf('\n');
    end
end

