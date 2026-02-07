function enhanceGlobeVisualization(data, stabilityData, saveFig)
    % ENHANCEGLOBEVISUALIZATION Enhances existing globe visualization
    %
    % Extends displayGlobe.mlx:
    %   - Node size = risk magnitude
    %   - Node color = quadrant
    %   - Lines between dependent nodes (critical chains)
    %   - Interactive rotation/zoom
    %
    % Inputs:
    %   data - Base data structure with graph
    %   stabilityData - Stability data with risk scores
    %   saveFig - Save figure (default: true)
    %
    % Note: This function extends the existing displayGlobe.mlx functionality
    % For full implementation, you would integrate this into displayGlobe.mlx
    
    if nargin < 3
        saveFig = true;
    end
    
    fprintf('Enhancing globe visualization...\n');
    
    % Check if displayGlobe exists
    if exist('displayGlobe.mlx', 'file')
        % Call existing function and enhance
        try
            fig = displayGlobe();
        catch
            % Create new figure if displayGlobe fails
            fig = figure('Position', [100, 100, 1200, 900]);
        end
    else
        % Create new figure
        fig = figure('Position', [100, 100, 1200, 900]);
    end
    
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
    
    % For globe visualization, you would need geographic coordinates
    % This is a simplified version - integrate with actual globe code
    
    % Create 3D scatter plot (simplified globe representation)
    clf(fig);
    axes('Parent', fig);
    
    % Generate positions on sphere (simplified)
    nNodes = length(risk);
    angles = linspace(0, 2*pi, nNodes);
    phi = linspace(0, pi, nNodes);
    x = cos(angles) .* sin(phi);
    y = sin(angles) .* sin(phi);
    z = cos(phi);
    
    % Plot nodes by quadrant with size proportional to risk
    hold on;
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        idx = strcmp(quadrants, quadrant);
        if any(idx)
            nodeSizes = 50 + 200 * risk(idx); % Scale node size by risk
            scatter3(x(idx), y(idx), z(idx), nodeSizes, ...
                colors(quadrant), 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
                'DisplayName', sprintf('%s - %s', quadrant, getActionFromQuadrant(quadrant)));
        end
    end
    
    % Draw lines for critical chains (edges in graph)
    adj = data.graph.adjacency;
    [src, tgt] = find(adj > 0);
    
    for i = 1:min(length(src), 50) % Limit lines for clarity
        plot3([x(src(i)), x(tgt(i))], [y(src(i)), y(tgt(i))], ...
            [z(src(i)), z(tgt(i))], 'k-', 'LineWidth', 0.5, 'Alpha', 0.3);
    end
    
    % Labels
    xlabel('X', 'FontSize', 12);
    ylabel('Y', 'FontSize', 12);
    zlabel('Z', 'FontSize', 12);
    title('Globe Risk Map: Node Size = Risk, Color = Quadrant', ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    legend('Location', 'best');
    grid on;
    axis equal;
    view(45, 30); % Set viewing angle
    rotate3d on; % Enable rotation
    
    hold off;
    
    % Save figure
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, 'globe_risk_map.fig'));
        fprintf('Figure saved to: globe_risk_map.fig\n');
    end
    
    fprintf('Globe visualization enhanced\n');
end

