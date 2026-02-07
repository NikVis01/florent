% CREATERISKDASHBOARD Creates comprehensive risk analysis dashboard
%
% Combines multiple visualizations in tiled layout
% Sections: MC summary stats, key visualizations, stability rankings
% Export: PDF report for stakeholders
%
% Usage:
%   createRiskDashboard()
%   createRiskDashboard(data, stabilityData, mcResults)

function createRiskDashboard(data, stabilityData, mcResults)
    % If no inputs, try to load from files
    if nargin < 1
        dataDir = fullfile(pwd, 'MATLAB', 'Data');
        
        % Try to load data
        if exist(fullfile(dataDir, 'stabilityData.mat'), 'file')
            load(fullfile(dataDir, 'stabilityData.mat'), 'stabilityData');
        else
            error('stabilityData.mat not found. Run MC simulations first.');
        end
        
        % Try to load MC results
        if exist(fullfile(dataDir, 'mc_parameterSensitivity.mat'), 'file')
            load(fullfile(dataDir, 'mc_parameterSensitivity.mat'), 'results');
            mcResults.parameterSensitivity = results.parameterSensitivity;
        end
        
        % Load base data (or create mock)
        data = getRiskData();
    end
    
    fprintf('Creating comprehensive risk analysis dashboard...\n');
    
    % Create figure
    fig = figure('Position', [50, 50, 1600, 1000], 'Name', 'Risk Analysis Dashboard');
    
    % Create tiled layout
    t = tiledlayout(3, 3, 'TileSpacing', 'tight', 'Padding', 'compact');
    
    % Top row: Summary statistics
    nexttile([1, 3]);
    createSummaryStats(stabilityData);
    
    % Middle row: Key visualizations
    % 2x2 Matrix
    nexttile;
    plot2x2MatrixWithEllipses(stabilityData, data, false);
    title('2x2 Risk Matrix', 'FontSize', 12, 'FontWeight', 'bold');
    
    % 3D Landscape
    nexttile;
    plot3DRiskLandscape(stabilityData, data, false);
    title('3D Risk Landscape', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Stability Network
    nexttile;
    plotStabilityNetwork(data, stabilityData, false);
    title('Stability Network', 'FontSize', 12, 'FontWeight', 'bold');
    
    % Bottom row: Additional visualizations
    % Parameter Sensitivity
    if isfield(mcResults, 'parameterSensitivity')
        nexttile;
        plotParameterSensitivity(mcResults, false);
        title('Parameter Sensitivity', 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    % MC Convergence
    if isfield(mcResults, 'parameterSensitivity')
        nexttile;
        plotMCConvergence(mcResults, false);
        title('MC Convergence', 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    % Stability Rankings
    nexttile;
    createStabilityRankings(stabilityData);
    
    % Overall title
    sgtitle('Comprehensive Risk Analysis Dashboard', ...
        'FontSize', 18, 'FontWeight', 'bold');
    
    % Save figure
    figDir = fullfile(pwd, 'MATLAB', 'Figures');
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    savefig(fig, fullfile(figDir, 'risk_analysis_dashboard.fig'));
    fprintf('Dashboard saved to: risk_analysis_dashboard.fig\n');
    
    % Export to PDF with multi-page support
    reportDir = fullfile(pwd, 'MATLAB', 'Reports');
    if ~exist(reportDir, 'dir')
        mkdir(reportDir);
    end
    
    % Generate text report first (executive summary)
    try
        if isfield(data, 'projectId') && isfield(data, 'firmId')
            generateTextReport(data, stabilityData, config);
        end
    catch
        warning('Text report generation failed');
    end
    
    % Export main dashboard PDF
    try
        pdfFile = fullfile(reportDir, 'risk_analysis_dashboard.pdf');
        exportgraphics(fig, pdfFile, ...
            'ContentType', 'vector', 'BackgroundColor', 'white', ...
            'Resolution', config.visualization.dpi);
        fprintf('PDF report saved to: risk_analysis_dashboard.pdf\n');
    catch
        warning('PDF export failed. Figure saved as .fig only.');
    end
    
    % Export individual figure PDFs if configured
    if isfield(config, 'report') && config.report.exportPDF
        try
            figDir = config.paths.figuresDir;
            if exist(figDir, 'dir')
                % Export key figures as separate PDFs
                keyFigs = {'2x2_matrix_confidence', '3d_risk_landscape', ...
                    'stability_network', 'parameter_sensitivity_heatmap'};
                for i = 1:length(keyFigs)
                    figFile = fullfile(figDir, [keyFigs{i}, '.fig']);
                    if exist(figFile, 'file')
                        try
                            figHandle = openfig(figFile, 'invisible');
                            pdfFile = fullfile(reportDir, [keyFigs{i}, '.pdf']);
                            exportgraphics(figHandle, pdfFile, ...
                                'ContentType', 'vector', 'BackgroundColor', 'white', ...
                                'Resolution', config.visualization.dpi);
                            close(figHandle);
                        catch
                            % Skip if export fails
                        end
                    end
                end
            end
        catch
            % Ignore individual figure export errors
        end
    end
    
    fprintf('Dashboard creation completed\n');
end

function createSummaryStats(stabilityData)
    % Create summary statistics panel
    
    cla;
    axis off;
    
    % Calculate statistics
    nNodes = length(stabilityData.nodeIds);
    avgStability = mean(stabilityData.overallStability);
    avgRisk = mean(stabilityData.meanScores.risk);
    avgInfluence = mean(stabilityData.meanScores.influence);
    
    % Count nodes by quadrant
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    quadrants = classifyQuadrant(risk, influence);
    
    q1Count = sum(strcmp(quadrants, 'Q1'));
    q2Count = sum(strcmp(quadrants, 'Q2'));
    q3Count = sum(strcmp(quadrants, 'Q3'));
    q4Count = sum(strcmp(quadrants, 'Q4'));
    
    % Count unstable nodes
    unstableCount = sum(stabilityData.overallStability < 0.5);
    
    % Create text summary
    text(0.1, 0.9, 'Monte Carlo Summary Statistics', ...
        'FontSize', 16, 'FontWeight', 'bold', 'Units', 'normalized');
    
    statsText = {
        sprintf('Total Nodes: %d', nNodes);
        sprintf('Average Stability: %.3f', avgStability);
        sprintf('Average Risk: %.3f', avgRisk);
        sprintf('Average Influence: %.3f', avgInfluence);
        '';
        'Quadrant Distribution:';
        sprintf('  Q1 (Mitigate): %d (%.1f%%)', q1Count, 100*q1Count/nNodes);
        sprintf('  Q2 (Automate): %d (%.1f%%)', q2Count, 100*q2Count/nNodes);
        sprintf('  Q3 (Contingency): %d (%.1f%%)', q3Count, 100*q3Count/nNodes);
        sprintf('  Q4 (Delegate): %d (%.1f%%)', q4Count, 100*q4Count/nNodes);
        '';
        sprintf('Unstable Nodes (< 0.5 stability): %d (%.1f%%)', ...
            unstableCount, 100*unstableCount/nNodes);
    };
    
    text(0.1, 0.7, statsText, 'FontSize', 11, 'Units', 'normalized', ...
        'VerticalAlignment', 'top', 'FontName', 'Courier');
end

function createStabilityRankings(stabilityData)
    % Create stability rankings bar chart
    
    % Get top and bottom nodes
    [~, rank] = sort(stabilityData.overallStability, 'descend');
    nShow = min(10, length(rank));
    
    topNodes = rank(1:nShow);
    bottomNodes = rank(end-nShow+1:end);
    
    % Create bar chart
    barData = [stabilityData.overallStability(topNodes); ...
        stabilityData.overallStability(bottomNodes)];
    
    bar(barData, 'FaceColor', [0.3, 0.6, 0.9]);
    
    % Labels
    nodeLabels = [stabilityData.nodeIds(topNodes); ...
        stabilityData.nodeIds(bottomNodes)];
    set(gca, 'XTick', 1:length(barData));
    set(gca, 'XTickLabel', nodeLabels);
    set(gca, 'XTickLabelRotation', 45);
    
    ylabel('Stability Score', 'FontSize', 10, 'FontWeight', 'bold');
    title('Top & Bottom Stability Rankings', 'FontSize', 12, 'FontWeight', 'bold');
    grid on;
    
    % Add dividing line
    hold on;
    plot([nShow+0.5, nShow+0.5], ylim, 'r--', 'LineWidth', 2);
    text(nShow/2, max(ylim)*0.95, 'Top 10', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'Color', 'blue');
    text(nShow*1.5, max(ylim)*0.95, 'Bottom 10', 'HorizontalAlignment', 'center', ...
        'FontWeight', 'bold', 'Color', 'red');
    hold off;
end

