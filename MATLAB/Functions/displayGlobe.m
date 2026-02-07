function fig = displayGlobe(data, stabilityData, config)
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
    
    % Get node data
    risk = stabilityData.meanScores.risk;
    influence = stabilityData.meanScores.influence;
    quadrants = classifyQuadrant(risk, influence);
    
    % Define quadrant colors
    colors = containers.Map();
    colors('Q1') = [0.8, 0.2, 0.2]; % Red
    colors('Q2') = [0.2, 0.8, 0.2]; % Green
    colors('Q3') = [0.9, 0.6, 0.1]; % Orange
    colors('Q4') = [0.5, 0.5, 0.5]; % Gray
    
    % Create figure
    fig = figure('Position', [100, 100, config.visualization.figureSize], ...
        'Name', 'Florent Globe Risk Map');
    
    % Create 3D axes for globe
    ax = axes('Parent', fig);
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
    
    % Labels and formatting
    xlabel(ax, 'X', 'FontSize', config.visualization.fontSize);
    ylabel(ax, 'Y', 'FontSize', config.visualization.fontSize);
    zlabel(ax, 'Z', 'FontSize', config.visualization.fontSize);
    title(ax, 'Globe Risk Map: Node Size = Risk, Color = Quadrant', ...
        'FontSize', config.visualization.titleFontSize, 'FontWeight', 'bold');
    
    legend(ax, 'Location', 'best', 'FontSize', 10);
    grid(ax, 'on');
    axis(ax, 'equal');
    view(ax, 45, 30); % Set viewing angle
    rotate3d(ax, 'on'); % Enable rotation
    
    hold(ax, 'off');
    
    % Save figure if configured
    if config.report.exportPDF || any(strcmp(config.visualization.saveFormats, 'fig'))
        figDir = config.paths.figuresDir;
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        
        if any(strcmp(config.visualization.saveFormats, 'fig'))
            savefig(fig, fullfile(figDir, 'globe_risk_map.fig'));
        end
        
        if config.report.exportPDF
            try
                exportgraphics(fig, fullfile(figDir, 'globe_risk_map.pdf'), ...
                    'ContentType', 'vector', 'Resolution', config.visualization.dpi);
            catch
                warning('PDF export failed for globe visualization');
            end
        end
    end
    
    fprintf('Globe visualization created\n');
end

