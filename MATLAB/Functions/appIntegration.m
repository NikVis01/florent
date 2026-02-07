function varargout = appIntegration(operation, app, varargin)
    % APPINTEGRATION Bridge functions between App Designer and Florent pipeline
    %
    % Usage:
    %   results = appIntegration('runAnalysis', app, projectId, firmId, mode, config)
    %   appIntegration('updateVisualization', app, type, data, stabilityData)
    %   appIntegration('displayResults', app, results)
    %   appIntegration('updateProgress', app, phase, progress, message)
    
    operation = lower(operation);
    
    switch operation
        case 'runanalysis'
            if nargin < 5
                error('runAnalysis requires app, projectId, firmId, mode, and config');
            end
            varargout{1} = runAnalysisForApp(app, varargin{1}, varargin{2}, varargin{3}, varargin{4});
            
        case 'updatevisualization'
            if nargin < 4
                error('updateVisualization requires app, type, data, and stabilityData');
            end
            updateAppVisualization(app, varargin{1}, varargin{2}, varargin{3});
            
        case 'displayresults'
            if nargin < 2
                error('displayResults requires app and results');
            end
            displayResultsInApp(app, varargin{1});
            
        case 'updateprogress'
            if nargin < 4
                error('updateProgress requires app, phase, progress, and message');
            end
            updateAppProgress(app, varargin{1}, varargin{2}, varargin{3});
            
        otherwise
            error('Unknown operation: %s', operation);
    end
end

function results = runAnalysisForApp(app, projectId, firmId, mode, config)
    % Run analysis with progress callbacks for app
    
    % Update progress
    updateAppProgress(app, 'initializing', 0, 'Initializing analysis...');
    
    try
        % Load data
        updateAppProgress(app, 'loading', 10, 'Loading data...');
        data = runAnalysisPipeline('loadData', config, projectId, firmId);
        
        % Store in app
        if isprop(app, 'Data')
            app.Data = data;
        end
        
        % Run MC simulations
        updateAppProgress(app, 'mc', 30, 'Running Monte Carlo simulations...');
        mcResults = runAnalysisPipeline('runMC', data, config);
        
        % Aggregate
        updateAppProgress(app, 'aggregating', 70, 'Aggregating results...');
        stabilityData = runAnalysisPipeline('aggregate', mcResults, config);
        
        % Store results
        if isprop(app, 'StabilityData')
            app.StabilityData = stabilityData;
        end
        if isprop(app, 'MCResults')
            app.MCResults = mcResults;
        end
        
        % Generate visualizations (optional, can be done on-demand)
        updateAppProgress(app, 'visualizing', 90, 'Preparing visualizations...');
        
        % Build results structure
        results = struct();
        results.data = data;
        results.stabilityData = stabilityData;
        results.mcResults = mcResults;
        results.config = config;
        results.projectId = projectId;
        results.firmId = firmId;
        
        updateAppProgress(app, 'complete', 100, 'Analysis complete!');
        
    catch ME
        updateAppProgress(app, 'error', 0, sprintf('Error: %s', ME.message));
        rethrow(ME);
    end
end

function updateAppVisualization(app, visualizationType, data, stabilityData)
    % Update visualization in app display panel
    
    % Get the appropriate axes
    axesHandle = getVisualizationAxes(app, visualizationType);
    
    if isempty(axesHandle)
        warning('Could not find axes for visualization type: %s', visualizationType);
        return;
    end
    
    % Clear axes
    cla(axesHandle);
    
    % Generate visualization based on type
    switch lower(visualizationType)
        case '2x2matrix'
            plot2x2MatrixWithEllipses(stabilityData, data, false, axesHandle);
            
        case '3dlandscape'
            plot3DRiskLandscape(stabilityData, data, false, axesHandle);
            
        case 'globe'
            displayGlobe(data, stabilityData, data.config, axesHandle);
            
        case 'stabilitynetwork'
            plotStabilityNetwork(data, stabilityData, false, axesHandle);
            
        case 'heatmap'
            if isprop(app, 'MCResults') && ~isempty(app.MCResults)
                plotParameterSensitivity(app.MCResults, false, axesHandle);
            end
            
        case 'convergence'
            if isprop(app, 'MCResults') && ~isempty(app.MCResults)
                plotMCConvergence(app.MCResults, false, axesHandle);
            end
            
        otherwise
            warning('Unknown visualization type: %s', visualizationType);
    end
    
    % Refresh display
    drawnow;
end

function displayResultsInApp(app, results)
    % Display results summary in app
    
    if ~isfield(results, 'stabilityData')
        return;
    end
    
    stabilityData = results.stabilityData;
    
    % Update status label if it exists
    if isprop(app, 'StatusLabel')
        nNodes = length(stabilityData.nodeIds);
        avgStability = mean(stabilityData.overallStability);
        avgRisk = mean(stabilityData.meanScores.risk);
        avgInfluence = mean(stabilityData.meanScores.influence);
        
        statusText = sprintf('Nodes: %d | Stability: %.3f | Risk: %.3f | Influence: %.3f', ...
            nNodes, avgStability, avgRisk, avgInfluence);
        app.StatusLabel.Text = statusText;
    end
    
    % Update results table if it exists
    if isprop(app, 'ResultsTable')
        updateResultsTable(app, stabilityData);
    end
    
    % Update findings text area if it exists
    if isprop(app, 'FindingsTextArea')
        updateFindingsText(app, stabilityData);
    end
    
    % Update statistics if panel exists
    if isprop(app, 'StatisticsPanel')
        updateStatisticsPanel(app, stabilityData);
    end
end

function axesHandle = getVisualizationAxes(app, visualizationType)
    % Get the appropriate axes handle for visualization type
    
    axesHandle = [];
    
    % Try to get from app properties
    % This depends on how axes are named in App Designer
    switch lower(visualizationType)
        case '2x2matrix'
            if isprop(app, 'MatrixAxes')
                axesHandle = app.MatrixAxes;
            elseif isprop(app, 'MainAxes')
                axesHandle = app.MainAxes;
            end
            
        case '3dlandscape'
            if isprop(app, 'LandscapeAxes')
                axesHandle = app.LandscapeAxes;
            elseif isprop(app, 'MainAxes')
                axesHandle = app.MainAxes;
            end
            
        case 'globe'
            if isprop(app, 'GlobeAxes')
                axesHandle = app.GlobeAxes;
            elseif isprop(app, 'MainAxes')
                axesHandle = app.MainAxes;
            end
            
        case 'stabilitynetwork'
            if isprop(app, 'NetworkAxes')
                axesHandle = app.NetworkAxes;
            elseif isprop(app, 'MainAxes')
                axesHandle = app.MainAxes;
            end
            
        otherwise
            % Default to main axes
            if isprop(app, 'MainAxes')
                axesHandle = app.MainAxes;
            end
    end
end

function updateResultsTable(app, stabilityData)
    % Update results table with node data
    
    if ~isprop(app, 'ResultsTable')
        return;
    end
    
    nNodes = length(stabilityData.nodeIds);
    
    % Prepare table data
    tableData = cell(nNodes, 5);
    for i = 1:nNodes
        tableData{i, 1} = stabilityData.nodeIds{i};
        tableData{i, 2} = stabilityData.meanScores.risk(i);
        tableData{i, 3} = stabilityData.meanScores.influence(i);
        
        % Get quadrant
        risk = stabilityData.meanScores.risk(i);
        influence = stabilityData.meanScores.influence(i);
        quad = classifyQuadrant(risk, influence);
        tableData{i, 4} = quad;
        
        tableData{i, 5} = stabilityData.overallStability(i);
    end
    
    % Update table
    app.ResultsTable.Data = tableData;
    app.ResultsTable.ColumnName = {'Node ID', 'Risk', 'Influence', 'Quadrant', 'Stability'};
end

function updateFindingsText(app, stabilityData)
    % Update findings text area
    
    if ~isprop(app, 'FindingsTextArea')
        return;
    end
    
    % Generate findings text
    findings = generateFindingsText(stabilityData);
    app.FindingsTextArea.Value = findings;
end

function findings = generateFindingsText(stabilityData)
    % Generate findings text from stability data
    
    findings = {};
    
    % Overall metrics
    avgStability = mean(stabilityData.overallStability);
    findings{end+1} = sprintf('Overall Stability: %.3f', avgStability);
    findings{end+1} = '';
    
    % Quadrant distribution
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    quadrants = classifyQuadrant(risk, influence);
    
    q1Count = sum(strcmp(quadrants, 'Q1'));
    q2Count = sum(strcmp(quadrants, 'Q2'));
    q3Count = sum(strcmp(quadrants, 'Q3'));
    q4Count = sum(strcmp(quadrants, 'Q4'));
    total = length(quadrants);
    
    findings{end+1} = 'Quadrant Distribution:';
    findings{end+1} = sprintf('  Q1 (Mitigate): %d (%.1f%%)', q1Count, 100*q1Count/total);
    findings{end+1} = sprintf('  Q2 (Automate): %d (%.1f%%)', q2Count, 100*q2Count/total);
    findings{end+1} = sprintf('  Q3 (Contingency): %d (%.1f%%)', q3Count, 100*q3Count/total);
    findings{end+1} = sprintf('  Q4 (Delegate): %d (%.1f%%)', q4Count, 100*q4Count/total);
    findings{end+1} = '';
    
    % Top risks
    [~, riskRank] = sort(stabilityData.meanScores.risk, 'descend');
    findings{end+1} = 'Top 5 Highest Risk Nodes:';
    for i = 1:min(5, length(riskRank))
        idx = riskRank(i);
        findings{end+1} = sprintf('  %d. %s (Risk: %.3f)', i, ...
            stabilityData.nodeIds{idx}, stabilityData.meanScores.risk(idx));
    end
    
    % Unstable nodes
    unstableIdx = find(stabilityData.overallStability < 0.5);
    if ~isempty(unstableIdx)
        findings{end+1} = '';
        findings{end+1} = sprintf('Unstable Nodes: %d (%.1f%%)', ...
            length(unstableIdx), 100*length(unstableIdx)/total);
    end
end

function updateStatisticsPanel(app, stabilityData)
    % Update statistics panel
    
    if ~isprop(app, 'StatisticsPanel')
        return;
    end
    
    % This would update child components of statistics panel
    % Implementation depends on panel structure
end

