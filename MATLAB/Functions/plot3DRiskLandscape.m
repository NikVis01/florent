function fig = plot3DRiskLandscape(stabilityData, data, saveFig, axesHandle)
    % PLOT3DRISKLANDSCAPE Creates 3D risk landscape visualization
    %
    % Axes: Influence (X), Risk (Y), Centrality (Z)
    % Color: quadrant (4 colors)
    % Animation: parameter sweep showing node drift (optional)
    %
    % Inputs:
    %   stabilityData - Aggregated stability data
    %   data - Base data structure with graph
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        saveFig = true;
    end
    
    % Get scores
    influence = stabilityData.meanScores.influence;
    risk = stabilityData.meanScores.risk;
    
    % Calculate centrality if not available
    if isfield(data.graph, 'centrality')
        centrality = data.graph.centrality;
    else
        centrality = calculateEigenvectorCentrality(data.graph.adjacency);
    end
    
    % Classify quadrants
    quadrants = classifyQuadrant(risk, influence);
    
    % Define quadrant colors
    colors = containers.Map();
    colors('Q1') = [0.8, 0.2, 0.2]; % Red - High Risk, High Influence
    colors('Q2') = [0.2, 0.8, 0.2]; % Green - Low Risk, High Influence
    colors('Q3') = [0.9, 0.6, 0.1]; % Orange - High Risk, Low Influence
    colors('Q4') = [0.5, 0.5, 0.5]; % Gray - Low Risk, Low Influence
    
    % Create figure or use provided axes (CHECK FIRST!)
    if nargin < 4 || isempty(axesHandle)
        fig = figure('Position', [100, 100, 1200, 900]);
        ax = axes('Parent', fig);
    else
        ax = axesHandle;
        fig = ax.Parent;
    end
    
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
    
    % Labels and formatting
    xlabel(ax, 'Influence Score', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax, 'Risk Score', 'FontSize', 12, 'FontWeight', 'bold');
    zlabel(ax, 'Centrality', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax, '3D Risk Landscape: Influence vs Risk vs Centrality', ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    legend(ax, 'Location', 'best', 'FontSize', 10);
    grid(ax, 'on');
    view(ax, 45, 30); % Set viewing angle
    
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
    if saveFig && isempty(axesHandle)
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, '3d_risk_landscape.fig'));
        fprintf('Figure saved to: 3d_risk_landscape.fig\n');
    end
    
    % Return figure handle (or empty if using provided axes)
    if isempty(axesHandle)
        % Return figure handle
    else
        fig = []; % Don't return figure if using provided axes
    end
end

