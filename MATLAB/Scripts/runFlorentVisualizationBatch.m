% RUNFLORENTVISUALIZATIONBATCH Batch visualization script for aggregate data
%
% Creates comprehensive visualizations from batch processing results
% All visualizations are adapted to handle aggregate data across multiple projects
%
% This function is automatically called by batchProcessProjects().
%
% Usage:
%   batchProcessProjects()  % Automatically calls this function
%
%   OR if you need to call it separately (e.g., after loading saved results):
%   load('path/to/allResults.mat', 'allResults');
%   runFlorentVisualizationBatch(allResults);

function runFlorentVisualizationBatch(allResults, config)
    % RUNFLORENTVISUALIZATIONBATCH Create visualizations from batch processing results
    %
    % Creates comprehensive visualizations from batch processing results,
    % showing aggregate patterns across all projects.
    %
    % This function is automatically called by batchProcessProjects() at the end
    % of batch processing. You typically don't need to call this directly.
    %
    % Usage:
    %   batchProcessProjects()  % This will automatically call this function
    %
    %   OR if you have saved allResults from a previous run:
    %   load('allResults.mat', 'allResults');
    %   runFlorentVisualizationBatch(allResults);
    %
    % Arguments:
    %   allResults - Structure from batchProcessProjects containing:
    %                .projects - Cell array of project filenames
    %                .analyses - Cell array of analysis results
    %                .stabilityData - Cell array of stability data
    %                .mcResults - Cell array of MC results
    %                .summaries - Cell array of summary statistics
    %   config     - Configuration structure (optional, will load default if not provided)
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT: BATCH RISK ANALYSIS\n');
    fprintf('  Portfolio Visualization & Analysis\n');
    fprintf('========================================\n');
    
    % Validate input
    if nargin < 1 || isempty(allResults)
        error('allResults is required. Usage: runFlorentVisualizationBatch(allResults, [config])');
    end
    
    % Load config if not provided
    if nargin < 2 || isempty(config)
        try
            config = loadFlorentConfig('test');
        catch
            config = struct();
            config.paths = struct();
            config.paths.figuresDir = fullfile(pwd, 'MATLAB', 'Figures', 'batch');
        end
    end
    
    % Filter out failed projects
    validIndices = [];
    for i = 1:length(allResults.analyses)
        if ~isempty(allResults.analyses{i})
            validIndices(end+1) = i;
        end
    end
    
    if isempty(validIndices)
        error('No valid projects to visualize');
    end
    
    nValid = length(validIndices);
    fprintf('Processing %d valid projects for visualization\n', nValid);
    fprintf('========================================\n\n');
    
    % Create figures directory
    figDir = fullfile(pwd, 'MATLAB', 'Figures', 'batch');
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    
    % Initialize
    try
        initializeFlorent(false);
        fprintf('Paths initialized\n');
    catch ME
        warning('Path init: %s', ME.message);
    end
    
    fprintf('\nCreating batch visualizations...\n\n');
    
    % ========================================
    % MAIN AGGREGATE VISUALIZATIONS
    % ========================================
    
    % 1. Aggregate Project Scores Distribution
    fprintf('  [1/8] Project Scores Distribution\n');
    try
        scores = [];
        for i = validIndices
            if isfield(allResults.summaries{i}, 'aggregateProjectScore')
                scores(end+1) = allResults.summaries{i}.aggregateProjectScore;
            end
        end
        
        if ~isempty(scores)
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Risk Assessment Score Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            h = histogram(ax, scores, 20, ...
                'FaceColor', [0.2, 0.5, 0.8], ...
                'EdgeColor', [0.1, 0.3, 0.6], ...
                'LineWidth', 1.5, ...
                'FaceAlpha', 0.85);
            
            hold(ax, 'on');
            meanScore = mean(scores);
            yLim = ylim(ax);
            plot(ax, [meanScore, meanScore], yLim, 'r--', 'LineWidth', 2.5, ...
                'DisplayName', sprintf('Mean: %.3f', meanScore));
            hold(ax, 'off');
            
            xlabel(ax, 'Risk Assessment Score', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            ylabel(ax, 'Number of Projects', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Risk Assessment Score Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.85, 0.85, 0.85];
            ax.GridAlpha = 0.6;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            
            legend(ax, 'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            fprintf('    [OK] Created\n');
        end
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 2. Risk vs Influence Scatter (all projects)
    fprintf('  [2/8] Risk vs Influence Scatter\n');
    try
        allRisk = [];
        allInfluence = [];
        projectLabels = {};
        projectScores = [];
        
        for i = validIndices
            if isfield(allResults.summaries{i}, 'avgRisk') && ...
               isfield(allResults.summaries{i}, 'avgInfluence')
                allRisk(end+1) = allResults.summaries{i}.avgRisk;
                allInfluence(end+1) = allResults.summaries{i}.avgInfluence;
                projectLabels{end+1} = allResults.projects{i};
                if isfield(allResults.summaries{i}, 'aggregateProjectScore')
                    projectScores(end+1) = allResults.summaries{i}.aggregateProjectScore;
                else
                    projectScores(end+1) = 0.5;
                end
            end
        end
        
        if ~isempty(allRisk)
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Risk vs Influence Analysis');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            hold(ax, 'on');
            scatter(ax, allRisk, allInfluence, 150, projectScores, 'filled', ...
                'MarkerFaceAlpha', 0.75, 'MarkerEdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 1.5, 'DisplayName', 'Projects');
            colormap(ax, 'viridis');
            c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial', 'Location', 'eastoutside');
            c.Label.String = 'Project Risk Score';
            c.Label.FontSize = 13;
            c.Label.FontWeight = 'bold';
            c.Label.Color = [0.2, 0.2, 0.2];
            c.Color = [0.2, 0.2, 0.2];
            
            plot(ax, [0.5, 0.5], [0, 1], '--', 'LineWidth', 2.5, ...
                'Color', [0.6, 0.6, 0.6], 'DisplayName', 'Risk Threshold (0.5)');
            plot(ax, [0, 1], [0.5, 0.5], '--', 'LineWidth', 2.5, ...
                'Color', [0.6, 0.6, 0.6], 'DisplayName', 'Influence Threshold (0.5)');
            
            % Add quadrant labels
            text(ax, 0.25, 0.75, 'Q1: High Risk\nHigh Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            text(ax, 0.75, 0.75, 'Q2: High Risk\nLow Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            text(ax, 0.25, 0.25, 'Q3: Low Risk\nHigh Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            text(ax, 0.75, 0.25, 'Q4: Low Risk\nLow Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            
            % Add project labels with values
            for i = 1:length(allRisk)
                labelText = projectLabels{i};
                labelText = strrep(labelText, '_', ' ');
                labelText = strrep(labelText, '.json', '');
                labelText = strrep(labelText, 'project ', 'P');
                % Add risk and influence values to label
                valueText = sprintf('%s\n(R:%.2f, I:%.2f)', labelText, allRisk(i), allInfluence(i));
                text(ax, allRisk(i), allInfluence(i) + 0.04, valueText, ...
                    'FontSize', 9, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                    'Color', [0.1, 0.1, 0.1], 'HorizontalAlignment', 'center', ...
                    'VerticalAlignment', 'bottom', ...
                    'BackgroundColor', [1, 1, 1, 0.9], 'EdgeColor', [0.3, 0.3, 0.3], ...
                    'LineWidth', 1.5, 'Margin', 3);
            end
            hold(ax, 'off');
            
            % Set axis labels - MAKE THEM BIG AND BOLD
            xlabel(ax, 'Average Risk Level', 'FontSize', 16, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.1, 0.1, 0.1]);
            ylabel(ax, 'Average Influence Score', 'FontSize', 16, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.1, 0.1, 0.1]);
            title(ax, 'Risk vs Influence: Portfolio Analysis', ...
                'FontSize', 20, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.05, 0.05, 0.05]);
            subtitle(ax, 'Quadrant-based risk classification across all projects', ...
                'FontSize', 13, 'FontName', 'Arial', 'FontWeight', 'normal', ...
                'Color', [0.3, 0.3, 0.3]);
            
            % Set axis properties - MAKE SURE LABELS ARE VISIBLE
            ax.XColor = [0.2, 0.2, 0.2];
            ax.YColor = [0.2, 0.2, 0.2];
            ax.XAxis.FontSize = 12;
            ax.YAxis.FontSize = 12;
            ax.XAxis.FontWeight = 'bold';
            ax.YAxis.FontWeight = 'bold';
            ax.GridColor = [0.9, 0.9, 0.9];
            ax.GridAlpha = 0.8;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 2;
            xlim(ax, [0, 1]);
            ylim(ax, [0, 1]);
            
            % Add tick labels with values
            ax.XTick = [0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0];
            ax.XTickLabel = {'0.0', '0.2', '0.4', '0.5', '0.6', '0.8', '1.0'};
            ax.YTick = [0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0];
            ax.YTickLabel = {'0.0', '0.2', '0.4', '0.5', '0.6', '0.8', '1.0'};
            
            % Add comprehensive legend
            legend(ax, {'Projects', 'Risk Threshold (0.5)', 'Influence Threshold (0.5)'}, ...
                'Location', 'best', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'EdgeColor', [0.5, 0.5, 0.5], 'Box', 'on', 'LineWidth', 1.5, ...
                'BackgroundColor', [1, 1, 1, 0.95], 'TextColor', [0.1, 0.1, 0.1]);
            
            % Add axis annotations
            text(ax, 0.5, -0.08, '← Low Risk | High Risk →', ...
                'Units', 'normalized', 'FontSize', 11, 'FontName', 'Arial', ...
                'FontWeight', 'bold', 'Color', [0.3, 0.3, 0.3], ...
                'HorizontalAlignment', 'center');
            text(ax, -0.12, 0.5, '← Low Influence', ...
                'Units', 'normalized', 'FontSize', 11, 'FontName', 'Arial', ...
                'FontWeight', 'bold', 'Color', [0.3, 0.3, 0.3], ...
                'HorizontalAlignment', 'center', 'Rotation', 90);
            text(ax, -0.12, 0.95, 'High Influence →', ...
                'Units', 'normalized', 'FontSize', 11, 'FontName', 'Arial', ...
                'FontWeight', 'bold', 'Color', [0.3, 0.3, 0.3], ...
                'HorizontalAlignment', 'center', 'Rotation', 90);
            
            fprintf('    [OK] Created\n');
        end
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 3. Risk Level Distribution
    fprintf('  [3/8] Risk Level Distribution\n');
    try
        highRiskCount = 0;
        mediumRiskCount = 0;
        lowRiskCount = 0;
        
        for i = validIndices
            if isfield(allResults.summaries{i}, 'avgRisk')
                avgRisk = allResults.summaries{i}.avgRisk;
                if avgRisk >= 0.6
                    highRiskCount = highRiskCount + 1;
                elseif avgRisk >= 0.3
                    mediumRiskCount = mediumRiskCount + 1;
                else
                    lowRiskCount = lowRiskCount + 1;
                end
            end
        end
        
        if highRiskCount + mediumRiskCount + lowRiskCount > 0
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Risk Level Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            categories = {'High Risk\n(≥0.6)', 'Medium Risk\n(0.3-0.6)', 'Low Risk\n(<0.3)'};
            counts = [highRiskCount, mediumRiskCount, lowRiskCount];
            
            colors = [0.85, 0.2, 0.2; 1.0, 0.65, 0.0; 0.2, 0.7, 0.3];
            
            b = bar(ax, counts, 'FaceColor', 'flat', 'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2, 'BarWidth', 0.6);
            b.CData = colors;
            
            for i = 1:length(counts)
                if counts(i) > 0
                    text(ax, i, counts(i) + 0.5, num2str(counts(i)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 13, ...
                        'FontWeight', 'bold', 'FontName', 'Arial', ...
                        'Color', [0.2, 0.2, 0.2]);
                end
            end
            
            set(ax, 'XTickLabel', categories, 'XTickLabelRotation', 0);
            xlabel(ax, 'Risk Category', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            ylabel(ax, 'Number of Projects', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Risk Level Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.9, 0.9, 0.9];
            ax.GridAlpha = 0.8;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            ylim(ax, [0, max(counts) * 1.2]);
            
            legend(ax, {'High Risk', 'Medium Risk', 'Low Risk'}, ...
                'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            fprintf('    [OK] Created\n');
        end
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 4. Quadrant Distribution Comparison
    fprintf('  [4/8] Quadrant Distribution Comparison\n');
    try
        q1Total = 0; q2Total = 0; q3Total = 0; q4Total = 0;
        
        for i = validIndices
            if isfield(allResults.summaries{i}, 'q1Count')
                q1Total = q1Total + allResults.summaries{i}.q1Count;
                q2Total = q2Total + allResults.summaries{i}.q2Count;
                q3Total = q3Total + allResults.summaries{i}.q3Count;
                q4Total = q4Total + allResults.summaries{i}.q4Count;
            end
        end
        
        if q1Total + q2Total + q3Total + q4Total > 0
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Quadrant Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            categories = {'Q1: Mitigate\n(High Risk/High Influence)', ...
                         'Q2: Automate\n(High Risk/Low Influence)', ...
                         'Q3: Contingency\n(Low Risk/High Influence)', ...
                         'Q4: Delegate\n(Low Risk/Low Influence)'};
            counts = [q1Total, q2Total, q3Total, q4Total];
            
            colors = [0.9, 0.2, 0.2; 1.0, 0.5, 0.0; 0.2, 0.6, 0.9; 0.5, 0.5, 0.5];
            
            b = bar(ax, counts, 'FaceColor', 'flat', 'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2, 'BarWidth', 0.7);
            b.CData = colors;
            
            for i = 1:length(counts)
                if counts(i) > 0
                    text(ax, i, counts(i) + max(counts)*0.02, num2str(counts(i)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 13, ...
                        'FontWeight', 'bold', 'FontName', 'Arial', ...
                        'Color', [0.2, 0.2, 0.2]);
                end
            end
            
            set(ax, 'XTickLabel', categories, 'XTickLabelRotation', 0);
            xlabel(ax, 'Quadrant Category', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            ylabel(ax, 'Total Nodes Across All Projects', 'FontSize', 15, ...
                'FontWeight', 'bold', 'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Aggregate Quadrant Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.9, 0.9, 0.9];
            ax.GridAlpha = 0.8;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            ylim(ax, [0, max(counts) * 1.15]);
            
            legend(ax, {'Q1: Mitigate', 'Q2: Automate', 'Q3: Contingency', 'Q4: Delegate'}, ...
                'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            fprintf('    [OK] Created\n');
        end
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 5. Critical Failure Likelihood Distribution
    fprintf('  [5/8] Critical Failure Likelihood Distribution\n');
    try
        failureLikelihoods = [];
        for i = validIndices
            if isfield(allResults.summaries{i}, 'criticalFailureLikelihood')
                failureLikelihoods(end+1) = allResults.summaries{i}.criticalFailureLikelihood;
            end
        end
        
        if ~isempty(failureLikelihoods)
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Critical Failure Likelihood Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            h = histogram(ax, failureLikelihoods, 20, ...
                'FaceColor', [0.85, 0.25, 0.25], ...
                'EdgeColor', [0.6, 0.1, 0.1], ...
                'LineWidth', 1.5, ...
                'FaceAlpha', 0.85);
            
            hold(ax, 'on');
            meanLikelihood = mean(failureLikelihoods);
            medianLikelihood = median(failureLikelihoods);
            yLim = ylim(ax);
            plot(ax, [meanLikelihood, meanLikelihood], yLim, 'r--', 'LineWidth', 2.5, ...
                'DisplayName', sprintf('Mean: %.3f', meanLikelihood));
            plot(ax, [medianLikelihood, medianLikelihood], yLim, 'b--', 'LineWidth', 2.5, ...
                'DisplayName', sprintf('Median: %.3f', medianLikelihood));
            hold(ax, 'off');
            
            xlabel(ax, 'Critical Failure Likelihood', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            ylabel(ax, 'Number of Projects', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Critical Failure Likelihood Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.85, 0.85, 0.85];
            ax.GridAlpha = 0.6;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            
            legend(ax, 'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            fprintf('    [OK] Created\n');
        end
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 6. 3D Risk Landscape
    fprintf('  [6/8] 3D Risk Landscape\n');
    try
        % Call the function from batchProcessProjects.m
        plot3DRiskLandscape(allResults, validIndices, figDir);
        fprintf('    [OK] Created\n');
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 7. Monte Carlo Uncertainty Fan
    fprintf('  [7/8] Monte Carlo Uncertainty Fan\n');
    try
        % Call the function from batchProcessProjects.m
        plotMCUncertaintyFan(allResults, validIndices, figDir);
        fprintf('    [OK] Created\n');
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 8. Parameter Sensitivity Heatmap
    fprintf('  [8/9] Parameter Sensitivity Heatmap\n');
    try
        % Call the function from batchProcessProjects.m
        plotParameterSensitivityAggregate(allResults, validIndices, figDir);
        fprintf('    [OK] Created\n');
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    % 9. Stability Network (Aggregate)
    fprintf('  [9/9] Stability Network (Aggregate)\n');
    try
        plotStabilityNetworkAggregate(allResults, validIndices, figDir);
        fprintf('    [OK] Created\n');
    catch ME
        warning('Failed: %s', ME.message);
    end
    
    fprintf('\n========================================\n');
    fprintf('  BATCH VISUALIZATIONS COMPLETE\n');
    fprintf('========================================\n');
    fprintf('All visualizations displayed in separate figure windows\n');
    fprintf('Figures saved to: %s\n', figDir);
    fprintf('Close figures when done\n');
    fprintf('========================================\n\n');
    
    % Display summary
    fprintf('\n=== Batch Analysis Summary ===\n');
    fprintf('Total Projects Processed: %d\n', length(allResults.projects));
    fprintf('Successful: %d\n', nValid);
    fprintf('Failed: %d\n', length(allResults.projects) - nValid);
    fprintf('\n');
    
    % Aggregate statistics
    totalNodes = 0;
    allRisks = [];
    allInfluences = [];
    allScores = [];
    
    for i = validIndices
        s = allResults.summaries{i};
        if isfield(s, 'nNodes')
            totalNodes = totalNodes + s.nNodes;
        end
        if isfield(s, 'avgRisk')
            allRisks(end+1) = s.avgRisk;
        end
        if isfield(s, 'avgInfluence')
            allInfluences(end+1) = s.avgInfluence;
        end
        if isfield(s, 'aggregateProjectScore')
            allScores(end+1) = s.aggregateProjectScore;
        end
    end
    
    if ~isempty(allRisks)
        fprintf('Average Risk (across projects): %.3f\n', mean(allRisks));
        fprintf('Risk Range: [%.3f, %.3f]\n', min(allRisks), max(allRisks));
    end
    if ~isempty(allInfluences)
        fprintf('Average Influence (across projects): %.3f\n', mean(allInfluences));
        fprintf('Influence Range: [%.3f, %.3f]\n', min(allInfluences), max(allInfluences));
    end
    if ~isempty(allScores)
        fprintf('Average Project Score: %.3f\n', mean(allScores));
        fprintf('Score Range: [%.3f, %.3f]\n', min(allScores), max(allScores));
    end
    if totalNodes > 0
        fprintf('Total Nodes (all projects): %d\n', totalNodes);
        fprintf('Average Nodes per Project: %.1f\n', totalNodes / nValid);
    end
    
    fprintf('\n');
end

function plotStabilityNetworkAggregate(allResults, validIndices, figDir)
    % PLOTSTABILITYNETWORKAGGREGATE Creates aggregate stability network visualization
    %
    % Aggregates network data across all projects to show:
    % - Node size = aggregate stability score
    % - Node color = most common quadrant across projects
    % - Edge thickness = aggregate dependency strength
    % - Highlights unstable nodes across the portfolio
    
    nValid = length(validIndices);
    if nValid < 1
        warning('No valid projects for stability network visualization');
        return;
    end
    
    % Collect all nodes and their aggregate properties
    allNodeIds = {};
    nodeStabilityMap = containers.Map();
    nodeRiskMap = containers.Map();
    nodeInfluenceMap = containers.Map();
    nodeQuadrantCounts = containers.Map();
    allAdjMatrices = {};
    
    % Process each project
    for idx = 1:nValid
        i = validIndices(idx);
        if ~isempty(allResults.analyses{i})
            analysis = allResults.analyses{i};
            
            % Get node IDs
            nodeIds = openapiHelpers('getNodeIds', analysis);
            if isempty(nodeIds)
                continue;
            end
            
            % Get risk and influence
            risk = openapiHelpers('getAllRiskLevels', analysis);
            influence = openapiHelpers('getAllInfluenceScores', analysis);
            
            % Ensure risk and influence match nodeIds length
            nNodesThis = length(nodeIds);
            if length(risk) ~= nNodesThis
                if length(risk) > nNodesThis
                    risk = risk(1:nNodesThis);
                else
                    risk = [risk; zeros(nNodesThis - length(risk), 1)];
                end
            end
            if length(influence) ~= nNodesThis
                if length(influence) > nNodesThis
                    influence = influence(1:nNodesThis);
                else
                    influence = [influence; zeros(nNodesThis - length(influence), 1)];
                end
            end
            
            % Get adjacency matrix
            adjMatrix = openapiHelpers('getAdjacencyMatrix', analysis);
            if isempty(adjMatrix)
                adjMatrix = zeros(nNodesThis, nNodesThis);
            elseif size(adjMatrix, 1) ~= nNodesThis || size(adjMatrix, 2) ~= nNodesThis
                % Resize adjacency matrix to match node count
                adjMatrix = zeros(nNodesThis, nNodesThis);
            end
            
            % Get stability data if available
            stability = [];
            if ~isempty(allResults.stabilityData{i}) && ...
               isfield(allResults.stabilityData{i}, 'overallStability')
                stability = allResults.stabilityData{i}.overallStability;
                if length(stability) ~= nNodesThis
                    if length(stability) > nNodesThis
                        stability = stability(1:nNodesThis);
                    else
                        stability = [stability; zeros(nNodesThis - length(stability), 1)];
                    end
                end
            else
                % Use risk as proxy: lower risk = higher stability
                stability = 1 - risk;
            end
            
            % Aggregate data per node
            for j = 1:nNodesThis
                nodeId = char(string(nodeIds(j)));
                
                % Track node IDs
                if ~ismember(nodeId, allNodeIds)
                    allNodeIds{end+1} = nodeId;
                end
                
                % Aggregate stability (average)
                if isKey(nodeStabilityMap, nodeId)
                    nodeStabilityMap(nodeId) = [nodeStabilityMap(nodeId), stability(j)];
                else
                    nodeStabilityMap(nodeId) = stability(j);
                end
                
                % Aggregate risk (average)
                if isKey(nodeRiskMap, nodeId)
                    nodeRiskMap(nodeId) = [nodeRiskMap(nodeId), risk(j)];
                else
                    nodeRiskMap(nodeId) = risk(j);
                end
                
                % Aggregate influence (average)
                if isKey(nodeInfluenceMap, nodeId)
                    nodeInfluenceMap(nodeId) = [nodeInfluenceMap(nodeId), influence(j)];
                else
                    nodeInfluenceMap(nodeId) = influence(j);
                end
                
                % Track quadrant (use existing classifyQuadrant function)
                quad = classifyQuadrant(risk(j), influence(j));
                if ischar(quad)
                    quadStr = quad;
                else
                    quadStr = quad{1};
                end
                quadKey = sprintf('%s_%s', nodeId, quadStr);
                if isKey(nodeQuadrantCounts, quadKey)
                    nodeQuadrantCounts(quadKey) = nodeQuadrantCounts(quadKey) + 1;
                else
                    nodeQuadrantCounts(quadKey) = 1;
                end
            end
            
            % Store adjacency matrix
            allAdjMatrices{end+1} = adjMatrix;
        end
    end
    
    if isempty(allNodeIds)
        warning('No nodes found for stability network visualization');
        return;
    end
    
    % Calculate aggregate properties
    nNodes = length(allNodeIds);
    aggregateStability = zeros(nNodes, 1);
    aggregateRisk = zeros(nNodes, 1);
    aggregateInfluence = zeros(nNodes, 1);
    aggregateQuadrants = cell(nNodes, 1);
    
    for i = 1:nNodes
        nodeId = allNodeIds{i};
        aggregateStability(i) = mean(nodeStabilityMap(nodeId));
        aggregateRisk(i) = mean(nodeRiskMap(nodeId));
        aggregateInfluence(i) = mean(nodeInfluenceMap(nodeId));
        
        % Determine most common quadrant
        quadCounts = containers.Map();
        for q = {'Q1', 'Q2', 'Q3', 'Q4'}
            quadKey = sprintf('%s_%s', nodeId, q{1});
            if isKey(nodeQuadrantCounts, quadKey)
                quadCounts(q{1}) = nodeQuadrantCounts(quadKey);
            else
                quadCounts(q{1}) = 0;
            end
        end
        [~, maxQuad] = max(cell2mat(quadCounts.values));
        quadKeys = quadCounts.keys;
        aggregateQuadrants{i} = quadKeys{maxQuad};
    end
    
    % Build aggregate adjacency matrix (average across projects)
    aggregateAdj = zeros(nNodes, nNodes);
    adjCount = 0;
    for adjIdx = 1:length(allAdjMatrices)
        adj = allAdjMatrices{adjIdx};
        if size(adj, 1) == nNodes && size(adj, 2) == nNodes
            aggregateAdj = aggregateAdj + adj;
            adjCount = adjCount + 1;
        end
    end
    if adjCount > 0
        aggregateAdj = aggregateAdj / adjCount;
    end
    
    % Create figure with modern styling
    fig = figure('Position', [100, 100, 1600, 1200], ...
        'Color', 'white', 'Name', 'Stability Network - Aggregate');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    
    % Create graph object
    try
        G = digraph(aggregateAdj, allNodeIds);
    catch
        % Fallback to undirected if digraph fails
        G = graph(aggregateAdj, allNodeIds);
    end
    
    % Calculate node sizes (proportional to stability)
    nodeSizes = 5 + 25 * aggregateStability; % Scale stability to node size
    
    % Get edge weights for thickness
    edgeWeights = G.Edges.Weight;
    if isempty(edgeWeights)
        edgeWeights = ones(G.numedges, 1);
    end
    edgeWidths = 0.5 + 4 * (edgeWeights / (max(edgeWeights) + eps));
    
    % Plot graph with force-directed layout
    p = plot(ax, G, 'Layout', 'force', 'NodeLabel', allNodeIds, ...
        'NodeFontSize', 10, 'NodeFontWeight', 'bold', ...
        'ArrowSize', 10);
    
    % Set node sizes
    p.MarkerSize = nodeSizes;
    
    % Set node colors by quadrant
    colors = containers.Map();
    colors('Q1') = [0.85, 0.2, 0.2]; % Red
    colors('Q2') = [1.0, 0.65, 0.0]; % Orange
    colors('Q3') = [0.2, 0.6, 0.9];  % Blue
    colors('Q4') = [0.5, 0.5, 0.5];  % Gray
    
    % Set node colors by quadrant
    % MATLAB graph plots require NodeCData to be a vector for colormap indexing
    % or we can set individual node colors using highlight()
    quadrantMap = containers.Map({'Q1', 'Q2', 'Q3', 'Q4'}, {1, 2, 3, 4});
    nodeColorIndices = zeros(nNodes, 1);
    for i = 1:nNodes
        if isKey(quadrantMap, aggregateQuadrants{i})
            nodeColorIndices(i) = quadrantMap(aggregateQuadrants{i});
        else
            nodeColorIndices(i) = 4; % Default to Q4
        end
    end
    
    % Create custom colormap with quadrant colors
    customColormap = [colors('Q1'); colors('Q2'); colors('Q3'); colors('Q4')];
    colormap(ax, customColormap);
    p.NodeCData = nodeColorIndices;
    
    % Set edge properties
    p.LineWidth = edgeWidths;
    p.EdgeColor = [0.6, 0.6, 0.6];
    p.EdgeAlpha = 0.7;
    
    % Highlight unstable nodes (low stability)
    unstableThreshold = prctile(aggregateStability, 25); % Bottom 25%
    unstableIdx = find(aggregateStability <= unstableThreshold);
    
    if ~isempty(unstableIdx)
        highlight(p, unstableIdx, 'NodeColor', [0.9, 0.1, 0.1], ...
            'MarkerSize', nodeSizes(unstableIdx) + 8, ...
            'LineWidth', 3.5);
    end
    
    % Labels and title with modern styling
    xlabel(ax, 'Network Layout (Force-Directed)', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Network Layout (Force-Directed)', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, 'Stability Network: Portfolio Aggregate', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, sprintf('Node Size = Stability | Color = Quadrant | %d projects, %d nodes', ...
        nValid, nNodes), ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    % Set axis properties
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.9, 0.9, 0.9];
    ax.GridAlpha = 0.5;
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    
    % Add legend
    legendEntries = {};
    legendHandles = [];
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        if any(strcmp(aggregateQuadrants, quadrant))
            h = plot(ax, NaN, NaN, 'o', 'MarkerSize', 12, ...
                'MarkerFaceColor', colors(quadrant), ...
                'MarkerEdgeColor', [0.3, 0.3, 0.3], 'LineWidth', 1.5);
            legendHandles(end+1) = h;
            legendEntries{end+1} = sprintf('%s - %s', quadrant, getActionFromQuadrant(quadrant));
        end
    end
    if ~isempty(unstableIdx)
        hUnstable = plot(ax, NaN, NaN, 'o', 'MarkerSize', 12, ...
            'MarkerFaceColor', [0.9, 0.1, 0.1], ...
            'MarkerEdgeColor', [0.5, 0.1, 0.1], 'LineWidth', 3.5);
        legendHandles(end+1) = hUnstable;
        legendEntries{end+1} = sprintf('Unstable Nodes (≤25th percentile)');
    end
    
    legend(ax, legendHandles, legendEntries, ...
        'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
        'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on', ...
        'BackgroundColor', [1, 1, 1, 0.95], 'TextColor', [0.2, 0.2, 0.2]);
    
    % Add summary statistics text box
    summaryText = sprintf('Portfolio Summary:\nTotal Nodes: %d\nUnstable Nodes: %d (%.1f%%)\nAvg Stability: %.3f\nProjects: %d', ...
        nNodes, length(unstableIdx), 100*length(unstableIdx)/nNodes, ...
        mean(aggregateStability), nValid);
    
    text(ax, 0.02, 0.98, summaryText, ...
        'Units', 'normalized', ...
        'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
        'Color', [0.2, 0.2, 0.2], ...
        'VerticalAlignment', 'top', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [1, 1, 1, 0.9], ...
        'EdgeColor', [0.5, 0.5, 0.5], ...
        'LineWidth', 1.5, ...
        'Margin', 5);
    
    % Save figure
    savefig(fig, fullfile(figDir, 'stability_network_aggregate.fig'));
    % Keep figure open for viewing
end

function action = getActionFromQuadrant(quadrant)
    % GETACTIONFROMQUADRANT Get action description for quadrant
    actions = containers.Map();
    actions('Q1') = 'Mitigate';
    actions('Q2') = 'Automate';
    actions('Q3') = 'Contingency';
    actions('Q4') = 'Delegate';
    
    if isKey(actions, quadrant)
        action = actions(quadrant);
    else
        action = 'Unknown';
    end
end

% ============================================================================
% Helper Functions for Batch Visualizations
% ============================================================================

function plot3DRiskLandscape(allResults, validIndices, figDir)
    % PLOT3DRISKLANDSCAPE Create a 3D topographical map of risk
    % (Copied from batchProcessProjects.m for accessibility)
    
    nValid = length(validIndices);
    if nValid < 3
        warning('Need at least 3 projects for 3D landscape visualization');
        return;
    end
    
    % Extract data points
    xData = []; % Influence
    yData = []; % Project complexity/index
    zData = []; % Risk
    projectLabels = {};
    
    for idx = 1:nValid
        i = validIndices(idx);
        if ~isempty(allResults.summaries{i})
            summary = allResults.summaries{i};
            
            if isfield(summary, 'avgInfluence') && isfield(summary, 'avgRisk')
                influence = summary.avgInfluence;
                risk = summary.avgRisk;
                
                if isfield(summary, 'nNodes')
                    complexity = summary.nNodes;
                else
                    complexity = idx;
                end
                
                xData(end+1) = influence;
                yData(end+1) = complexity;
                zData(end+1) = risk;
                projName = allResults.projects{i};
                projName = strrep(projName, '_', ' ');
                projName = strrep(projName, '.json', '');
                projName = strrep(projName, 'project ', 'P');
                projectLabels{end+1} = projName;
            end
        end
    end
    
    if length(xData) < 3
        warning('Insufficient data points for 3D landscape');
        return;
    end
    
    % Create interpolation grid
    xMin = min(xData); xMax = max(xData);
    yMin = min(yData); yMax = max(yData);
    xRange = xMax - xMin;
    yRange = yMax - yMin;
    xMin = xMin - 0.1 * xRange;
    xMax = xMax + 0.1 * xRange;
    yMin = yMin - 0.1 * yRange;
    yMax = yMax + 0.1 * yRange;
    
    gridRes = 50;
    xi = linspace(xMin, xMax, gridRes);
    yi = linspace(yMin, yMax, gridRes);
    [XI, YI] = meshgrid(xi, yi);
    
    try
        ZI = griddata(xData, yData, zData, XI, YI, 'cubic');
        nanMask = isnan(ZI);
        if any(nanMask(:))
            ZI(nanMask) = griddata(xData, yData, zData, XI(nanMask), YI(nanMask), 'nearest');
        end
    catch
        ZI = griddata(xData, yData, zData, XI, YI, 'linear');
        nanMask = isnan(ZI);
        if any(nanMask(:))
            ZI(nanMask) = griddata(xData, yData, zData, XI(nanMask), YI(nanMask), 'nearest');
        end
    end
    
    fig = figure('Position', [100, 100, 1600, 1200], ...
        'Name', '3D Risk Landscape - Topographical Risk Map', 'Color', 'white');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    
    surf(ax, XI, YI, ZI, 'EdgeColor', 'none', 'FaceColor', 'interp', ...
        'FaceAlpha', 0.85, 'FaceLighting', 'gouraud');
    colormap(ax, 'viridis');
    c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial');
    c.Label.String = 'Risk Level';
    c.Label.FontSize = 13;
    c.Label.FontWeight = 'bold';
    c.Label.Color = [0.2, 0.2, 0.2];
    c.Color = [0.2, 0.2, 0.2];
    
    light(ax, 'Position', [1, 1, 1], 'Style', 'infinite', 'Color', [1, 1, 1]);
    light(ax, 'Position', [-1, -1, 0.5], 'Style', 'infinite', 'Color', [0.8, 0.8, 0.9]);
    lighting(ax, 'gouraud');
    material(ax, 'shiny');
    
    hold(ax, 'on');
    scatter3(ax, xData, yData, zData, 140, zData, 'filled', ...
        'MarkerEdgeColor', [0.3, 0.3, 0.3], 'LineWidth', 1.5, 'MarkerFaceAlpha', 0.85);
    
    for i = 1:length(xData)
        if i <= length(projectLabels) && ~isempty(projectLabels{i})
            labelText = strrep(projectLabels{i}, '_', ' ');
            labelText = strrep(labelText, '.json', '');
        else
            labelText = sprintf('P%d', i);
        end
        text(ax, xData(i), yData(i), zData(i) + 0.05, labelText, ...
            'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold', ...
            'Color', [0.2, 0.2, 0.2], 'HorizontalAlignment', 'center', ...
            'BackgroundColor', [1, 1, 1, 0.85], 'EdgeColor', [0.5, 0.5, 0.5], 'LineWidth', 1);
    end
    hold(ax, 'off');
    
    xlabel(ax, 'Influence Score', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Project Complexity (Node Count)', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    zlabel(ax, 'Risk Level', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, '3D Risk Landscape: Topographical Risk Map', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, 'Peaks = High Risk Zones | Valleys = Stable Zones', ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.ZColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.85, 0.85, 0.85];
    ax.GridAlpha = 0.5;
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    view(ax, 45, 30);
    
    savefig(fig, fullfile(figDir, '3d_risk_landscape.fig'));
end

function plotMCUncertaintyFan(allResults, validIndices, figDir)
    % PLOTMCUNCERTAINTYFAN Create uncertainty fan plot from Monte Carlo results
    % (Copied from batchProcessProjects.m for accessibility, with fixed structure access)
    
    nValid = length(validIndices);
    if nValid < 2
        warning('Need at least 2 projects for uncertainty fan visualization');
        return;
    end
    
    projectIndices = [];
    meanRisks = [];
    stdDevRisks = [];
    projectNames = {};
    
    for idx = 1:nValid
        i = validIndices(idx);
        if ~isempty(allResults.mcResults{i})
            mcResults = allResults.mcResults{i};
            
            meanRisk = [];
            stdDevRisk = [];
            
            % Check top-level meanScores first (correct structure)
            if isfield(mcResults, 'meanScores') && isfield(mcResults.meanScores, 'risk')
                meanRisk = mean(mcResults.meanScores.risk);
                if isfield(mcResults, 'stdDev') && isfield(mcResults.stdDev, 'risk')
                    stdDevRisk = mean(mcResults.stdDev.risk);
                end
            % Check nested in parameterSensitivity
            elseif isfield(mcResults, 'parameterSensitivity') && ...
                   isfield(mcResults.parameterSensitivity, 'meanScores') && ...
                   isfield(mcResults.parameterSensitivity.meanScores, 'risk')
                meanRisk = mean(mcResults.parameterSensitivity.meanScores.risk);
                if isfield(mcResults.parameterSensitivity, 'stdDev') && ...
                   isfield(mcResults.parameterSensitivity.stdDev, 'risk')
                    stdDevRisk = mean(mcResults.parameterSensitivity.stdDev.risk);
                end
            % Check nested in failureProbDist
            elseif isfield(mcResults, 'failureProbDist') && ...
                   isfield(mcResults.failureProbDist, 'meanScores') && ...
                   isfield(mcResults.failureProbDist.meanScores, 'risk')
                meanRisk = mean(mcResults.failureProbDist.meanScores.risk);
                if isfield(mcResults.failureProbDist, 'stdDev') && ...
                   isfield(mcResults.failureProbDist.stdDev, 'risk')
                    stdDevRisk = mean(mcResults.failureProbDist.stdDev.risk);
                end
            end
            
            % Fallback: use summary statistics
            if isempty(meanRisk) && ~isempty(allResults.summaries{i})
                summary = allResults.summaries{i};
                if isfield(summary, 'avgRisk')
                    meanRisk = summary.avgRisk;
                    if isfield(summary, 'avgStability')
                        stdDevRisk = (1 - summary.avgStability) * 0.3;
                    else
                        stdDevRisk = 0.1;
                    end
                end
            end
            
            if ~isempty(meanRisk)
                projectIndices(end+1) = idx;
                meanRisks(end+1) = meanRisk;
                stdDevRisks(end+1) = stdDevRisk;
                projectNames{end+1} = allResults.projects{i};
            end
        end
    end
    
    if length(meanRisks) < 2
        warning('Insufficient MC data for uncertainty fan visualization');
        return;
    end
    
    [~, sortIdx] = sort(projectIndices);
    meanRisks = meanRisks(sortIdx);
    stdDevRisks = stdDevRisks(sortIdx);
    projectNames = projectNames(sortIdx);
    xAxis = 1:length(meanRisks);
    
    p5 = max(0, min(1, meanRisks - 1.645 * stdDevRisks));
    p25 = max(0, min(1, meanRisks - 0.674 * stdDevRisks));
    p50 = max(0, min(1, meanRisks));
    p75 = max(0, min(1, meanRisks + 0.674 * stdDevRisks));
    p95 = max(0, min(1, meanRisks + 1.645 * stdDevRisks));
    
    fig = figure('Position', [100, 100, 1600, 1000], ...
        'Name', 'Monte Carlo Uncertainty Fan - Risk Confidence Intervals', 'Color', 'white');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    hold(ax, 'on');
    
    xFill = [xAxis, fliplr(xAxis)];
    yFill95 = [p5, fliplr(p95)];
    fill(ax, xFill, yFill95, [0.95, 0.6, 0.3], 'FaceAlpha', 0.25, 'EdgeColor', 'none', ...
        'DisplayName', '90% Confidence Interval (5th-95th percentile)');
    
    yFill75 = [p25, fliplr(p75)];
    fill(ax, xFill, yFill75, [0.95, 0.75, 0.5], 'FaceAlpha', 0.45, 'EdgeColor', 'none', ...
        'DisplayName', '50% Confidence Interval (25th-75th percentile)');
    
    plot(ax, xAxis, p50, '-', 'LineWidth', 3.5, 'Color', [0.2, 0.4, 0.8], ...
        'DisplayName', 'Expected Risk (Median)', 'Marker', 'o', 'MarkerSize', 10, ...
        'MarkerFaceColor', [0.2, 0.4, 0.8], 'MarkerEdgeColor', [0.1, 0.2, 0.5], 'MarkerEdgeWidth', 1.5);
    
    scatter(ax, xAxis, meanRisks, 120, meanRisks, 'filled', ...
        'MarkerEdgeColor', [0.3, 0.3, 0.3], 'LineWidth', 1.5, 'MarkerFaceAlpha', 0.85, ...
        'HandleVisibility', 'off');
    
    for i = 1:length(xAxis)
        if i <= length(projectNames) && ~isempty(projectNames{i})
            labelText = strrep(projectNames{i}, '_', ' ');
            labelText = strrep(labelText, '.json', '');
            labelText = strrep(labelText, 'project ', 'P');
        else
            labelText = sprintf('P%d', i);
        end
        text(ax, xAxis(i), p95(i) + 0.03, labelText, ...
            'FontSize', 10, 'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2], ...
            'HorizontalAlignment', 'center', 'Rotation', 45, 'FontWeight', 'bold', ...
            'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.5, 0.5, 0.5], 'LineWidth', 0.5);
    end
    
    for i = 1:length(xAxis)
        text(ax, xAxis(i), p50(i) - 0.05, sprintf('%.2f', p50(i)), ...
            'FontSize', 9, 'FontName', 'Arial', 'Color', [0.2, 0.4, 0.8], ...
            'HorizontalAlignment', 'center', 'FontWeight', 'bold', ...
            'BackgroundColor', [1, 1, 1, 0.7]);
    end
    
    hold(ax, 'off');
    
    xlabel(ax, 'Project Index', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Risk Level', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, 'Monte Carlo Uncertainty Fan: Risk Confidence Intervals', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, 'Central line = Expected Risk | Shaded areas = Confidence intervals', ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.9, 0.9, 0.9];
    ax.GridAlpha = 0.6;
    ax.GridLineStyle = '-';
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    xlim(ax, [0.5, length(xAxis) + 0.5]);
    ylim(ax, [0, 1]);
    
    legend(ax, 'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
        'TextColor', [0.2, 0.2, 0.2], 'EdgeColor', [0.7, 0.7, 0.7], ...
        'Box', 'on', 'BackgroundColor', [1, 1, 1, 0.95]);
    
    colormap(ax, 'viridis');
    c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial');
    c.Label.String = 'Risk Level';
    c.Label.FontSize = 13;
    c.Label.FontWeight = 'bold';
    c.Label.Color = [0.2, 0.2, 0.2];
    c.Color = [0.2, 0.2, 0.2];
    caxis(ax, [0, 1]);
    
    savefig(fig, fullfile(figDir, 'mc_uncertainty_fan.fig'));
end

function plotParameterSensitivityAggregate(allResults, validIndices, figDir)
    % PLOTPARAMETERSENSITIVITYAGGREGATE Creates aggregate parameter sensitivity heatmap
    % (Copied from batchProcessProjects.m for accessibility)
    
    nValid = length(validIndices);
    if nValid < 1
        warning('No valid projects for parameter sensitivity visualization');
        return;
    end
    
    allSensitivityMatrices = [];
    projectNames = {};
    paramNames = {'Attenuation Factor', 'Risk Multiplier', 'Alignment Weights'};
    
    for idx = 1:nValid
        i = validIndices(idx);
        if ~isempty(allResults.mcResults{i}) && ...
           isfield(allResults.mcResults{i}, 'parameterSensitivity') && ...
           isfield(allResults.mcResults{i}.parameterSensitivity, 'sensitivityMatrix')
            
            sens = allResults.mcResults{i}.parameterSensitivity.sensitivityMatrix;
            if isfield(sens, 'attenuation_factor') && ...
               isfield(sens, 'risk_multiplier') && ...
               isfield(sens, 'alignment_weights')
                
                sensMatrix = [
                    sens.attenuation_factor';
                    sens.risk_multiplier';
                    sens.alignment_weights';
                ];
                
                if isempty(allSensitivityMatrices)
                    allSensitivityMatrices = sensMatrix;
                else
                    [nParams, nNodes] = size(sensMatrix);
                    [nParamsExisting, nNodesExisting] = size(allSensitivityMatrices);
                    
                    if nNodes == nNodesExisting
                        allSensitivityMatrices = (allSensitivityMatrices + sensMatrix) / 2;
                    elseif nNodes < nNodesExisting
                        % Pad the new matrix to match existing size
                        padded = [sensMatrix, zeros(nParams, nNodesExisting - nNodes)];
                        allSensitivityMatrices = (allSensitivityMatrices + padded) / 2;
                    else
                        % New matrix has more nodes - pad existing and use new size
                        paddedExisting = [allSensitivityMatrices, zeros(nParamsExisting, nNodes - nNodesExisting)];
                        allSensitivityMatrices = (paddedExisting + sensMatrix) / 2;
                    end
                end
                
                projName = allResults.projects{i};
                projName = strrep(projName, '_', ' ');
                projName = strrep(projName, '.json', '');
                projectNames{end+1} = projName;
            end
        end
    end
    
    if isempty(allSensitivityMatrices)
        warning('No parameter sensitivity data found for visualization');
        return;
    end
    
    fig = figure('Position', [100, 100, 1600, 800], ...
        'Color', 'white', 'Name', 'Parameter Sensitivity Heatmap - Aggregate');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    
    imagesc(ax, allSensitivityMatrices);
    colormap(ax, 'viridis');
    c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial', 'Location', 'eastoutside');
    c.Label.String = 'Average Sensitivity Magnitude';
    c.Label.FontSize = 13;
    c.Label.FontWeight = 'bold';
    c.Label.Color = [0.2, 0.2, 0.2];
    c.Color = [0.2, 0.2, 0.2];
    caxis(ax, [0, max(allSensitivityMatrices(:))]);
    
    nNodes = size(allSensitivityMatrices, 2);
    set(ax, 'XTick', 1:nNodes);
    set(ax, 'XTickLabel', arrayfun(@(x) sprintf('Node %d', x), 1:nNodes, 'UniformOutput', false));
    set(ax, 'XTickLabelRotation', 45);
    set(ax, 'YTick', 1:length(paramNames));
    set(ax, 'YTickLabel', paramNames);
    
    xlabel(ax, 'Nodes (Aggregated Across Projects)', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Parameters', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, 'Parameter Sensitivity Heatmap: Portfolio Aggregate', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, sprintf('Average sensitivity across %d projects', length(projectNames)), ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.9, 0.9, 0.9];
    ax.GridAlpha = 0.5;
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    
    hold(ax, 'on');
    threshold75 = prctile(allSensitivityMatrices(:), 75);
    threshold90 = prctile(allSensitivityMatrices(:), 90);
    
    [C75, h75] = contour(ax, allSensitivityMatrices, [threshold75, threshold75], ...
        'LineColor', [0.2, 0.6, 0.9], 'LineWidth', 2, 'LineStyle', '--');
    clabel(C75, h75, 'FontSize', 10, 'FontName', 'Arial', 'Color', [0.2, 0.6, 0.9], ...
        'FontWeight', 'bold', 'LabelSpacing', 200);
    
    [C90, h90] = contour(ax, allSensitivityMatrices, [threshold90, threshold90], ...
        'LineColor', [0.9, 0.2, 0.2], 'LineWidth', 2.5, 'LineStyle', '-');
    clabel(C90, h90, 'FontSize', 10, 'FontName', 'Arial', 'Color', [0.9, 0.2, 0.2], ...
        'FontWeight', 'bold', 'LabelSpacing', 200);
    hold(ax, 'off');
    
    [highSensRows, highSensCols] = find(allSensitivityMatrices >= threshold90);
    if ~isempty(highSensRows)
        hold(ax, 'on');
        for i = 1:min(length(highSensRows), 20)
            text(ax, highSensCols(i), highSensRows(i), '★', ...
                'Color', [1, 0.8, 0], 'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        end
        hold(ax, 'off');
    end
    
    legendEntries = {};
    legendHandles = [];
    if ~isempty(highSensRows)
        hStar = plot(ax, NaN, NaN, 'w*', 'MarkerSize', 14, ...
            'MarkerFaceColor', [1, 0.8, 0], 'MarkerEdgeColor', [1, 0.8, 0], 'LineWidth', 2);
        legendEntries{end+1} = 'High Sensitivity (≥90th percentile)';
        legendHandles(end+1) = hStar;
    end
    h75_legend = plot(ax, NaN, NaN, '--', 'Color', [0.2, 0.6, 0.9], 'LineWidth', 2);
    legendEntries{end+1} = '75th Percentile Threshold';
    legendHandles(end+1) = h75_legend;
    h90_legend = plot(ax, NaN, NaN, '-', 'Color', [0.9, 0.2, 0.2], 'LineWidth', 2.5);
    legendEntries{end+1} = '90th Percentile Threshold';
    legendHandles(end+1) = h90_legend;
    
    legend(ax, legendHandles, legendEntries, 'Location', 'best', 'FontSize', 11, ...
        'FontName', 'Arial', 'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on', ...
        'BackgroundColor', [1, 1, 1, 0.95], 'TextColor', [0.2, 0.2, 0.2]);
    
    meanSens = mean(allSensitivityMatrices(:));
    maxSens = max(allSensitivityMatrices(:));
    minSens = min(allSensitivityMatrices(:));
    stdSens = std(allSensitivityMatrices(:));
    
    summaryText = sprintf('Portfolio Summary:\nMean: %.4f\nMax: %.4f\nMin: %.4f\nStd: %.4f\n\nProjects: %d', ...
        meanSens, maxSens, minSens, stdSens, length(projectNames));
    
    text(ax, 0.02, 0.98, summaryText, 'Units', 'normalized', ...
        'FontSize', 10, 'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2], ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'left', ...
        'BackgroundColor', [1, 1, 1, 0.9], 'EdgeColor', [0.5, 0.5, 0.5], ...
        'LineWidth', 1, 'Margin', 5);
    
    savefig(fig, fullfile(figDir, 'parameter_sensitivity_heatmap_aggregate.fig'));
end

% Note: classifyQuadrant and getActionFromQuadrant functions are available
% in MATLAB/Functions/classifyQuadrant.m

