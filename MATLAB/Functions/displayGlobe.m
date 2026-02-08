function fig = displayGlobe(data, stabilityData, config, axesHandle)
    % DISPLAYGLOBE Creates globe visualization with risk analysis data
    %
    % Replaces displayGlobe.mlx with enhanced functionality
    %
    % Usage:
    %   fig = displayGlobe(data, stabilityData)
    %   fig = displayGlobe(data, stabilityData, config)
    %
    % Inputs:
    %   data - Base data structure with graph and project info
    %   stabilityData - Stability data with risk/influence scores
    %   config - Configuration structure (optional)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        config = loadFlorentConfig();
    end
    if nargin < 4
        axesHandle = [];
    end
    
    fprintf('Creating globe visualization...\n');
    
    % Get geographic data from project
    if isfield(data, 'project') && isfield(data.project, 'country')
        countryCode = data.project.country.a3;
    elseif isfield(data, 'projectId')
        % Try to extract from project data
        countryCode = 'BRA'; % Default fallback
    else
        countryCode = 'BRA'; % Default
    end
    
    geoData = loadGeographicData(countryCode, config);
    
    % Get node data - check if stabilityData is actually analysis (enhanced API format)
    if isstruct(stabilityData) && isfield(stabilityData, 'node_assessments')
        % Enhanced API format
        analysis = stabilityData;
        risk = openapiHelpers('getAllRiskLevels', analysis);
        influence = openapiHelpers('getAllInfluenceScores', analysis);
        nodeIds = openapiHelpers('getNodeIds', analysis);
        
        % Get graph topology for adjacency
        graphTopo = openapiHelpers('getGraphTopology', analysis);
        if ~isempty(graphTopo) && isfield(graphTopo, 'adjacency_matrix')
            adjMatrix = graphTopo.adjacency_matrix;
            if iscell(adjMatrix)
                adjMatrix = cell2mat(adjMatrix);
            end
            % Store in data structure for compatibility
            if ~isfield(data, 'graph')
                data.graph = struct();
            end
            data.graph.adjacency = adjMatrix;
        end
    else
        % Legacy format
        risk = stabilityData.meanScores.risk;
        influence = stabilityData.meanScores.influence;
    end
    quadrants = classifyQuadrant(risk, influence);
    
    % Define colorblind-friendly quadrant colors (from ColorBrewer)
    colors = containers.Map();
    colors('Q1') = [228, 26, 28] / 255;    % Red (High Risk, High Influence)
    colors('Q2') = [77, 175, 74] / 255;    % Green (Low Risk, High Influence)
    colors('Q3') = [255, 127, 0] / 255;    % Orange (High Risk, Low Influence)
    colors('Q4') = [166, 166, 166] / 255;  % Gray (Low Risk, Low Influence)
    
    % Create figure or use provided axes
    if isempty(axesHandle)
        fig = figure('Position', [100, 100, config.visualization.figureSize], ...
            'Name', 'Florent Globe Risk Map', 'Color', 'w', 'Renderer', 'opengl');
        ax = axes('Parent', fig);
    else
        ax = axesHandle;
        fig = ax.Parent;
    end

    % Create 3D axes for globe
    set(ax, 'FontSize', 11);
    hold(ax, 'on');
    
    % Generate node positions on sphere
    % Option 1: Use geographic coordinates if available
    % Option 2: Use graph-based layout
    nNodes = length(risk);
    
    if isfield(data.graph, 'nodePositions') && ~isempty(data.graph.nodePositions)
        % Use provided positions
        nodePos = data.graph.nodePositions;
    else
        % Generate positions on sphere (geographic or graph-based)
        if size(geoData.coordinates, 1) > 0
            % Use geographic coordinates (project to sphere)
            lat = geoData.coordinates(1, 1);
            lon = geoData.coordinates(1, 2);
            
            % Convert lat/lon to 3D sphere coordinates
            % Distribute nodes around country location
            angles = linspace(0, 2*pi, nNodes);
            phi = deg2rad(lat) + 0.1 * sin(angles); % Small variation
            theta = deg2rad(lon) + 0.1 * cos(angles);
            
            R = 1; % Sphere radius
            nodePos = [
                R * cos(phi) .* cos(theta);
                R * cos(phi) .* sin(theta);
                R * sin(phi)
            ]';
        else
            % Fallback: uniform distribution on sphere
            angles = linspace(0, 2*pi, nNodes);
            phi = linspace(0, pi, nNodes);
            nodePos = [
                cos(angles) .* sin(phi);
                sin(angles) .* sin(phi);
                cos(phi)
            ]';
        end
        
        % Store positions for later use
        data.graph.nodePositions = nodePos;
    end
    
    % Plot nodes by quadrant with size proportional to risk
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        idx = strcmp(quadrants, quadrant);
        if any(idx)
            nodeSizes = 50 + 200 * risk(idx); % Scale node size by risk
            scatter3(ax, nodePos(idx, 1), nodePos(idx, 2), nodePos(idx, 3), ...
                nodeSizes, colors(quadrant), 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
                'DisplayName', sprintf('%s - %s', quadrant, getActionFromQuadrant(quadrant)));
        end
    end
    
    % Draw lines for critical chains (edges in graph)
    adj = data.graph.adjacency;
    [src, tgt] = find(adj > 0);
    
    % Limit lines for clarity
    maxLines = min(50, length(src));
    for i = 1:maxLines
        if src(i) <= size(nodePos, 1) && tgt(i) <= size(nodePos, 1)
            plot3(ax, [nodePos(src(i), 1), nodePos(tgt(i), 1)], ...
                [nodePos(src(i), 2), nodePos(tgt(i), 2)], ...
                [nodePos(src(i), 3), nodePos(tgt(i), 3)], ...
                'k-', 'LineWidth', 0.5, 'Color', [0.5, 0.5, 0.5, 0.3]);
        end
    end
    
    % Draw sphere (globe)
    [x, y, z] = sphere(50);
    surf(ax, x, y, z, 'FaceAlpha', 0.1, 'EdgeColor', 'none', ...
        'FaceColor', [0.7, 0.7, 0.9]);
    
    % Labels and formatting with proper geographic context
    xlabel(ax, 'Longitude (scaled)', 'FontSize', config.visualization.fontSize, 'FontWeight', 'bold');
    ylabel(ax, 'Latitude (scaled)', 'FontSize', config.visualization.fontSize, 'FontWeight', 'bold');
    zlabel(ax, 'Elevation (scaled)', 'FontSize', config.visualization.fontSize, 'FontWeight', 'bold');
    title(ax, sprintf('Geographic Risk Distribution: Node Size ∝ Risk Level'), ...
        'FontSize', config.visualization.titleFontSize, 'FontWeight', 'bold');

    legend(ax, 'Location', 'northeastoutside', 'FontSize', 10, 'Box', 'off');
    grid(ax, 'on');
    box(ax, 'on');
    axis(ax, 'equal', 'vis3d');
    view(ax, 45, 30); % Set viewing angle
    rotate3d(ax, 'on'); % Enable rotation

    hold(ax, 'off');
    
    % Save figure if configured (only if not using provided axes)
    if isempty(axesHandle) && (config.report.exportPDF || any(strcmp(config.visualization.saveFormats, 'fig')))
        figDir = config.paths.figuresDir;
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end

        % Save as .fig for MATLAB
        if any(strcmp(config.visualization.saveFormats, 'fig'))
            savefig(fig, fullfile(figDir, 'globe_risk_map.fig'));
        end

        % Export as high-resolution PDF (vector graphics)
        if config.report.exportPDF
            try
                exportgraphics(fig, fullfile(figDir, 'globe_risk_map.pdf'), ...
                    'ContentType', 'vector', 'BackgroundColor', 'white', ...
                    'Resolution', config.visualization.dpi);
            catch
                warning('PDF export failed for globe visualization');
            end
        end

        % Export as high-resolution PNG
        try
            exportgraphics(fig, fullfile(figDir, 'globe_risk_map.png'), ...
                'Resolution', 300, 'BackgroundColor', 'white');
        catch
            warning('PNG export failed for globe visualization');
        end

        fprintf('Globe visualization saved to: %s\n', figDir);
        fprintf('  - globe_risk_map.fig (MATLAB)\n');
        if config.report.exportPDF
            fprintf('  - globe_risk_map.pdf (vector, publication-quality)\n');
        end
        fprintf('  - globe_risk_map.png (raster, 300 DPI)\n');
    end
    
    fprintf('Globe visualization created\n');
    
    % Return figure handle (or empty if using provided axes)
    if isempty(axesHandle)
        % Return figure handle
    else
        fig = []; % Don't return figure if using provided axes
    end
end

