function appExportFunctions(operation, app, varargin)
    % APPEXPORTFUNCTIONS Export functions for App Designer app
    %
    % Usage:
    %   appExportFunctions('currentFigure', app, outputPath)
    %   appExportFunctions('allFigures', app, outputDir)
    %   appExportFunctions('generateReport', app, outputPath)
    %   appExportFunctions('exportData', app, outputPath)
    
    operation = lower(operation);
    
    switch operation
        case 'currentfigure'
            if nargin < 3
                error('exportCurrentFigure requires app and outputPath');
            end
            exportCurrentFigure(app, varargin{1});
            
        case 'allfigures'
            if nargin < 3
                error('exportAllFigures requires app and outputDir');
            end
            exportAllFigures(app, varargin{1});
            
        case 'generatereport'
            if nargin < 3
                error('generateReport requires app and outputPath');
            end
            generateReport(app, varargin{1});
            
        case 'exportdata'
            if nargin < 3
                error('exportData requires app and outputPath');
            end
            exportData(app, varargin{1});
            
        otherwise
            error('Unknown operation: %s', operation);
    end
end

function exportCurrentFigure(app, outputPath)
    % Export current visualization to file
    
    if ~isprop(app, 'TabGroup')
        error('No visualization to export');
    end
    
    selectedTab = app.TabGroup.SelectedTab;
    axesHandle = [];
    
    % Get axes handle based on selected tab
    if isprop(app, 'MatrixTab') && selectedTab == app.MatrixTab
        if isprop(app, 'MatrixAxes')
            axesHandle = app.MatrixAxes;
        end
    elseif isprop(app, 'LandscapeTab') && selectedTab == app.LandscapeTab
        if isprop(app, 'LandscapeAxes')
            axesHandle = app.LandscapeAxes;
        end
    elseif isprop(app, 'GlobeTab') && selectedTab == app.GlobeTab
        if isprop(app, 'GlobeAxes')
            axesHandle = app.GlobeAxes;
        end
    elseif isprop(app, 'NetworkTab') && selectedTab == app.NetworkTab
        if isprop(app, 'NetworkAxes')
            axesHandle = app.NetworkAxes;
        end
    end
    
    if isempty(axesHandle)
        error('Could not find axes for current tab');
    end
    
    % Get parent figure
    fig = axesHandle.Parent;
    
    % Determine file format from extension
    [~, ~, ext] = fileparts(outputPath);
    if isempty(ext)
        outputPath = [outputPath, '.png'];
        ext = '.png';
    end
    
    % Export based on format
    switch lower(ext)
        case {'.png', '.jpg', '.jpeg', '.tif', '.tiff', '.bmp'}
            exportgraphics(fig, outputPath, 'Resolution', 300);
        case '.pdf'
            exportgraphics(fig, outputPath, 'ContentType', 'vector');
        case '.fig'
            savefig(fig, outputPath);
        case '.eps'
            print(fig, outputPath, '-depsc', '-r300');
        otherwise
            warning('Unknown format %s, using PNG', ext);
            outputPath = strrep(outputPath, ext, '.png');
            exportgraphics(fig, outputPath, 'Resolution', 300);
    end
    
    fprintf('Figure exported to: %s\n', outputPath);
end

function exportAllFigures(app, outputDir)
    % Export all visualizations to files
    
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
    end
    
    if isempty(app.StabilityData) || isempty(app.Data)
        error('No analysis results to export');
    end
    
    % Export each visualization
    visualizations = {'2x2matrix', '3dlandscape', 'globe', 'stabilitynetwork'};
    filenames = {'2x2_matrix', '3d_landscape', 'globe', 'stability_network'};
    
    for i = 1:length(visualizations)
        % Create temporary figure
        fig = figure('Visible', 'off');
        ax = axes('Parent', fig);
        
        % Generate visualization
        appIntegration('updateVisualization', app, visualizations{i}, app.Data, app.StabilityData);
        
        % Export
        outputPath = fullfile(outputDir, [filenames{i}, '.png']);
        exportgraphics(fig, outputPath, 'Resolution', 300);
        
        % Close figure
        close(fig);
    end
    
    fprintf('All figures exported to: %s\n', outputDir);
end

function generateReport(app, outputPath)
    % Generate PDF report with all visualizations and findings
    
    if isempty(app.StabilityData) || isempty(app.Data)
        error('No analysis results to report');
    end
    
    % Create report using existing function if available
    if exist('createRiskDashboard', 'file')
        try
            % Use existing dashboard creation
            dashboard = createRiskDashboard(app.Data, app.StabilityData, app.Config);
            
            % Export dashboard to PDF
            if ishandle(dashboard)
                [reportDir, reportName] = fileparts(outputPath);
                if isempty(reportDir)
                    reportDir = fullfile(pwd, 'MATLAB', 'Reports');
                end
                if ~exist(reportDir, 'dir')
                    mkdir(reportDir);
                end
                
                pdfPath = fullfile(reportDir, [reportName, '.pdf']);
                exportgraphics(dashboard, pdfPath, 'ContentType', 'vector');
                fprintf('Report generated: %s\n', pdfPath);
            end
        catch ME
            warning('Dashboard creation failed: %s', ME.message);
            % Fall back to simple report
            generateSimpleReport(app, outputPath);
        end
    else
        generateSimpleReport(app, outputPath);
    end
end

function generateSimpleReport(app, outputPath)
    % Generate simple text/PDF report
    
    [reportDir, reportName] = fileparts(outputPath);
    if isempty(reportDir)
        reportDir = fullfile(pwd, 'MATLAB', 'Reports');
    end
    if ~exist(reportDir, 'dir')
        mkdir(reportDir);
    end
    
    % Generate text report
    if exist('generateTextReport', 'file')
        textPath = fullfile(reportDir, [reportName, '.txt']);
        generateTextReport(app.Data, app.StabilityData, app.Config, textPath);
        fprintf('Text report generated: %s\n', textPath);
    end
end

function exportData(app, outputPath)
    % Export analysis data to MAT or CSV
    
    if isempty(app.StabilityData) || isempty(app.Data)
        error('No data to export');
    end
    
    [~, ~, ext] = fileparts(outputPath);
    
    switch lower(ext)
        case '.mat'
            % Export as MAT file
            data = struct();
            data.projectId = app.Data.projectId;
            data.firmId = app.Data.firmId;
            data.stabilityData = app.StabilityData;
            data.meanScores = app.StabilityData.meanScores;
            data.nodeIds = app.StabilityData.nodeIds;
            data.overallStability = app.StabilityData.overallStability;
            
            save(outputPath, 'data', '-v7.3');
            fprintf('Data exported to MAT file: %s\n', outputPath);
            
        case '.csv'
            % Export as CSV
            if isprop(app, 'ResultsTable') && ~isempty(app.ResultsTable.Data)
                % Use table data if available
                writetable(app.ResultsTable.Data, outputPath);
            else
                % Create table from stability data
                nNodes = length(app.StabilityData.nodeIds);
                tableData = table(...
                    app.StabilityData.nodeIds(:), ...
                    app.StabilityData.meanScores.risk(:), ...
                    app.StabilityData.meanScores.influence(:), ...
                    app.StabilityData.overallStability(:), ...
                    'VariableNames', {'NodeID', 'Risk', 'Influence', 'Stability'});
                writetable(tableData, outputPath);
            end
            fprintf('Data exported to CSV: %s\n', outputPath);
            
        otherwise
            error('Unsupported export format. Use .mat or .csv');
    end
end

