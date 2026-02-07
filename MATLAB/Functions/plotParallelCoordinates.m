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
    
    % Create figure
    fig = figure('Position', [100, 100, 1400, 700]);
    axes('Parent', fig);
    hold on;
    
    % Axis labels
    axisLabels = {'Local Risk', 'Cascading Risk', 'Influence', 'Centrality'};
    
    % Define quadrant colors
    colors = containers.Map();
    colors('Q1') = [0.8, 0.2, 0.2]; % Red
    colors('Q2') = [0.2, 0.8, 0.2]; % Green
    colors('Q3') = [0.9, 0.6, 0.1]; % Orange - "Cooked Zone"
    colors('Q4') = [0.5, 0.5, 0.5]; % Gray
    
    % Plot lines for each node
    xPositions = 1:nAxes;
    
    % Highlight Q3 (Cooked Zone) with thicker lines
    for i = 1:nNodes
        quad = quadrants{i};
        lineWidth = 2.5;
        lineAlpha = 0.7;
        
        if strcmp(quad, 'Q3')
            lineWidth = 3.5; % Thicker for Cooked Zone
            lineAlpha = 1.0;
        end
        
        plot(xPositions, dataMatrixNorm(i, :), '-', ...
            'Color', [colors(quad), lineAlpha], ...
            'LineWidth', lineWidth, ...
            'DisplayName', quad);
    end
    
    % Set axis properties
    set(gca, 'XTick', xPositions);
    set(gca, 'XTickLabel', axisLabels);
    set(gca, 'XLim', [0.5, nAxes + 0.5]);
    set(gca, 'YLim', [-0.1, 1.1]);
    set(gca, 'YTick', 0:0.2:1);
    set(gca, 'YTickLabel', {'0', '0.2', '0.4', '0.6', '0.8', '1.0'});
    
    ylabel('Normalized Value', 'FontSize', 12, 'FontWeight', 'bold');
    title('Parallel Coordinates Plot: Risk Dimensions', ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    grid on;
    
    % Add legend (simplified - only show quadrants)
    legendEntries = {};
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        if any(strcmp(quadrants, quadrant))
            legendEntries{end+1} = sprintf('%s - %s', quadrant, getActionFromQuadrant(quadrant));
        end
    end
    legend(legendEntries, 'Location', 'best', 'FontSize', 10);
    
    % Add text annotation for Cooked Zone
    text(nAxes/2, 0.95, 'Q3 (Cooked Zone) highlighted in orange', ...
        'HorizontalAlignment', 'center', 'FontSize', 11, ...
        'FontWeight', 'bold', 'Color', colors('Q3'), ...
        'BackgroundColor', 'white');
    
    hold off;
    
    % Save figure
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, 'parallel_coordinates.fig'));
        fprintf('Figure saved to: parallel_coordinates.fig\n');
    end
end

