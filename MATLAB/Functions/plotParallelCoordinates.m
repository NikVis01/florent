function fig = plotParallelCoordinates(stabilityData, data, saveFig)
    % PLOTPARALLELCOORDINATES Creates parallel coordinates plot
    %
    % Axes: Local Risk, Cascading Risk, Influence, Centrality
    % Highlight: paths leading to "Cooked Zone" (Q3)
    % Interactive brushing by quadrant (basic implementation)
    %
    % Inputs:
    %   stabilityData - Stability data
    %   data - Base data structure
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        saveFig = true;
    end
    
    % Get data
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    
    % Calculate cascading risk (1 - P(success))
    if isfield(data.riskScores, 'cascadingRisk')
        cascadingRisk = data.riskScores.cascadingRisk;
    else
        cascadingRisk = risk; % Use risk as proxy
    end
    
    % Local risk (failure probability)
    if isfield(data.riskScores, 'localFailureProb')
        localRisk = data.riskScores.localFailureProb;
    else
        localRisk = risk * 0.5; % Estimate
    end
    
    % Centrality
    if isfield(data.graph, 'centrality')
        centrality = data.graph.centrality;
    else
        centrality = calculateEigenvectorCentrality(data.graph.adjacency);
    end
    
    % Classify quadrants
    quadrants = classifyQuadrant(risk, influence);
    
    % Prepare data matrix: [Local Risk, Cascading Risk, Influence, Centrality]
    dataMatrix = [localRisk, cascadingRisk, influence, centrality];
    nNodes = size(dataMatrix, 1);
    nAxes = size(dataMatrix, 2);
    
    % Normalize each axis to [0, 1]
    dataMatrixNorm = zeros(size(dataMatrix));
    for i = 1:nAxes
        col = dataMatrix(:, i);
        dataMatrixNorm(:, i) = (col - min(col)) / (max(col) - min(col) + eps);
    end
    
    % Create figure with publication-quality settings
    fig = figure('Position', [100, 100, 1400, 700], 'Color', 'w', 'Renderer', 'painters');
    ax = axes('Parent', fig);
    hold(ax, 'on');
    
    % Axis labels
    axisLabels = {'Local Risk', 'Cascading Risk', 'Influence', 'Centrality'};
    
    % Define colorblind-friendly quadrant colors (from ColorBrewer)
    colors = containers.Map();
    colors('Q1') = [228, 26, 28] / 255;    % Red (High Risk, High Influence)
    colors('Q2') = [77, 175, 74] / 255;    % Green (Low Risk, High Influence)
    colors('Q3') = [255, 127, 0] / 255;    % Orange (High Risk, Low Influence - "Cooked Zone")
    colors('Q4') = [166, 166, 166] / 255;  % Gray (Low Risk, Low Influence)

    % Plot lines for each node
    xPositions = 1:nAxes;

    % Highlight Q3 (Cooked Zone) with thicker lines
    for i = 1:nNodes
        quad = quadrants{i};
        lineWidth = 1.5;
        lineAlpha = 0.4;

        if strcmp(quad, 'Q3')
            lineWidth = 2.5; % Thicker for Cooked Zone
            lineAlpha = 0.8;
        elseif strcmp(quad, 'Q1')
            lineWidth = 2.0; % Also emphasize high risk
            lineAlpha = 0.6;
        end

        plot(ax, xPositions, dataMatrixNorm(i, :), '-', ...
            'Color', [colors(quad), lineAlpha], ...
            'LineWidth', lineWidth, ...
            'DisplayName', quad);
    end

    % Set axis properties
    set(ax, 'XTick', xPositions);
    set(ax, 'XTickLabel', axisLabels);
    set(ax, 'XLim', [0.5, nAxes + 0.5]);
    set(ax, 'YLim', [-0.05, 1.05]);
    set(ax, 'YTick', 0:0.25:1);
    set(ax, 'YTickLabel', {'0.00', '0.25', '0.50', '0.75', '1.00'});
    set(ax, 'FontSize', 11);
    set(ax, 'LineWidth', 1);

    ylabel(ax, 'Normalized Value', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax, 'Parallel Coordinates: Risk Dimensions Across Nodes', ...
        'FontSize', 14, 'FontWeight', 'bold');

    grid(ax, 'on');
    box(ax, 'on');
    
    % Add legend (show only present quadrants)
    legendEntries = {};
    legendHandles = [];
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        if any(strcmp(quadrants, quadrant))
            % Create dummy line for legend
            h = plot(ax, NaN, NaN, '-', 'Color', colors(quadrant), 'LineWidth', 2);
            legendHandles(end+1) = h;
            legendEntries{end+1} = sprintf('%s: %s', quadrant, getActionFromQuadrant(quadrant));
        end
    end
    legend(ax, legendHandles, legendEntries, 'Location', 'best', 'FontSize', 10, 'Box', 'off');

    % Add annotation for Cooked Zone with quadrant counts
    q3Count = sum(strcmp(quadrants, 'Q3'));
    text(ax, 0.5, 1.02, sprintf('Q3 (Cooked Zone) highlighted: %d nodes (%.1f%%)', ...
        q3Count, 100*q3Count/nNodes), ...
        'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 10, ...
        'FontWeight', 'bold', 'Color', colors('Q3'), ...
        'BackgroundColor', [1 1 1 0.9], 'EdgeColor', colors('Q3'), 'LineWidth', 1.5);

    hold(ax, 'off');
    
    % Save figure with publication-quality settings
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end

        % Save as .fig for MATLAB
        savefig(fig, fullfile(figDir, 'parallel_coordinates.fig'));

        % Export as high-resolution PDF (vector graphics)
        try
            exportgraphics(fig, fullfile(figDir, 'parallel_coordinates.pdf'), ...
                'ContentType', 'vector', 'BackgroundColor', 'white', 'Resolution', 300);
        catch
            warning('PDF export failed. Only .fig saved.');
        end

        % Export as high-resolution PNG
        try
            exportgraphics(fig, fullfile(figDir, 'parallel_coordinates.png'), ...
                'Resolution', 300, 'BackgroundColor', 'white');
        catch
            warning('PNG export failed.');
        end

        fprintf('Figures saved to: %s\n', figDir);
        fprintf('  - parallel_coordinates.fig (MATLAB)\n');
        fprintf('  - parallel_coordinates.pdf (vector, publication-quality)\n');
        fprintf('  - parallel_coordinates.png (raster, 300 DPI)\n');
    end
end

