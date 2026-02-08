function fig = plot3DRiskLandscape(stabilityData, data, saveFig, axesHandle)
    % PLOT3DRISKLANDSCAPE Creates 3D risk landscape visualization
    %
    % Axes: Influence (X), Risk (Y), Centrality (Z)
    % Color: quadrant (4 colors)
    % Animation: parameter sweep showing node drift (optional)
    %
    % Inputs:
    %   stabilityData - Aggregated stability data OR analysis structure (OpenAPI format)
    %   data - Base data structure with graph (optional if stabilityData is analysis)
    %   saveFig - Save figure (default: true)
    %   axesHandle - Optional axes handle to plot into
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        saveFig = true;
    end
    
    % Check if first parameter is analysis structure (enhanced API format)
    if isstruct(stabilityData) && isfield(stabilityData, 'node_assessments')
        % Enhanced API format - extract from enhanced schemas
        analysis = stabilityData;
        nodeIds = openapiHelpers('getNodeIds', analysis);
        influence = openapiHelpers('getAllInfluenceScores', analysis);
        risk = openapiHelpers('getAllRiskLevels', analysis);
        
        % Get centrality from graph_statistics (enhanced schema)
        graphStats = openapiHelpers('getGraphStatistics', analysis);
        nNodes = length(nodeIds);
        centrality = zeros(nNodes, 1);
        
        if ~isempty(graphStats) && isfield(graphStats, 'centrality')
            for i = 1:nNodes
                nodeId = nodeIds{i};
                nodeCentrality = openapiHelpers('getCentrality', analysis, nodeId);
                if ~isempty(nodeCentrality)
                    % Use eigenvector centrality if available, otherwise pagerank
                    if isfield(nodeCentrality, 'eigenvector')
                        centrality(i) = nodeCentrality.eigenvector;
                    elseif isfield(nodeCentrality, 'pagerank')
                        centrality(i) = nodeCentrality.pagerank;
                    else
                        centrality(i) = 0.5; % Default
                    end
                else
                    centrality(i) = 0.5; % Default
                end
            end
        else
            % Fallback: calculate from graph_topology
            adjMatrix = openapiHelpers('getAdjacencyMatrix', analysis);
            if ~isempty(adjMatrix)
                centrality = calculateEigenvectorCentrality(adjMatrix);
            else
                centrality = ones(nNodes, 1) * 0.5;
            end
        end
    else
        % Legacy format
        influence = stabilityData.meanScores.influence;
        risk = stabilityData.meanScores.risk;
        
        % Calculate centrality if not available
        if isfield(data, 'graph') && isfield(data.graph, 'centrality')
            centrality = data.graph.centrality;
        elseif isfield(data, 'graph') && isfield(data.graph, 'adjacency')
            centrality = calculateEigenvectorCentrality(data.graph.adjacency);
        else
            centrality = ones(length(influence), 1) * 0.5;
        end
    end
    
    % Classify quadrants
    quadrants = classifyQuadrant(risk, influence);
    
    % Define colorblind-friendly quadrant colors (from ColorBrewer)
    colors = containers.Map();
    colors('Q1') = [228, 26, 28] / 255;    % Red (High Risk, High Influence)
    colors('Q2') = [77, 175, 74] / 255;    % Green (Low Risk, High Influence)
    colors('Q3') = [255, 127, 0] / 255;    % Orange (High Risk, Low Influence)
    colors('Q4') = [166, 166, 166] / 255;  % Gray (Low Risk, Low Influence)
    
    % Create figure or use provided axes (CHECK FIRST!)
    if nargin < 4 || isempty(axesHandle)
        fig = figure('Position', [100, 100, 1200, 900], 'Color', 'w', 'Renderer', 'opengl');
        ax = axes('Parent', fig);
    else
        ax = axesHandle;
        fig = ax.Parent;
    end
    set(ax, 'FontSize', 11, 'LineWidth', 1);
    
    % Plot nodes by quadrant
    hold(ax, 'on');
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        idx = strcmp(quadrants, quadrant);
        if any(idx)
            scatter3(ax, influence(idx), risk(idx), centrality(idx), ...
                100, colors(quadrant), 'filled', ...
                'DisplayName', sprintf('%s - %s', quadrant, getActionFromQuadrant(quadrant)));
        end
    end
    
    % Labels and formatting with improved clarity
    xlabel(ax, 'Influence Score', 'FontSize', 13, 'FontWeight', 'bold');
    ylabel(ax, 'Risk Score', 'FontSize', 13, 'FontWeight', 'bold');
    zlabel(ax, 'Network Centrality', 'FontSize', 13, 'FontWeight', 'bold');
    title(ax, '3D Risk Landscape: Multi-dimensional Node Assessment', ...
        'FontSize', 14, 'FontWeight', 'bold');

    legend(ax, 'Location', 'northeastoutside', 'FontSize', 10, 'Box', 'off');
    grid(ax, 'on');
    box(ax, 'on');
    view(ax, 45, 30); % Set viewing angle
    rotate3d(ax, 'on'); % Enable interactive rotation
    
    % Add quadrant boundaries (projected onto planes)
    riskThreshold = median(risk);
    influenceThreshold = median(influence);
    
    % Project boundaries onto XY plane (z=0)
    xlims = xlim(ax);
    ylims = ylim(ax);
    zlims = zlim(ax);
    
    % Risk threshold line (vertical plane)
    plot3(ax, [influenceThreshold, influenceThreshold], ...
        ylims, [zlims(1), zlims(1)], 'k--', 'LineWidth', 1.5, 'DisplayName', 'Risk Threshold');
    
    % Influence threshold line (vertical plane)
    plot3(ax, xlims, [riskThreshold, riskThreshold], ...
        [zlims(1), zlims(1)], 'k--', 'LineWidth', 1.5, 'DisplayName', 'Influence Threshold');
    
    hold(ax, 'off');
    
    % Save figure (only if not using provided axes)
    if saveFig && (nargin < 4 || isempty(axesHandle))
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end

        % Save as .fig for MATLAB
        savefig(fig, fullfile(figDir, '3d_risk_landscape.fig'));

        % Export as high-resolution PDF (vector graphics)
        try
            exportgraphics(fig, fullfile(figDir, '3d_risk_landscape.pdf'), ...
                'ContentType', 'vector', 'BackgroundColor', 'white', 'Resolution', 300);
        catch
            warning('PDF export failed. Only .fig saved.');
        end

        % Export as high-resolution PNG
        try
            exportgraphics(fig, fullfile(figDir, '3d_risk_landscape.png'), ...
                'Resolution', 300, 'BackgroundColor', 'white');
        catch
            warning('PNG export failed.');
        end

        fprintf('Figures saved to: %s\n', figDir);
        fprintf('  - 3d_risk_landscape.fig (MATLAB)\n');
        fprintf('  - 3d_risk_landscape.pdf (vector, publication-quality)\n');
        fprintf('  - 3d_risk_landscape.png (raster, 300 DPI)\n');
    end
    
    % Return figure handle (or empty if using provided axes)
    if isempty(axesHandle)
        % Return figure handle
    else
        fig = []; % Don't return figure if using provided axes
    end
end

