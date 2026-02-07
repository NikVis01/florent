function updateAppProgress(app, phase, progress, message)
    % UPDATEAPPPROGRESS Update progress indicators in app
    %
    % Usage:
    %   updateAppProgress(app, 'loading', 50, 'Loading data...')
    %
    % Inputs:
    %   app - App Designer app object
    %   phase - Current phase: 'initializing', 'loading', 'mc', 'aggregating', 'visualizing', 'complete', 'error'
    %   progress - Progress percentage (0-100)
    %   message - Status message to display
    
    if nargin < 4
        message = '';
    end
    
    % Update progress bar if it exists
    if isprop(app, 'ProgressBar')
        app.ProgressBar.Value = min(100, max(0, progress));
    end
    
    % Update status label if it exists
    if isprop(app, 'StatusLabel') && ~isempty(message)
        app.StatusLabel.Text = message;
    end
    
    % Update status text area if it exists
    if isprop(app, 'StatusTextArea')
        currentText = app.StatusTextArea.Value;
        if iscell(currentText)
            currentText{end+1} = sprintf('[%.0f%%] %s', progress, message);
        else
            currentText = {sprintf('[%.0f%%] %s', progress, message)};
        end
        app.StatusTextArea.Value = currentText;
    end
    
    % Update phase indicator if it exists
    if isprop(app, 'PhaseLabel')
        phaseNames = containers.Map();
        phaseNames('initializing') = 'Initializing';
        phaseNames('loading') = 'Loading Data';
        phaseNames('mc') = 'Monte Carlo';
        phaseNames('aggregating') = 'Aggregating';
        phaseNames('visualizing') = 'Visualizing';
        phaseNames('complete') = 'Complete';
        phaseNames('error') = 'Error';
        
        if isKey(phaseNames, phase)
            app.PhaseLabel.Text = phaseNames(phase);
        end
    end
    
    % Enable/disable controls based on phase
    if strcmp(phase, 'complete') || strcmp(phase, 'error')
        enableControls(app, true);
    else
        enableControls(app, false);
    end
    
    % Force UI update
    drawnow;
end

function enableControls(app, enable)
    % Enable or disable app controls
    
    % Enable/disable run button
    if isprop(app, 'RunAnalysisButton')
        app.RunAnalysisButton.Enable = mat2str(enable);
    end
    
    % Enable/disable demo button
    if isprop(app, 'LoadDemoButton')
        app.LoadDemoButton.Enable = mat2str(enable);
    end
    
    % Enable/disable parameter controls
    if isprop(app, 'MCIterationsSlider')
        app.MCIterationsSlider.Enable = mat2str(enable);
    end
    
    if isprop(app, 'RiskThresholdSlider')
        app.RiskThresholdSlider.Enable = mat2str(enable);
    end
    
    if isprop(app, 'InfluenceThresholdSlider')
        app.InfluenceThresholdSlider.Enable = mat2str(enable);
    end
end

