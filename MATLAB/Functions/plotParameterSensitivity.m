function fig = plotParameterSensitivity(mcResults, saveFig)
    % PLOTPARAMETERSENSITIVITY Creates parameter sensitivity heatmap
    %
    % Grid: parameters (rows) × nodes (columns)
    % Color intensity: sensitivity magnitude
    % Overlay: contour lines for risk thresholds
    %
    % Inputs:
    %   mcResults - MC results structure (must include parameterSensitivity)
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 2
        saveFig = true;
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
    
    % Create figure
    fig = figure('Position', [100, 100, 1400, 600]);
    
    % Create heatmap
    imagesc(sensitivityMatrix);
    colorbar;
    colormap('hot');
    caxis([0, max(sensitivityMatrix(:))]);
    
    % Labels
    set(gca, 'XTick', 1:nNodes);
    set(gca, 'XTickLabel', results.nodeIds);
    set(gca, 'XTickLabelRotation', 45);
    set(gca, 'YTick', 1:length(paramNames));
    set(gca, 'YTickLabel', paramNames);
    
    xlabel('Nodes', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Parameters', 'FontSize', 12, 'FontWeight', 'bold');
    title('Parameter Sensitivity Heatmap', 'FontSize', 14, 'FontWeight', 'bold');
    
    % Add contour lines for sensitivity thresholds
    hold on;
    threshold = prctile(sensitivityMatrix(:), 75);
    contour(sensitivityMatrix, [threshold, threshold], 'b-', 'LineWidth', 2);
    hold off;
    
    % Add text annotations for high sensitivity regions
    [highSensRows, highSensCols] = find(sensitivityMatrix >= threshold);
    for i = 1:min(length(highSensRows), 10) % Limit annotations
        text(highSensCols(i), highSensRows(i), '*', ...
            'Color', 'cyan', 'FontSize', 12, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center');
    end
    
    % Save figure
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, 'parameter_sensitivity_heatmap.fig'));
        fprintf('Figure saved to: parameter_sensitivity_heatmap.fig\n');
    end
end

