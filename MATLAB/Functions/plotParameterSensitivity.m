function fig = plotParameterSensitivity(mcResults, saveFig, figDir)
    % PLOTPARAMETERSENSITIVITY Creates parameter sensitivity heatmap
    %
    % Grid: parameters (rows) × nodes (columns)
    % Color intensity: sensitivity magnitude
    % Overlay: contour lines for sensitivity thresholds
    %
    % Inputs:
    %   mcResults - MC results structure (must include parameterSensitivity)
    %   saveFig - Save figure (default: true)
    %   figDir - Directory to save figure (optional)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 2
        saveFig = true;
    end
    if nargin < 3
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
    end
    
    if ~isfield(mcResults, 'parameterSensitivity')
        error('parameterSensitivity results not found in mcResults');
    end
    
    results = mcResults.parameterSensitivity;
    
    if ~isfield(results, 'sensitivityMatrix')
        error('sensitivityMatrix not found in parameterSensitivity results');
    end
    
    sens = results.sensitivityMatrix;
    nNodes = length(results.nodeIds);
    
    % Build sensitivity matrix: parameters × nodes
    paramNames = {'Attenuation Factor', 'Risk Multiplier', 'Alignment Weights'};
    sensitivityMatrix = [
        sens.attenuation_factor';
        sens.risk_multiplier';
        sens.alignment_weights';
    ];
    
    % Create figure with modern styling
    fig = figure('Position', [100, 100, 1600, 800], ...
        'Color', 'white', 'Name', 'Parameter Sensitivity Heatmap');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    
    % Create heatmap with modern colormap
    imagesc(ax, sensitivityMatrix);
    colormap(ax, 'viridis'); % Modern, perceptually uniform colormap
    c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial', 'Location', 'eastoutside');
    c.Label.String = 'Sensitivity Magnitude';
    c.Label.FontSize = 13;
    c.Label.FontWeight = 'bold';
    c.Label.Color = [0.2, 0.2, 0.2];
    c.Color = [0.2, 0.2, 0.2];
    caxis(ax, [0, max(sensitivityMatrix(:))]);
    
    % Set axis labels with modern styling
    set(ax, 'XTick', 1:nNodes);
    set(ax, 'XTickLabel', results.nodeIds);
    set(ax, 'XTickLabelRotation', 45);
    set(ax, 'YTick', 1:length(paramNames));
    set(ax, 'YTickLabel', paramNames);
    
    xlabel(ax, 'Nodes', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Parameters', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, 'Parameter Sensitivity Heatmap', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, 'Sensitivity of each node to parameter perturbations', ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    % Set axis properties
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.9, 0.9, 0.9];
    ax.GridAlpha = 0.5;
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    
    % Add contour lines for sensitivity thresholds
    hold(ax, 'on');
    threshold75 = prctile(sensitivityMatrix(:), 75);
    threshold90 = prctile(sensitivityMatrix(:), 90);
    
    % Plot 75th percentile threshold
    [C75, h75] = contour(ax, sensitivityMatrix, [threshold75, threshold75], ...
        'LineColor', [0.2, 0.6, 0.9], 'LineWidth', 2, 'LineStyle', '--');
    clabel(C75, h75, 'FontSize', 10, 'FontName', 'Arial', 'Color', [0.2, 0.6, 0.9], ...
        'FontWeight', 'bold', 'LabelSpacing', 200);
    
    % Plot 90th percentile threshold
    [C90, h90] = contour(ax, sensitivityMatrix, [threshold90, threshold90], ...
        'LineColor', [0.9, 0.2, 0.2], 'LineWidth', 2.5, 'LineStyle', '-');
    clabel(C90, h90, 'FontSize', 10, 'FontName', 'Arial', 'Color', [0.9, 0.2, 0.2], ...
        'FontWeight', 'bold', 'LabelSpacing', 200);
    hold(ax, 'off');
    
    % Add text annotations for high sensitivity regions
    [highSensRows, highSensCols] = find(sensitivityMatrix >= threshold90);
    if ~isempty(highSensRows)
        hold(ax, 'on');
        for i = 1:min(length(highSensRows), 15) % Limit annotations
            text(ax, highSensCols(i), highSensRows(i), '★', ...
                'Color', [1, 0.8, 0], 'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        end
        hold(ax, 'off');
    end
    
    % Add legend
    legendEntries = {};
    legendHandles = [];
    if ~isempty(highSensRows)
        % Create dummy plot for star marker in legend
        hStar = plot(ax, NaN, NaN, 'w*', 'MarkerSize', 14, ...
            'MarkerFaceColor', [1, 0.8, 0], 'MarkerEdgeColor', [1, 0.8, 0], ...
            'LineWidth', 2);
        legendEntries{end+1} = sprintf('High Sensitivity (≥90th percentile)');
        legendHandles(end+1) = hStar;
    end
    h75_legend = plot(ax, NaN, NaN, '--', 'Color', [0.2, 0.6, 0.9], 'LineWidth', 2);
    legendEntries{end+1} = sprintf('75th Percentile Threshold');
    legendHandles(end+1) = h75_legend;
    h90_legend = plot(ax, NaN, NaN, '-', 'Color', [0.9, 0.2, 0.2], 'LineWidth', 2.5);
    legendEntries{end+1} = sprintf('90th Percentile Threshold');
    legendHandles(end+1) = h90_legend;
    
    legend(ax, legendHandles, legendEntries, ...
        'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
        'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on', ...
        'BackgroundColor', [1, 1, 1, 0.95], 'TextColor', [0.2, 0.2, 0.2]);
    
    % Add summary statistics text box
    meanSens = mean(sensitivityMatrix(:));
    maxSens = max(sensitivityMatrix(:));
    minSens = min(sensitivityMatrix(:));
    stdSens = std(sensitivityMatrix(:));
    
    summaryText = sprintf('Summary Statistics:\nMean: %.4f\nMax: %.4f\nMin: %.4f\nStd: %.4f', ...
        meanSens, maxSens, minSens, stdSens);
    
    text(ax, 0.02, 0.98, summaryText, ...
        'Units', 'normalized', ...
        'FontSize', 10, 'FontName', 'Arial', ...
        'Color', [0.2, 0.2, 0.2], ...
        'VerticalAlignment', 'top', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [1, 1, 1, 0.9], ...
        'EdgeColor', [0.5, 0.5, 0.5], ...
        'LineWidth', 1, ...
        'Margin', 5);
    
    % Save figure
    if saveFig
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, 'parameter_sensitivity_heatmap.fig'));
        fprintf('Figure saved to: %s\n', fullfile(figDir, 'parameter_sensitivity_heatmap.fig'));
    end
end
