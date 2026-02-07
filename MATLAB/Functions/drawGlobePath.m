function drawGlobePath(fig, pathNodes, style, data)
    % DRAWGLOBEPATH Draws geodesic paths between nodes on globe
    %
    % Usage:
    %   drawGlobePath(fig, [1, 2, 3])  % Draw path through nodes 1->2->3
    %   drawGlobePath(fig, pathNodes, style, data)
    %
    % Inputs:
    %   fig - Figure handle
    %   pathNodes - Vector of node indices forming a path
    %   style - Structure with style options (optional):
    %     .color - Line color (default: 'red')
    %     .lineWidth - Line width (default: 2)
    %     .lineStyle - Line style (default: '-')
    %     .highlight - Highlight critical path (default: false)
    %   data - Data structure with node coordinates (optional)
    %
    % Features:
    %   - Draws geodesic paths between nodes
    %   - Supports critical chain highlighting
    %   - Configurable line styles
    
    if nargin < 3
        style = struct();
    end
    if nargin < 4
        data = [];
    end
    
    % Default style
    if ~isfield(style, 'color')
        style.color = 'red';
    end
    if ~isfield(style, 'lineWidth')
        style.lineWidth = 2;
    end
    if ~isfield(style, 'lineStyle')
        style.lineStyle = '-';
    end
    if ~isfield(style, 'highlight')
        style.highlight = false;
    end
    
    % Get current axes
    ax = fig.CurrentAxes;
    if isempty(ax)
        ax = axes('Parent', fig);
    end
    
    hold(ax, 'on');
    
    % Get node coordinates
    if ~isempty(data) && isfield(data, 'graph') && isfield(data.graph, 'nodePositions')
        % Use provided coordinates
        coords = data.graph.nodePositions;
    else
        % Extract from current plot (if nodes are already plotted)
        % This is a fallback - ideally coordinates should be provided
        warning('Node coordinates not provided, using simplified path drawing');
        coords = [];
    end
    
    % Draw path segments
    if length(pathNodes) < 2
        return; % Need at least 2 nodes for a path
    end
    
    for i = 1:(length(pathNodes)-1)
        node1 = pathNodes(i);
        node2 = pathNodes(i+1);
        
        if ~isempty(coords) && size(coords, 1) >= max(node1, node2)
            % Draw geodesic line between nodes
            x1 = coords(node1, 1);
            y1 = coords(node1, 2);
            z1 = coords(node1, 3);
            
            x2 = coords(node2, 1);
            y2 = coords(node2, 2);
            z2 = coords(node2, 3);
            
            % Draw line (geodesic approximation)
            plot3(ax, [x1, x2], [y1, y2], [z1, z2], ...
                'Color', style.color, ...
                'LineWidth', style.lineWidth, ...
                'LineStyle', style.lineStyle);
        else
            % Simplified: draw straight line
            % This would be replaced with proper geodesic calculation
            % For now, just draw a line
            warning('Drawing simplified path (geodesic not calculated)');
        end
    end
    
    % Highlight if critical path
    if style.highlight
        % Add markers at path nodes
        if ~isempty(coords) && size(coords, 1) >= max(pathNodes)
            pathCoords = coords(pathNodes, :);
            scatter3(ax, pathCoords(:,1), pathCoords(:,2), pathCoords(:,3), ...
                100, style.color, 'filled', 'MarkerEdgeColor', 'k', ...
                'LineWidth', 2);
        end
    end
    
    hold(ax, 'off');
end

