function fig = plotStabilityNetwork(data, stabilityData, saveFig, axesHandle)
    % PLOTSTABILITYNETWORK Creates stability network visualization
    %
    % Network graph:
    %   - Node size = stability score
    %   - Node color = current quadrant
    %   - Edge thickness = dependency strength
    %   - Animation: unstable nodes pulse/change color (optional)
    %
    % Inputs:
    %   data - Base data structure with graph
    %   stabilityData - Aggregated stability data
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        saveFig = true;
    end
    
    fprintf('Creating stability network visualization...\n');
    
    adj = data.graph.adjacency;
    nNodes = size(adj, 1);
    
    % Get stability scores and quadrants
    stability = stabilityData.overallStability;
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    quadrants = classifyQuadrant(risk, influence);
    
    % Define quadrant colors
    colors = containers.Map();
    colors('Q1') = [0.8, 0.2, 0.2]; % Red
    colors('Q2') = [0.2, 0.8, 0.2]; % Green
    colors('Q3') = [0.9, 0.6, 0.1]; % Orange
    colors('Q4') = [0.5, 0.5, 0.5]; % Gray
    
    % Create figure or use provided axes (CHECK FIRST!)
    if nargin < 4 || isempty(axesHandle)
        fig = figure('Position', [100, 100, 1400, 1000]);
        ax = axes('Parent', fig);
    else
        ax = axesHandle;
        fig = ax.Parent;
    end
    
    % Create graph object
    G = digraph(adj, stabilityData.nodeIds);
    
    % Calculate node sizes (proportional to stability, with minimum size)
    nodeSizes = 30 + 200 * stability; % Scale stability to node size
    
    % Get edge weights for thickness
    edgeWeights = G.Edges.Weight;
    if isempty(edgeWeights)
        % If no weights, use uniform
        edgeWeights = ones(G.numedges, 1);
    end
    edgeWidths = 0.5 + 3 * (edgeWeights / (max(edgeWeights) + eps));
    
    % Plot graph
    p = plot(ax, G, 'Layout', 'force', 'NodeLabel', stabilityData.nodeIds, ...
        'NodeFontSize', 8, 'ArrowSize', 8);
    
    % Set node sizes
    p.MarkerSize = nodeSizes;
    
    % Set node colors by quadrant
    nodeColors = zeros(nNodes, 3);
    for i = 1:nNodes
        nodeColors(i, :) = colors(quadrants{i});
    end
    p.NodeCData = nodeColors;
    
    % Set edge widths
    p.LineWidth = edgeWidths;
    p.EdgeColor = [0.5, 0.5, 0.5];
    p.EdgeAlpha = 0.6;
    
    % Highlight unstable nodes (low stability)
    unstableThreshold = prctile(stability, 25); % Bottom 25%
    unstableIdx = find(stability <= unstableThreshold);
    
    if ~isempty(unstableIdx)
        % Highlight with red border
        highlight(p, unstableIdx, 'NodeColor', 'red', ...
            'MarkerSize', nodeSizes(unstableIdx) + 10, ...
            'LineWidth', 3);
    end
    
    % Title
    title(ax, 'Stability Network: Node Size = Stability, Color = Quadrant', ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    % Add colorbar for stability (if needed)
    colormap('default');
    
    % Add legend
    legendEntries = {};
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        if any(strcmp(quadrants, quadrant))
            legendEntries{end+1} = sprintf('%s - %s', quadrant, getActionFromQuadrant(quadrant));
        end
    end
    legend(legendEntries, 'Location', 'best', 'FontSize', 10);
    
    % Add text annotation
    text(0.02, 0.98, sprintf('Unstable nodes (red border): %d', length(unstableIdx)), ...
        'Units', 'normalized', 'FontSize', 11, 'FontWeight', 'bold', ...
        'BackgroundColor', 'white', 'EdgeColor', 'red', ...
        'VerticalAlignment', 'top');
    
    % Save figure (only if not using provided axes)
    if saveFig && isempty(axesHandle)
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, 'stability_network.fig'));
        fprintf('Figure saved to: stability_network.fig\n');
    end
    
    fprintf('Stability network visualization created\n');
    fprintf('Unstable nodes: %d (%.1f%%)\n', length(unstableIdx), ...
        100*length(unstableIdx)/nNodes);
    
    % Return figure handle (or empty if using provided axes)
    if isempty(axesHandle)
        % Return figure handle
    else
        fig = []; % Don't return figure if using provided axes
    end
end

