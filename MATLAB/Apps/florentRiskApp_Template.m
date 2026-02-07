% FLORENTRISKAPP_TEMPLATE Template for creating App Designer app
%
% This is a programmatic template for the Florent Risk Analysis App.
% To create the actual .mlapp file:
%   1. Open App Designer in MATLAB
%   2. Create new app
%   3. Use this template as reference for components and callbacks
%   4. Or use the provided component specifications
%
% The actual .mlapp file should be created in App Designer GUI.
% This file serves as documentation and reference.

classdef florentRiskApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        InputPanel          matlab.ui.container.Panel
        FirmDropdown       matlab.ui.control.DropDown
        ProjectDropdown    matlab.ui.control.DropDown
        ModeDropdown       matlab.ui.control.DropDown
        MCIterationsSlider matlab.ui.control.Slider
        MCIterationsLabel  matlab.ui.control.Label
        RunAnalysisButton   matlab.ui.control.Button
        LoadDemoButton     matlab.ui.control.Button
        DisplayPanel        matlab.ui.container.Panel
        TabGroup           matlab.ui.container.TabGroup
        MatrixTab          matlab.ui.container.Tab
        MatrixAxes         matlab.ui.control.UIAxes
        LandscapeTab       matlab.ui.container.Tab
        LandscapeAxes      matlab.ui.control.UIAxes
        GlobeTab           matlab.ui.container.Tab
        GlobeAxes          matlab.ui.control.UIAxes
        NetworkTab          matlab.ui.container.Tab
        NetworkAxes        matlab.ui.control.UIAxes
        StatusPanel        matlab.ui.container.Panel
        ProgressBar        matlab.ui.control.LinearGauge
        StatusLabel        matlab.ui.control.Label
        ResultsTable       matlab.ui.control.Table
        FindingsTextArea   matlab.ui.control.TextArea
    end

    % App-specific properties
    properties (Access = private)
        Data            % Analysis data
        StabilityData   % Stability analysis results
        MCResults      % Monte Carlo results
        Config         % Configuration
        IsRunning = false  % Analysis running flag
        CurrentTab = 1     % Current visualization tab
    end

    % Component creation
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1400 900];
            app.UIFigure.Name = 'Florent Risk Analysis';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create Input Panel (left side, 30% width)
            app.InputPanel = uipanel(app.UIFigure);
            app.InputPanel.Title = 'Analysis Controls';
            app.InputPanel.Position = [10 10 400 880];

            % Firm Dropdown
            app.FirmDropdown = uidropdown(app.InputPanel);
            app.FirmDropdown.Items = {'firm_001', 'firm_002'};
            app.FirmDropdown.Value = 'firm_001';
            app.FirmDropdown.Position = [20 800 360 30];
            app.FirmDropdown.Label = 'Firm:';

            % Project Dropdown
            app.ProjectDropdown = uidropdown(app.InputPanel);
            app.ProjectDropdown.Items = {'proj_001', 'proj_002'};
            app.ProjectDropdown.Value = 'proj_001';
            app.ProjectDropdown.Position = [20 750 360 30];
            app.ProjectDropdown.Label = 'Project:';

            % Mode Dropdown
            app.ModeDropdown = uidropdown(app.InputPanel);
            app.ModeDropdown.Items = {'test', 'interactive', 'production'};
            app.ModeDropdown.Value = 'interactive';
            app.ModeDropdown.Position = [20 700 360 30];
            app.ModeDropdown.Label = 'Mode:';

            % MC Iterations Slider
            app.MCIterationsSlider = uislider(app.InputPanel);
            app.MCIterationsSlider.Limits = [100 10000];
            app.MCIterationsSlider.Value = 1000;
            app.MCIterationsSlider.Position = [20 650 360 3];
            app.MCIterationsSlider.ValueChangedFcn = createCallbackFcn(app, @MCIterationsSliderValueChanged, true);

            app.MCIterationsLabel = uilabel(app.InputPanel);
            app.MCIterationsLabel.Text = 'MC Iterations: 1000';
            app.MCIterationsLabel.Position = [20 630 360 22];

            % Run Analysis Button
            app.RunAnalysisButton = uibutton(app.InputPanel, 'push');
            app.RunAnalysisButton.ButtonPushedFcn = createCallbackFcn(app, @RunAnalysisButtonPushed, true);
            app.RunAnalysisButton.Text = 'Run Analysis';
            app.RunAnalysisButton.Position = [20 550 360 40];
            app.RunAnalysisButton.FontSize = 14;
            app.RunAnalysisButton.FontWeight = 'bold';

            % Load Demo Button
            app.LoadDemoButton = uibutton(app.InputPanel, 'push');
            app.LoadDemoButton.ButtonPushedFcn = createCallbackFcn(app, @LoadDemoButtonPushed, true);
            app.LoadDemoButton.Text = 'Load Demo';
            app.LoadDemoButton.Position = [20 500 360 40];

            % Create Display Panel (right side, 70% width)
            app.DisplayPanel = uipanel(app.UIFigure);
            app.DisplayPanel.Title = 'Visualizations';
            app.DisplayPanel.Position = [420 10 970 880];

            % Create Tab Group
            app.TabGroup = uitabgroup(app.DisplayPanel);
            app.TabGroup.Position = [10 50 950 820];
            app.TabGroup.SelectionChangedFcn = createCallbackFcn(app, @TabGroupSelectionChanged, true);

            % Tab 1: 2x2 Matrix
            app.MatrixTab = uitab(app.TabGroup, 'Title', '2x2 Matrix');
            app.MatrixAxes = uiaxes(app.MatrixTab);
            app.MatrixAxes.Position = [10 10 930 780];

            % Tab 2: 3D Landscape
            app.LandscapeTab = uitab(app.TabGroup, 'Title', '3D Landscape');
            app.LandscapeAxes = uiaxes(app.LandscapeTab);
            app.LandscapeAxes.Position = [10 10 930 780];

            % Tab 3: Globe
            app.GlobeTab = uitab(app.TabGroup, 'Title', 'Globe');
            app.GlobeAxes = uiaxes(app.GlobeTab);
            app.GlobeAxes.Position = [10 10 930 780];

            % Tab 4: Network
            app.NetworkTab = uitab(app.TabGroup, 'Title', 'Stability Network');
            app.NetworkAxes = uiaxes(app.NetworkTab);
            app.NetworkAxes.Position = [10 10 930 780];

            % Create Status Panel (bottom)
            app.StatusPanel = uipanel(app.UIFigure);
            app.StatusPanel.Title = 'Status';
            app.StatusPanel.Position = [10 10 1380 100];

            % Progress Bar
            app.ProgressBar = uigauge(app.StatusPanel, 'linear');
            app.ProgressBar.Position = [20 50 500 30];
            app.ProgressBar.Limits = [0 100];
            app.ProgressBar.Value = 0;

            % Status Label
            app.StatusLabel = uilabel(app.StatusPanel);
            app.StatusLabel.Text = 'Ready';
            app.StatusLabel.Position = [540 50 800 30];
            app.StatusLabel.FontSize = 12;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = florentRiskApp
            % Create UIFigure and components
            createComponents(app);

            % Register the app with App Designer
            registerApp(app, app.UIFigure);

            % Execute the startup function
            runStartupFcn(app, @startupFcn);
        end

        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure);
        end
    end

    % Callback functions
    methods (Access = private)

        % Code that executes when app is started
        function startupFcn(app)
            % Initialize paths
            try
                initializeFlorent(false);
            catch
                warning('Path initialization had issues');
            end
            
            % Load default configuration
            mode = app.ModeDropdown.Value;
            app.Config = loadFlorentConfig(mode);
            
            % Update MC iterations from config
            app.MCIterationsSlider.Value = app.Config.monteCarlo.nIterations;
            app.MCIterationsLabel.Text = sprintf('MC Iterations: %d', app.Config.monteCarlo.nIterations);
            
            % Set initial status
            app.StatusLabel.Text = 'Ready - Select parameters and click Run Analysis';
        end

        % Button pushed function: RunAnalysisButton
        function RunAnalysisButtonPushed(app, event)
            % Disable controls
            app.IsRunning = true;
            app.RunAnalysisButton.Enable = 'off';
            
            % Get selections
            projectId = app.ProjectDropdown.Value;
            firmId = app.FirmDropdown.Value;
            mode = app.ModeDropdown.Value;
            
            % Update config with slider value
            app.Config.monteCarlo.nIterations = round(app.MCIterationsSlider.Value);
            
            try
                % Run analysis with progress updates
                results = appIntegration('runAnalysis', app, projectId, firmId, mode, app.Config);
                
                % Store results
                app.Data = results.data;
                app.StabilityData = results.stabilityData;
                app.MCResults = results.mcResults;
                
                % Display results
                appIntegration('displayResults', app, results);
                
                % Update current visualization
                updateCurrentVisualization(app);
                
            catch ME
                % Show error
                app.StatusLabel.Text = sprintf('Error: %s', ME.message);
                uialert(app.UIFigure, ME.message, 'Analysis Error');
            end
            
            % Re-enable controls
            app.IsRunning = false;
            app.RunAnalysisButton.Enable = 'on';
        end

        % Button pushed function: LoadDemoButton
        function LoadDemoButtonPushed(app, event)
            % Set demo parameters
            app.FirmDropdown.Value = 'firm_001';
            app.ProjectDropdown.Value = 'proj_001';
            app.ModeDropdown.Value = 'test';
            app.MCIterationsSlider.Value = 100;
            app.MCIterationsLabel.Text = 'MC Iterations: 100';
            
            app.StatusLabel.Text = 'Demo parameters loaded - Click Run Analysis';
        end

        % Value changed function: MCIterationsSlider
        function MCIterationsSliderValueChanged(app, event)
            value = round(app.MCIterationsSlider.Value);
            app.MCIterationsLabel.Text = sprintf('MC Iterations: %d', value);
        end

        % Selection changed function: TabGroup
        function TabGroupSelectionChanged(app, event)
            % Update visualization when tab changes
            if ~isempty(app.StabilityData)
                updateCurrentVisualization(app);
            end
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            delete(app);
        end
    end

    % Helper methods
    methods (Access = private)
        function updateCurrentVisualization(app)
            % Update visualization based on current tab
            
            if isempty(app.StabilityData) || isempty(app.Data)
                return;
            end
            
            selectedTab = app.TabGroup.SelectedTab;
            
            if selectedTab == app.MatrixTab
                appIntegration('updateVisualization', app, '2x2matrix', app.Data, app.StabilityData);
            elseif selectedTab == app.LandscapeTab
                appIntegration('updateVisualization', app, '3dlandscape', app.Data, app.StabilityData);
            elseif selectedTab == app.GlobeTab
                appIntegration('updateVisualization', app, 'globe', app.Data, app.StabilityData);
            elseif selectedTab == app.NetworkTab
                appIntegration('updateVisualization', app, 'stabilitynetwork', app.Data, app.StabilityData);
            end
        end
    end
end

