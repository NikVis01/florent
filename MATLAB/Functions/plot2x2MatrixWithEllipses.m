function fig = plot2x2MatrixWithEllipses(stabilityData, data, saveFig, axesHandle)
    % PLOT2X2MATRIXWITHELLIPSES Creates 2x2 matrix with confidence ellipses
    %
    % Scatter: nodes in Risk vs Influence space
    % Ellipses: 95% confidence regions from MC variance
    % Quadrant boundaries: dashed lines
    % Annotate: unstable nodes (large ellipses)
    %
    % Inputs:
    %   stabilityData - Aggregated stability data
    %   data - Base data structure
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        saveFig = true;
    end
    if nargin < 4
        axesHandle = [];
    end
    
    % Get scores
    influence = stabilityData.meanScores.influence;
    risk = stabilityData.meanScores.risk;
    
    % Get confidence intervals (from MC results if available)
    if isfield(stabilityData, 'allResults')
        if isfield(stabilityData.allResults, 'parameterSensitivity')
            ci = stabilityData.allResults.parameterSensitivity.confidenceIntervals;
            influenceStd = (ci.influence(:,2) - ci.influence(:,1)) / (2 * 1.96);
            riskStd = (ci.risk(:,2) - ci.risk(:,1)) / (2 * 1.96);
        else
            % Use variance to estimate std
            influenceStd = sqrt(stabilityData.scoreVariance.influence);
            riskStd = sqrt(stabilityData.scoreVariance.risk);
        end
    else
        % Fallback: estimate from variance
        influenceStd = sqrt(stabilityData.scoreVariance.influence);
        riskStd = sqrt(stabilityData.scoreVariance.risk);
    end
    
    % Classify quadrants
    quadrants = classifyQuadrant(risk, influence);
    
    % Create figure or use provided axes
    if isempty(axesHandle)
        fig = figure('Position', [100, 100, 1200, 900]);
        ax = axes('Parent', fig);
    else
        ax = axesHandle;
        fig = ax.Parent;
    end
    hold(ax, 'on');
    
    % Define quadrant colors
    colors = containers.Map();
    colors('Q1') = [0.8, 0.2, 0.2]; % Red
    colors('Q2') = [0.2, 0.8, 0.2]; % Green
    colors('Q3') = [0.9, 0.6, 0.1]; % Orange
    colors('Q4') = [0.5, 0.5, 0.5]; % Gray
    
    nNodes = length(risk);
    
    % Draw confidence ellipses for each node
    for i = 1:nNodes
        % Ellipse parameters (95% confidence)
        theta = linspace(0, 2*pi, 100);
        ellipse_x = influence(i) + 1.96 * influenceStd(i) * cos(theta);
        ellipse_y = risk(i) + 1.96 * riskStd(i) * sin(theta);
        
        % Plot ellipse with transparency
        quad = quadrants{i};
        plot(ax, ellipse_x, ellipse_y, '-', 'Color', colors(quad), ...
            'LineWidth', 0.5, 'LineStyle', '--');
        fill(ax, ellipse_x, ellipse_y, colors(quad), 'FaceAlpha', 0.1, ...
            'EdgeColor', 'none');
    end
    
    % Plot nodes by quadrant
    for q = {'Q1', 'Q2', 'Q3', 'Q4'}
        quadrant = q{1};
        idx = strcmp(quadrants, quadrant);
        if any(idx)
            scatter(ax, influence(idx), risk(idx), 100, colors(quadrant), ...
                'filled', 'MarkerEdgeColor', 'k', 'LineWidth', 1.5, ...
                'DisplayName', sprintf('%s - %s', quadrant, getActionFromQuadrant(quadrant)));
        end
    end
    
    % Draw quadrant boundaries
    riskThreshold = median(risk);
    influenceThreshold = median(influence);
    
    xlims = xlim(ax);
    ylims = ylim(ax);
    
    plot(ax, [influenceThreshold, influenceThreshold], ylims, 'k--', ...
        'LineWidth', 2, 'DisplayName', 'Influence Threshold');
    plot(ax, xlims, [riskThreshold, riskThreshold], 'k--', ...
        'LineWidth', 2, 'DisplayName', 'Risk Threshold');
    
    % Annotate unstable nodes (large ellipses)
    ellipseSizes = influenceStd + riskStd; % Combined ellipse size
    unstableThreshold = prctile(ellipseSizes, 75);
    unstableIdx = find(ellipseSizes >= unstableThreshold);
    
    for i = 1:min(length(unstableIdx), 10) % Limit annotations
        idx = unstableIdx(i);
        text(ax, influence(idx), risk(idx), stabilityData.nodeIds{idx}, ...
            'FontSize', 8, 'Color', 'red', 'FontWeight', 'bold', ...
            'BackgroundColor', 'white', 'EdgeColor', 'red');
    end
    
    % Labels and formatting
    xlabel(ax, 'Influence Score', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel(ax, 'Risk Score', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax, '2x2 Risk-Influence Matrix with Confidence Ellipses', ...
        'FontSize', 14, 'FontWeight', 'bold');
    
    legend(ax, 'Location', 'best', 'FontSize', 10);
    grid(ax, 'on');
    axis(ax, 'equal');
    hold(ax, 'off');
    
    % Save figure
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, '2x2_matrix_confidence.fig'));
        fprintf('Figure saved to: 2x2_matrix_confidence.fig\n');
    end
end

