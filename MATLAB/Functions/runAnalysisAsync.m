function runAnalysisAsync(app, projectId, firmId, mode, config)
    % RUNANALYSISASYNC Run analysis in background with progress updates
    %
    % This function runs the analysis asynchronously using a timer to poll
    % progress and update the UI. The actual analysis runs in the background.
    %
    % Usage:
    %   runAnalysisAsync(app, 'proj_001', 'firm_001', 'interactive', config)
    
    % Set running flag
    if isprop(app, 'IsRunning')
        app.IsRunning = true;
    end
    
    % Disable controls (already done in callback, but ensure it's done)
    if isprop(app, 'RunAnalysisButton')
        app.RunAnalysisButton.Enable = 'off';
    end
    if isprop(app, 'LoadDemoButton')
        app.LoadDemoButton.Enable = 'off';
    end
    
    % Initialize progress
    updateAppProgress(app, 'initializing', 0, 'Initializing analysis...');
    
    % Create timer for progress updates
    % Note: MATLAB doesn't have true async, but we can use timers to update UI
    % For true background execution, consider using parallel workers
    
    try
        % Run analysis (this will block, but updateProgress calls drawnow)
        results = appIntegration('runAnalysis', app, projectId, firmId, mode, config);
        
        % Store results
        if isprop(app, 'Data')
            app.Data = results.data;
        end
        if isprop(app, 'StabilityData')
            app.StabilityData = results.stabilityData;
        end
        if isprop(app, 'MCResults')
            app.MCResults = results.mcResults;
        end
        
        % Display results
        appIntegration('displayResults', app, results);
        
        % Update current visualization
        if isprop(app, 'TabGroup') && ~isempty(app.StabilityData)
            updateCurrentVisualization(app);
        end
        
        % Success message
        updateAppProgress(app, 'complete', 100, 'Analysis complete!');
        
    catch ME
        % Error handling
        updateAppProgress(app, 'error', 0, sprintf('Error: %s', ME.message));
        
        % Show error dialog
        if isprop(app, 'UIFigure')
            uialert(app.UIFigure, ME.message, 'Analysis Error', 'Icon', 'error');
        end
    end
    
    % Re-enable controls
    if isprop(app, 'IsRunning')
        app.IsRunning = false;
    end
    if isprop(app, 'RunAnalysisButton')
        app.RunAnalysisButton.Enable = 'on';
    end
    if isprop(app, 'LoadDemoButton')
        app.LoadDemoButton.Enable = 'on';
    end
end

function updateCurrentVisualization(app)
    % Helper to update visualization based on current tab
    
    if ~isprop(app, 'TabGroup') || isempty(app.StabilityData) || isempty(app.Data)
        return;
    end
    
    selectedTab = app.TabGroup.SelectedTab;
    
    % Determine which visualization to show
    if isprop(app, 'MatrixTab') && selectedTab == app.MatrixTab
        appIntegration('updateVisualization', app, '2x2matrix', app.Data, app.StabilityData);
    elseif isprop(app, 'LandscapeTab') && selectedTab == app.LandscapeTab
        appIntegration('updateVisualization', app, '3dlandscape', app.Data, app.StabilityData);
    elseif isprop(app, 'GlobeTab') && selectedTab == app.GlobeTab
        appIntegration('updateVisualization', app, 'globe', app.Data, app.StabilityData);
    elseif isprop(app, 'NetworkTab') && selectedTab == app.NetworkTab
        appIntegration('updateVisualization', app, 'stabilitynetwork', app.Data, app.StabilityData);
    end
end

