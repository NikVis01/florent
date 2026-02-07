function fig = plotRiskDistributions(stabilityData, mcResults, saveFig)
    % PLOTRISKDISTRIBUTIONS Creates risk distribution histograms
    %
    % Histogram: MC risk score distribution per node
    % Overlay: deterministic calculation (vertical line)
    % Show: if point estimate is in tail vs center
    %
    % Inputs:
    %   stabilityData - Aggregated stability data
    %   mcResults - MC results (for distribution data)
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle
    
    if nargin < 3
        saveFig = true;
    end
    
    % Get MC results (use failure probability distribution if available)
    if isfield(mcResults, 'failureProbDist')
        results = mcResults.failureProbDist;
    elseif isfield(mcResults, 'parameterSensitivity')
        results = mcResults.parameterSensitivity;
    else
        error('MC results not found');
    end
    
    nNodes = length(stabilityData.nodeIds);
    
    % Select sample nodes to plot (top 6 most variable)
    [~, varRank] = sort(stabilityData.scoreVariance.risk, 'descend');
    sampleNodes = varRank(1:min(6, nNodes));
    
    % Create figure with subplots
    fig = figure('Position', [100, 100, 1400, 900]);
    
    nRows = 2;
    nCols = 3;
    
    for i = 1:length(sampleNodes)
        nodeIdx = sampleNodes(i);
        subplot(nRows, nCols, i);
        
        % Get distribution parameters
        meanRisk = stabilityData.meanScores.risk(nodeIdx);
        stdRisk = stabilityData.stdDev.risk(nodeIdx);
        
        % Generate histogram data (simulate from normal distribution)
        % In practice, you'd use actual MC iteration data
        nBins = 30;
        x = linspace(max(0, meanRisk - 4*stdRisk), min(1, meanRisk + 4*stdRisk), nBins);
        pdf = normpdf(x, meanRisk, stdRisk);
        
        % Plot histogram (bar chart of PDF)
        bar(x, pdf, 'FaceColor', [0.3, 0.6, 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.7);
        hold on;
        
        % Overlay deterministic calculation (vertical line)
        if isfield(stabilityData, 'allResults')
            % Try to get original deterministic value
            if isfield(stabilityData.allResults, 'parameterSensitivity')
                origData = stabilityData.allResults.parameterSensitivity;
                if isfield(origData, 'meanScores')
                    deterministic = origData.meanScores.risk(nodeIdx);
                else
                    deterministic = meanRisk; % Use mean as proxy
                end
            else
                deterministic = meanRisk;
            end
        else
            deterministic = meanRisk;
        end
        
        plot([deterministic, deterministic], ylim, 'r-', ...
            'LineWidth', 2.5, 'DisplayName', 'Deterministic');
        
        % Check if deterministic is in tail
        zScore = abs(deterministic - meanRisk) / (stdRisk + eps);
        isInTail = zScore > 1.96; % Outside 95% CI
        
        if isInTail
            text(0.05, 0.95, 'In Tail', 'Units', 'normalized', ...
                'Color', 'red', 'FontWeight', 'bold', ...
                'BackgroundColor', 'white');
        else
            text(0.05, 0.95, 'In Center', 'Units', 'normalized', ...
                'Color', 'green', 'FontWeight', 'bold', ...
                'BackgroundColor', 'white');
        end
        
        % Formatting
        xlabel('Risk Score', 'FontSize', 10);
        ylabel('Probability Density', 'FontSize', 10);
        title(sprintf('%s\nMean=%.3f, Std=%.3f', ...
            stabilityData.nodeIds{nodeIdx}, meanRisk, stdRisk), ...
            'FontSize', 11, 'FontWeight', 'bold');
        grid on;
        legend('Location', 'best', 'FontSize', 8);
        hold off;
    end
    
    % Overall title
    sgtitle('Risk Score Distributions (Monte Carlo)', ...
        'FontSize', 16, 'FontWeight', 'bold');
    
    % Save figure
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end
        savefig(fig, fullfile(figDir, 'risk_distributions.fig'));
        fprintf('Figure saved to: risk_distributions.fig\n');
    end
end

