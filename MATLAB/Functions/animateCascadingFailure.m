function animateCascadingFailure(data, stabilityData, startNodeIdx, saveAnim)
    % ANIMATECASCADINGFAILURE Creates animation of cascading failure propagation
    %
    % Start: single node failure
    % Animate: risk propagation through DAG (time-lapse)
    % Node color intensity = risk magnitude
    %
    % Inputs:
    %   data - Base data structure with graph
    %   stabilityData - Stability data with risk scores
    %   startNodeIdx - Index of node to start failure (default: highest risk)
    %   saveAnim - Save animation as GIF (default: true)
    %
    % Output:
    %   Animation displayed and optionally saved
    
    if nargin < 3
        % Start with highest risk node
        [~, startNodeIdx] = max(stabilityData.meanScores.risk);
    end
    if nargin < 4
        saveAnim = true;
    end
    
    fprintf('Creating cascading failure animation...\n');
    
    adj = data.graph.adjacency;
    nNodes = size(adj, 1);
    
    % Initialize risk propagation
    riskLevels = zeros(nNodes, 1);
    riskLevels(startNodeIdx) = 1.0; % Start node fails
    
    % Get topological order for propagation
    topoOrder = topologicalSort(adj);
    
    % Find start node position in topological order
    startPos = find(topoOrder == startNodeIdx);
    
    % Create figure
    fig = figure('Position', [100, 100, 1200, 900]);
    
    % Set up graph layout (force-directed or circular)
    try
        % Try to use graph layout if available
        G = digraph(adj);
        layout = 'force';
        p = plot(G, 'Layout', layout, 'NodeLabel', data.riskScores.nodeIds);
    catch
        % Fallback: circular layout
        angles = linspace(0, 2*pi, nNodes+1);
        angles = angles(1:end-1);
        x = cos(angles);
        y = sin(angles);
        p = plot(digraph(adj), 'XData', x, 'YData', y, ...
            'NodeLabel', data.riskScores.nodeIds);
    end
    
    % Animation frames
    nFrames = min(20, nNodes); % Limit frames
    frames = cell(nFrames, 1);
    
    % Propagate risk through graph
    for frame = 1:nFrames
        % Update risk levels based on propagation
        newRiskLevels = riskLevels;
        
        % Propagate from current risk nodes
        for i = 1:nNodes
            if riskLevels(i) > 0
                % Find children
                children = getChildNodes(adj, i);
                for child = children'
                    % Propagate risk (attenuated)
                    propagationFactor = 0.7; % Risk reduces as it propagates
                    newRiskLevels(child) = max(newRiskLevels(child), ...
                        riskLevels(i) * propagationFactor);
                end
            end
        end
        
        riskLevels = newRiskLevels;
        
        % Update node colors based on risk
        nodeColors = riskLevels;
        p.NodeCData = nodeColors;
        colormap('hot');
        caxis([0, 1]);
        colorbar;
        
        % Update title
        title(sprintf('Cascading Failure Propagation - Frame %d/%d', frame, nFrames), ...
            'FontSize', 14, 'FontWeight', 'bold');
        
        % Highlight start node
        highlight(p, startNodeIdx, 'MarkerSize', 15, 'NodeColor', 'red');
        
        drawnow;
        
        % Capture frame
        frames{frame} = getframe(fig);
        
        % Small delay for animation
        pause(0.1);
    end
    
    % Save animation
    if saveAnim
        animDir = fullfile(pwd, 'MATLAB', 'Animations');
        if ~exist(animDir, 'dir')
            mkdir(animDir);
        end
        
        % Save as GIF
        filename = fullfile(animDir, 'cascading_failure.gif');
        for i = 1:length(frames)
            [A, map] = rgb2ind(frames{i}.cdata, 256);
            if i == 1
                imwrite(A, map, filename, 'gif', 'LoopCount', Inf, 'DelayTime', 0.2);
            else
                imwrite(A, map, filename, 'gif', 'WriteMode', 'append', 'DelayTime', 0.2);
            end
        end
        
        fprintf('Animation saved to: cascading_failure.gif\n');
    end
end

