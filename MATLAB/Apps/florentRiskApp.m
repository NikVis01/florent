% FLORENTRISKAPP Simple figure-based GUI for Florent Risk Analysis
%
% This uses standard MATLAB figure/uicontrol - no App Designer bullshit
%
% Usage:
%   app = florentRiskApp

classdef florentRiskApp < handle

    % Properties
    properties (Access = public)
        Figure            % Main figure
        Data            % Analysis data
        StabilityData   % Stability analysis results
        MCResults      % Monte Carlo results
        Config         % Configuration
        Results        % Full results from runFlorentAnalysis
    end
    
    properties (Access = private)
        % Input controls
        FirmPopup
        ProjectPopup
        ModePopup
        MCIterationsSlider
        MCIterationsText
        RunButton
        DemoButton
        
        % Display axes
        MatrixAxes
        LandscapeAxes
        GlobeAxes
        NetworkAxes
        
        % Status
        StatusText
        ProgressBar
        
        % Current tab
        CurrentTab = 1
    end

    % Constructor
    methods
        function app = florentRiskApp
            fprintf(2, '\n[DEBUG] Creating florentRiskApp...\n');
            drawnow;
            
            try
                createGUI(app);
                initializeApp(app);
                fprintf(2, '[DEBUG] App created successfully!\n');
            catch ME
                fprintf(2, '[ERROR] Failed to create app: %s\n', ME.message);
                rethrow(ME);
            end
        end
        
        function delete(app)
            if isvalid(app.Figure)
                delete(app.Figure);
            end
        end
    end
    
    % GUI Creation
    methods (Access = private)
        function createGUI(app)
            fprintf(2, '[DEBUG] Creating GUI components...\n');
            drawnow;
            
            % Create main figure
            app.Figure = figure('Name', 'Florent Risk Analysis', ...
                'Position', [100 100 1400 900], ...
                'Renderer', 'opengl', ...
                'CloseRequestFcn', @(~,~) app.closeApp);
            
            % Input Panel (left)
            inputPanel = uipanel('Parent', app.Figure, ...
                'Title', 'Analysis Controls', ...
                'Position', [0.01 0.12 0.28 0.85]);
            
            % Firm dropdown
            uicontrol('Parent', inputPanel, 'Style', 'text', ...
                'String', 'Firm:', 'Position', [20 700 100 20], ...
                'HorizontalAlignment', 'left');
            app.FirmPopup = uicontrol('Parent', inputPanel, 'Style', 'popupmenu', ...
                'String', {'firm_001', 'firm_002'}, ...
                'Position', [20 680 360 25], ...
                'Callback', @(~,~) app.updateStatus);
            
            % Project dropdown
            uicontrol('Parent', inputPanel, 'Style', 'text', ...
                'String', 'Project:', 'Position', [20 650 100 20], ...
                'HorizontalAlignment', 'left');
            app.ProjectPopup = uicontrol('Parent', inputPanel, 'Style', 'popupmenu', ...
                'String', {'proj_001', 'proj_002'}, ...
                'Position', [20 630 360 25], ...
                'Callback', @(~,~) app.updateStatus);
            
            % Mode dropdown
            uicontrol('Parent', inputPanel, 'Style', 'text', ...
                'String', 'Mode:', 'Position', [20 600 100 20], ...
                'HorizontalAlignment', 'left');
            app.ModePopup = uicontrol('Parent', inputPanel, 'Style', 'popupmenu', ...
                'String', {'test', 'interactive', 'production'}, ...
                'Position', [20 580 360 25], ...
                'Value', 2, ...
                'Callback', @(~,~) app.updateStatus);
            
            % MC Iterations slider
            uicontrol('Parent', inputPanel, 'Style', 'text', ...
                'String', 'MC Iterations:', 'Position', [20 550 150 20], ...
                'HorizontalAlignment', 'left');
            app.MCIterationsSlider = uicontrol('Parent', inputPanel, 'Style', 'slider', ...
                'Min', 100, 'Max', 10000, 'Value', 1000, ...
                'Position', [20 530 360 20], ...
                'Callback', @(~,~) app.updateMCIterations);
            app.MCIterationsText = uicontrol('Parent', inputPanel, 'Style', 'text', ...
                'String', 'MC Iterations: 1000', ...
                'Position', [20 510 360 20], ...
                'HorizontalAlignment', 'left');
            
            % Buttons
            app.RunButton = uicontrol('Parent', inputPanel, 'Style', 'pushbutton', ...
                'String', 'Run Analysis', ...
                'Position', [20 450 360 40], ...
                'FontSize', 14, 'FontWeight', 'bold', ...
                'Callback', @(~,~) app.runAnalysis);
            
            app.DemoButton = uicontrol('Parent', inputPanel, 'Style', 'pushbutton', ...
                'String', 'Load Demo', ...
                'Position', [20 400 360 40], ...
                'Callback', @(~,~) app.loadDemo);
            
            % Display Panel (right)
            displayPanel = uipanel('Parent', app.Figure, ...
                'Title', 'Visualizations', ...
                'Position', [0.30 0.12 0.69 0.85]);
            
            % Tab buttons
            uicontrol('Parent', displayPanel, 'Style', 'pushbutton', ...
                'String', '2x2 Matrix', ...
                'Position', [10 720 150 30], ...
                'Callback', @(~,~) app.switchTab(1));
            uicontrol('Parent', displayPanel, 'Style', 'pushbutton', ...
                'String', '3D Landscape', ...
                'Position', [170 720 150 30], ...
                'Callback', @(~,~) app.switchTab(2));
            uicontrol('Parent', displayPanel, 'Style', 'pushbutton', ...
                'String', 'Globe', ...
                'Position', [330 720 150 30], ...
                'Callback', @(~,~) app.switchTab(3));
            uicontrol('Parent', displayPanel, 'Style', 'pushbutton', ...
                'String', 'Network', ...
                'Position', [490 720 150 30], ...
                'Callback', @(~,~) app.switchTab(4));
            
            % Create axes (only Matrix initially, others lazy)
            app.MatrixAxes = axes('Parent', displayPanel, ...
                'Position', [0.05 0.05 0.90 0.90], ...
                'Visible', 'on');
            app.MatrixAxes.XAxis.Visible = 'off';
            app.MatrixAxes.YAxis.Visible = 'off';
            app.MatrixAxes.Color = [0.94 0.94 0.94];
            xlim(app.MatrixAxes, [0 1]);
            ylim(app.MatrixAxes, [0 1]);
            text(app.MatrixAxes, 0.5, 0.6, '2x2 Risk Matrix', ...
                'HorizontalAlignment', 'center', 'FontSize', 24, ...
                'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
            text(app.MatrixAxes, 0.5, 0.4, 'Click "Run Analysis" to generate visualization', ...
                'HorizontalAlignment', 'center', 'FontSize', 14, ...
                'Color', [0.5 0.5 0.5]);
            
            app.LandscapeAxes = [];
            app.GlobeAxes = [];
            app.NetworkAxes = [];
            
            % Status Panel (bottom)
            statusPanel = uipanel('Parent', app.Figure, ...
                'Title', 'Status', ...
                'Position', [0.01 0.01 0.98 0.10]);
            
            app.StatusText = uicontrol('Parent', statusPanel, 'Style', 'text', ...
                'String', 'Ready - Select parameters and click Run Analysis', ...
                'Position', [20 50 1000 30], ...
                'HorizontalAlignment', 'left', ...
                'FontSize', 12);
            
            app.ProgressBar = uicontrol('Parent', statusPanel, 'Style', 'text', ...
                'String', '', ...
                'Position', [20 20 500 20], ...
                'BackgroundColor', [0.8 0.8 0.8]);
            
            fprintf(2, '[DEBUG] GUI components created\n');
            drawnow;
        end
        
        function initializeApp(app)
            fprintf(2, '[DEBUG] Initializing app...\n');
            drawnow;
            
            try
                initializeFlorent(false);
                fprintf(2, '[DEBUG] Paths initialized\n');
            catch ME
                fprintf(2, '[WARNING] Path init failed: %s\n', ME.message);
            end
            
            % Load config
            modeItems = get(app.ModePopup, 'String');
            mode = modeItems{get(app.ModePopup, 'Value')};
            try
                app.Config = loadFlorentConfig(mode);
                if isfield(app.Config, 'monteCarlo') && isfield(app.Config.monteCarlo, 'nIterations')
                    set(app.MCIterationsSlider, 'Value', app.Config.monteCarlo.nIterations);
                    app.updateMCIterations();
                end
                fprintf(2, '[DEBUG] Config loaded\n');
            catch ME
                fprintf(2, '[WARNING] Config load failed: %s\n', ME.message);
                app.Config = struct();
                app.Config.monteCarlo = struct();
                app.Config.monteCarlo.nIterations = 1000;
            end
            
            fprintf(2, '[DEBUG] App initialized\n');
            drawnow;
        end
    end
    
    % Callbacks
    methods (Access = private)
        function updateMCIterations(app)
            value = round(get(app.MCIterationsSlider, 'Value'));
            set(app.MCIterationsText, 'String', sprintf('MC Iterations: %d', value));
        end
        
        function updateStatus(app)
            % Update status when controls change
        end
        
        function loadDemo(app)
            set(app.FirmPopup, 'Value', 1);
            set(app.ProjectPopup, 'Value', 1);
            set(app.ModePopup, 'Value', 1);
            set(app.MCIterationsSlider, 'Value', 100);
            app.updateMCIterations();
            set(app.StatusText, 'String', 'Demo parameters loaded - Click Run Analysis');
        end
        
        function switchTab(app, tabNum)
            fprintf(2, '[DEBUG] Switching to tab %d\n', tabNum);
            drawnow;
            
            % Hide all axes
            if ~isempty(app.MatrixAxes)
                set(app.MatrixAxes, 'Visible', 'off');
            end
            if ~isempty(app.LandscapeAxes)
                set(app.LandscapeAxes, 'Visible', 'off');
            end
            if ~isempty(app.GlobeAxes)
                set(app.GlobeAxes, 'Visible', 'off');
            end
            if ~isempty(app.NetworkAxes)
                set(app.NetworkAxes, 'Visible', 'off');
            end
            
            % Show/create selected tab
            displayPanel = get(app.MatrixAxes, 'Parent');
            
            switch tabNum
                case 1
                    set(app.MatrixAxes, 'Visible', 'on');
                    app.CurrentTab = 1;
                case 2
                    if isempty(app.LandscapeAxes)
                        app.LandscapeAxes = axes('Parent', displayPanel, ...
                            'Position', [0.05 0.05 0.90 0.90], ...
                            'Visible', 'on');
                        app.LandscapeAxes.XAxis.Visible = 'off';
                        app.LandscapeAxes.YAxis.Visible = 'off';
                        app.LandscapeAxes.Color = [0.94 0.94 0.94];
                        xlim(app.LandscapeAxes, [0 1]);
                        ylim(app.LandscapeAxes, [0 1]);
                        text(app.LandscapeAxes, 0.5, 0.6, '3D Risk Landscape', ...
                            'HorizontalAlignment', 'center', 'FontSize', 24, ...
                            'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
                        text(app.LandscapeAxes, 0.5, 0.4, 'Click "Run Analysis" to generate visualization', ...
                            'HorizontalAlignment', 'center', 'FontSize', 14, ...
                            'Color', [0.5 0.5 0.5]);
                    end
                    set(app.LandscapeAxes, 'Visible', 'on');
                    app.CurrentTab = 2;
                case 3
                    if isempty(app.GlobeAxes)
                        app.GlobeAxes = axes('Parent', displayPanel, ...
                            'Position', [0.05 0.05 0.90 0.90], ...
                            'Visible', 'on');
                        app.GlobeAxes.XAxis.Visible = 'off';
                        app.GlobeAxes.YAxis.Visible = 'off';
                        app.GlobeAxes.Color = [0.94 0.94 0.94];
                        xlim(app.GlobeAxes, [0 1]);
                        ylim(app.GlobeAxes, [0 1]);
                        text(app.GlobeAxes, 0.5, 0.6, 'Geographic Risk Globe', ...
                            'HorizontalAlignment', 'center', 'FontSize', 24, ...
                            'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
                        text(app.GlobeAxes, 0.5, 0.4, 'Click "Run Analysis" to generate visualization', ...
                            'HorizontalAlignment', 'center', 'FontSize', 14, ...
                            'Color', [0.5 0.5 0.5]);
                    end
                    set(app.GlobeAxes, 'Visible', 'on');
                    app.CurrentTab = 3;
                case 4
                    if isempty(app.NetworkAxes)
                        app.NetworkAxes = axes('Parent', displayPanel, ...
                            'Position', [0.05 0.05 0.90 0.90], ...
                            'Visible', 'on');
                        app.NetworkAxes.XAxis.Visible = 'off';
                        app.NetworkAxes.YAxis.Visible = 'off';
                        app.NetworkAxes.Color = [0.94 0.94 0.94];
                        xlim(app.NetworkAxes, [0 1]);
                        ylim(app.NetworkAxes, [0 1]);
                        text(app.NetworkAxes, 0.5, 0.6, 'Stability Network', ...
                            'HorizontalAlignment', 'center', 'FontSize', 24, ...
                            'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
                        text(app.NetworkAxes, 0.5, 0.4, 'Click "Run Analysis" to generate visualization', ...
                            'HorizontalAlignment', 'center', 'FontSize', 14, ...
                            'Color', [0.5 0.5 0.5]);
                    end
                    set(app.NetworkAxes, 'Visible', 'on');
                    app.CurrentTab = 4;
            end
            
            app.updateVisualization();
        end
        
        function runAnalysis(app)
            fprintf(2, '\n[DEBUG] ========================================\n');
            fprintf(2, '[DEBUG] RUN ANALYSIS BUTTON CLICKED\n');
            fprintf(2, '[DEBUG] ========================================\n');
            
            % Disable controls
            set(app.RunButton, 'Enable', 'off');
            set(app.DemoButton, 'Enable', 'off');
            
            % Get selections
            firmItems = get(app.FirmPopup, 'String');
            firmId = firmItems{get(app.FirmPopup, 'Value')};
            projectItems = get(app.ProjectPopup, 'String');
            projectId = projectItems{get(app.ProjectPopup, 'Value')};
            modeItems = get(app.ModePopup, 'String');
            mode = modeItems{get(app.ModePopup, 'Value')};
            
            fprintf(2, '[DEBUG] Project: %s, Firm: %s, Mode: %s\n', projectId, firmId, mode);
            
            % Update config
            if isempty(app.Config)
                app.Config = struct();
            end
            if ~isfield(app.Config, 'monteCarlo')
                app.Config.monteCarlo = struct();
            end
            app.Config.monteCarlo.nIterations = round(get(app.MCIterationsSlider, 'Value'));
            fprintf(2, '[DEBUG] MC iterations: %d\n', app.Config.monteCarlo.nIterations);
            
            % Update status
            set(app.StatusText, 'String', 'Starting analysis...');
            set(app.ProgressBar, 'BackgroundColor', [0.2 0.6 0.2]);
            drawnow;
            
            try
                fprintf(2, '[DEBUG] Calling runFlorentAnalysis...\n');
                app.Results = runFlorentAnalysis(projectId, firmId, mode, app.Config);
                fprintf(2, '[DEBUG] Analysis complete\n');
                
                % Store results
                app.Data = app.Results.data;
                app.StabilityData = app.Results.stabilityData;
                app.MCResults = app.Results.mcResults;
                
                fprintf(2, '[DEBUG] Results stored\n');
                
                % Update visualization
                app.updateVisualization();
                
                % Success
                if ~isempty(app.StabilityData) && isfield(app.StabilityData, 'nodeIds')
                    nNodes = length(app.StabilityData.nodeIds);
                    avgStability = mean(app.StabilityData.overallStability);
                    set(app.StatusText, 'String', ...
                        sprintf('Analysis complete! Nodes: %d, Avg Stability: %.3f', nNodes, avgStability));
                else
                    set(app.StatusText, 'String', 'Analysis complete!');
                end
                set(app.ProgressBar, 'BackgroundColor', [0.2 0.8 0.2]);
                
            catch ME
                fprintf(2, '[ERROR] Analysis failed: %s\n', ME.message);
                set(app.StatusText, 'String', sprintf('Error: %s', ME.message));
                set(app.ProgressBar, 'BackgroundColor', [0.8 0.2 0.2]);
                errordlg(ME.message, 'Analysis Error');
            end
            
            % Re-enable controls
            set(app.RunButton, 'Enable', 'on');
            set(app.DemoButton, 'Enable', 'on');
            fprintf(2, '[DEBUG] ========================================\n\n');
        end
        
        function updateVisualization(app)
            fprintf(2, '[DEBUG] Updating visualization for tab %d\n', app.CurrentTab);
            
            if isempty(app.StabilityData) || isempty(app.Data)
                fprintf(2, '[DEBUG] No data, showing placeholder\n');
                return;
            end
            
            try
                switch app.CurrentTab
                    case 1
                        if ~isempty(app.MatrixAxes)
                            cla(app.MatrixAxes);
                            plot2x2MatrixWithEllipses(app.StabilityData, app.Data, false, app.MatrixAxes);
                        end
                    case 2
                        if ~isempty(app.LandscapeAxes)
                            cla(app.LandscapeAxes);
                            plot3DRiskLandscape(app.StabilityData, app.Data, false, app.LandscapeAxes);
                        end
                    case 3
                        if ~isempty(app.GlobeAxes)
                            cla(app.GlobeAxes);
                            displayGlobe(app.Data, app.StabilityData, app.Config, app.GlobeAxes);
                        end
                    case 4
                        if ~isempty(app.NetworkAxes)
                            cla(app.NetworkAxes);
                            plotStabilityNetwork(app.Data, app.StabilityData, false, app.NetworkAxes);
                        end
                end
                drawnow;
            catch ME
                fprintf(2, '[ERROR] Visualization failed: %s\n', ME.message);
                set(app.StatusText, 'String', sprintf('Visualization error: %s', ME.message));
            end
        end
        
        function closeApp(app)
            delete(app);
        end
    end
end
