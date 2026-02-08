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
    %   data - Base data structure with graph OR analysis structure (OpenAPI format)
    %   stabilityData - Aggregated stability data (optional if data is analysis)
    %   saveFig - Save figure (default: true)
    %   axesHandle - Optional axes handle to plot into
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        saveFig = true;
    end
    
    fprintf('Creating stability network visualization...\n');
    
    % Check if data is actually an analysis structure (enhanced API format)
    if isstruct(data) && isfield(data, 'node_assessments')
        % Enhanced API format - extract from enhanced schemas
        analysis = data;
        nodeIds = openapiHelpers('getNodeIds', analysis);
        risk = openapiHelpers('getAllRiskLevels', analysis);
        influence = openapiHelpers('getAllInfluenceScores', analysis);
        
        % Get adjacency from graph_topology (enhanced schema)
        adjMatrix = openapiHelpers('getAdjacencyMatrix', analysis);
        if isempty(adjMatrix)
            % Fallback: try graph_topology directly
            graphTopo = openapiHelpers('getGraphTopology', analysis);
            if ~isempty(graphTopo) && isfield(graphTopo, 'adjacency_matrix')
                adjMatrix = graphTopo.adjacency_matrix;
                if iscell(adjMatrix)
                    adjMatrix = cell2mat(adjMatrix);
                end
            end
        end
        
        if isempty(adjMatrix)
            % Empty adjacency if not available
            adjMatrix = zeros(length(nodeIds), length(nodeIds));
        end
        
        % Calculate stability (use risk as proxy if not available)
        if isempty(stabilityData) || ~isfield(stabilityData, 'overallStability')
            stability = 1 - risk; % Simple proxy: lower risk = higher stability
        else
            stability = stabilityData.overallStability;
        end
        
        % Store for compatibility
        adj = adjMatrix;
    else
        % Legacy format
        adj = data.graph.adjacency;
        nodeIds = stabilityData.nodeIds;
        
        % Get stability scores and quadrants
        stability = stabilityData.overallStability;
        risk = stabilityData.meanScores.risk;
        influence = stabilityData.meanScores.influence;
    end
    
    nNodes = size(adj, 1);
    quadrants = classifyQuadrant(risk, influence);
    
    % Define colorblind-friendly quadrant colors (from ColorBrewer)
    colors = containers.Map();
    colors('Q1') = [228, 26, 28] / 255;    % Red (High Risk, High Influence)
    colors('Q2') = [77, 175, 74] / 255;    % Green (Low Risk, High Influence)
    colors('Q3') = [255, 127, 0] / 255;    % Orange (High Risk, Low Influence)
    colors('Q4') = [166, 166, 166] / 255;  % Gray (Low Risk, Low Influence)

    % Create figure or use provided axes (CHECK FIRST!)
    if nargin < 4 || isempty(axesHandle)
        fig = figure('Position', [100, 100, 1400, 1000], 'Color', 'w', 'Renderer', 'opengl');
        ax = axes('Parent', fig);
    else
        ax = axesHandle;
        fig = ax.Parent;
    end
    set(ax, 'FontSize', 11);
    
    % Create graph object
    G = digraph(adj, nodeIds);
    
    % Calculate node sizes (proportional to stability, with minimum size)
    nodeSizes = 1 + 20 * stability; % Scale stability to node size
    
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
    
    % Title with improved clarity
    title(ax, 'Dependency Network: Node Size ∝ Stability, Color = Risk Quadrant', ...
        'FontSize', 14, 'FontWeight', 'bold');

    % Add legend with quadrant information
    legendEntries = {};
    legendHandles = [];
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        if any(strcmp(quadrants, quadrant))
            % Create dummy scatter for legend
            h = scatter(ax, NaN, NaN, 100, colors(quadrant), 'filled');
            legendHandles(end+1) = h;
            legendEntries{end+1} = sprintf('%s: %s', quadrant, getActionFromQuadrant(quadrant));
        end
    end
    legend(ax, legendHandles, legendEntries, 'Location', 'northeastoutside', ...
        'FontSize', 10, 'Box', 'off');

    % Add text annotation with statistics
    text(ax, 0.02, 0.98, sprintf('Unstable Nodes (red border): %d (%.1f%%)\nMean Stability: %.3f', ...
        length(unstableIdx), 100*length(unstableIdx)/nNodes, mean(stability)), ...
        'Units', 'normalized', 'FontSize', 10, 'FontWeight', 'bold', ...
        'BackgroundColor', [1 1 1 0.9], 'EdgeColor', [0.5 0.5 0.5], ...
        'VerticalAlignment', 'top', 'LineWidth', 1);

    % Save figure (only if not using provided axes)
    if saveFig && (nargin < 4 || isempty(axesHandle))
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end

        % Save as .fig for MATLAB
        savefig(fig, fullfile(figDir, 'stability_network.fig'));

        % Export as high-resolution PDF (vector graphics)
        try
            exportgraphics(fig, fullfile(figDir, 'stability_network.pdf'), ...
                'ContentType', 'vector', 'BackgroundColor', 'white', 'Resolution', 300);
        catch
            warning('PDF export failed. Only .fig saved.');
        end

        % Export as high-resolution PNG
        try
            exportgraphics(fig, fullfile(figDir, 'stability_network.png'), ...
                'Resolution', 300, 'BackgroundColor', 'white');
        catch
            warning('PNG export failed.');
        end

        fprintf('Figures saved to: %s\n', figDir);
        fprintf('  - stability_network.fig (MATLAB)\n');
        fprintf('  - stability_network.pdf (vector, publication-quality)\n');
        fprintf('  - stability_network.png (raster, 300 DPI)\n');
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

