% RUNFLORENTVISUALIZATION Simple script to run analysis and show figures
%
% Old-school MATLAB - just figures, no GUI bullshit
% All data is fetched through OpenAPI calls - no local file scanning.
%
% Usage:
%   runFlorentVisualization('project_id', 'firm_id')
%   runFlorentVisualization('project_id', 'firm_id', 'test', 100)
%   runFlorentVisualization('src/data/poc/project.json', 'src/data/poc/firm.json')

function runFlorentVisualization(projectId, firmId, mode, nIterations)
    % RUNFLORENTVISUALIZATION Run analysis and generate visualizations
    %
    % Uses API data from specified project and firm IDs/paths.
    % All data is fetched through OpenAPI calls - no local file scanning.
    %
    % Usage:
    %   runFlorentVisualization('project_id', 'firm_id')
    %   runFlorentVisualization('project_id', 'firm_id', 'test', 100)
    %   runFlorentVisualization('src/data/poc/project.json', 'src/data/poc/firm.json')
    %
    % Arguments:
    %   projectId - Project identifier or path (required)
    %   firmId    - Firm identifier or path (required)
    %   mode      - Analysis mode: 'test', 'production', 'interactive' (default: 'test')
    %   nIterations - MC iterations (default: 100)
    
    % Require projectId and firmId
    if nargin < 1 || isempty(projectId)
        error('projectId is required. Usage: runFlorentVisualization(projectId, firmId, [mode], [nIterations])');
    end
    if nargin < 2 || isempty(firmId)
        error('firmId is required. Usage: runFlorentVisualization(projectId, firmId, [mode], [nIterations])');
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT RISK ANALYSIS\n');
    fprintf('========================================\n');
    
    % Optional parameters with defaults
    if nargin < 3 || isempty(mode)
        mode = 'test';
    end
    if nargin < 4 || isempty(nIterations)
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
    
    % Extract data - results.data is the raw OpenAPI analysis structure
    analysis = results.data;
    stabilityData = results.stabilityData;
    
    if isempty(analysis)
        error('No analysis data to visualize');
    end
    
    % Validate that analysis is in OpenAPI format
    if ~isstruct(analysis) || ~isfield(analysis, 'node_assessments')
        error('Analysis data is not in OpenAPI format. Expected node_assessments field.');
    end
    
    % If stabilityData is empty (MC not run), create minimal structure from analysis
    if isempty(stabilityData)
        warning('No stability data from MC simulations. Using analysis data directly.');
        % Create minimal stabilityData structure for compatibility
        nodeIds = openapiHelpers('getNodeIds', analysis);
        influence = openapiHelpers('getAllInfluenceScores', analysis);
        risk = openapiHelpers('getAllRiskLevels', analysis);
        
        stabilityData = struct();
        stabilityData.nodeIds = nodeIds;
        stabilityData.meanScores = struct();
        stabilityData.meanScores.influence = influence;
        stabilityData.meanScores.risk = risk;
        stabilityData.overallStability = ones(length(nodeIds), 1); % Default stability
        stabilityData.scoreVariance = struct();
        stabilityData.scoreVariance.influence = zeros(length(nodeIds), 1);
        stabilityData.scoreVariance.risk = zeros(length(nodeIds), 1);
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
    % Note: Functions check parameters to detect OpenAPI format (node_assessments field)
    fprintf('    - 2x2 Matrix\n');
    try
        % plot2x2MatrixWithEllipses(stabilityData, data, ...) - checks first param for analysis
        plot2x2MatrixWithEllipses(analysis, stabilityData, false, ax1);
    catch ME
        warning('2x2 Matrix failed: %s', ME.message);
    end
    
    fprintf('    - 3D Landscape\n');
    try
        % plot3DRiskLandscape(stabilityData, data, ...) - checks first param for analysis
        plot3DRiskLandscape(analysis, stabilityData, false, ax2);
    catch ME
        warning('3D Landscape failed: %s', ME.message);
    end
    
    fprintf('    - Globe\n');
    try
        % displayGlobe(data, stabilityData, ...) - uses first param for project info,
        % checks second param for analysis structure (node_assessments)
        % Pass analysis as first param for project info, and analysis as second for node data
        displayGlobe(analysis, analysis, config, ax3);
    catch ME
        warning('Globe failed: %s', ME.message);
    end
    
    fprintf('    - Stability Network\n');
    try
        % plotStabilityNetwork(data, stabilityData, ...) - checks first param for analysis
        plotStabilityNetwork(analysis, stabilityData, false, ax4);
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
    fprintf('\n=== Analysis Summary ===\n');
    
    % Get node IDs from analysis
    nodeIds = openapiHelpers('getNodeIds', analysis);
    nNodes = length(nodeIds);
    fprintf('Total Nodes: %d\n', nNodes);
    
    % Get scores from analysis
    risk = openapiHelpers('getAllRiskLevels', analysis);
    influence = openapiHelpers('getAllInfluenceScores', analysis);
    
    if ~isempty(risk) && ~isempty(influence)
        fprintf('Average Risk: %.3f\n', mean(risk));
        fprintf('Average Influence: %.3f\n', mean(influence));
    end
    
    % Get stability if available
    if isfield(stabilityData, 'overallStability') && ~isempty(stabilityData.overallStability)
        fprintf('Average Stability: %.3f\n', mean(stabilityData.overallStability));
    end
    
    % Get summary metrics from analysis if available
    if isfield(analysis, 'summary')
        summary = analysis.summary;
        if isfield(summary, 'aggregate_project_score')
            fprintf('Aggregate Project Score: %.3f\n', summary.aggregate_project_score);
        end
        if isfield(summary, 'critical_failure_likelihood')
            fprintf('Critical Failure Likelihood: %.3f\n', summary.critical_failure_likelihood);
        end
    end
    
    % Get recommendation if available
    if isfield(analysis, 'recommendation')
        rec = analysis.recommendation;
        if isfield(rec, 'should_bid')
            fprintf('Recommendation: %s\n', char(string(rec.should_bid).replace("1", "BID").replace("0", "DO NOT BID")));
        end
        if isfield(rec, 'confidence')
            fprintf('Confidence: %.3f\n', rec.confidence);
        end
    end
    
    fprintf('\n');
end


