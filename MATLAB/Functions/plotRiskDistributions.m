function fig = plotRiskDistributions(stabilityData, mcResults, saveFig)
    % PLOTRISKDISTRIBUTIONS Creates risk distribution histograms from Monte Carlo simulations
    %
    % Displays empirical risk score distributions per node with statistical overlays
    %
    % Inputs:
    %   stabilityData - Aggregated stability data with MC iteration history
    %   mcResults - MC results containing raw iteration data
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle

    if nargin < 3
        saveFig = true;
    end

    % Get MC results with iteration history
    if isfield(mcResults, 'failureProbDist') && isfield(mcResults.failureProbDist, 'rawIterations')
        results = mcResults.failureProbDist;
        iterData = results.rawIterations;
    elseif isfield(mcResults, 'parameterSensitivity') && isfield(mcResults.parameterSensitivity, 'rawIterations')
        results = mcResults.parameterSensitivity;
        iterData = results.rawIterations;
    else
        warning('No raw MC iteration data found. Using parametric approximation.');
        iterData = [];
    end

    nNodes = length(stabilityData.nodeIds);

    % Select sample nodes to plot (top 6 most variable)
    [~, varRank] = sort(stabilityData.scoreVariance.risk, 'descend');
    sampleNodes = varRank(1:min(6, nNodes));

    % Create figure with publication-quality settings
    fig = figure('Position', [100, 100, 1400, 900], 'Color', 'w', 'Renderer', 'painters');

    nRows = 2;
    nCols = 3;

    for i = 1:length(sampleNodes)
        nodeIdx = sampleNodes(i);
        subplot(nRows, nCols, i);

        % Get distribution statistics
        meanRisk = stabilityData.meanScores.risk(nodeIdx);
        stdRisk = stabilityData.stdDev.risk(nodeIdx);

        % Use real MC data if available, otherwise parametric approximation
        if ~isempty(iterData) && isfield(iterData, 'risk') && size(iterData.risk, 1) >= nodeIdx
            % Plot histogram from actual MC iterations
            riskSamples = iterData.risk(nodeIdx, :);
            nBins = min(30, floor(length(riskSamples)/5)); % Sturges' rule
            [counts, edges] = histcounts(riskSamples, nBins, 'Normalization', 'pdf');
            binCenters = (edges(1:end-1) + edges(2:end)) / 2;

            bar(binCenters, counts, 'FaceColor', [0.2, 0.4, 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        else
            % Parametric approximation (less ideal)
            nBins = 30;
            x = linspace(max(0, meanRisk - 4*stdRisk), min(1, meanRisk + 4*stdRisk), nBins);
            pdf = normpdf(x, meanRisk, stdRisk);
            binCenters = x;
            counts = pdf;

            bar(binCenters, counts, 'FaceColor', [0.2, 0.4, 0.7], 'EdgeColor', 'none', 'FaceAlpha', 0.6);
            text(0.98, 0.98, 'Parametric', 'Units', 'normalized', 'FontSize', 7, ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
                'Color', [0.5, 0.5, 0.5], 'FontAngle', 'italic');
        end
        hold on;
        
        % Add mean line with confidence interval
        yLimits = ylim;
        plot([meanRisk, meanRisk], yLimits, 'r-', ...
            'LineWidth', 2.5, 'DisplayName', 'Mean');

        % Add 95% confidence interval shading
        ci95_lower = meanRisk - 1.96 * stdRisk;
        ci95_upper = meanRisk + 1.96 * stdRisk;
        patch([ci95_lower ci95_upper ci95_upper ci95_lower], ...
              [yLimits(1) yLimits(1) yLimits(2) yLimits(2)], ...
              'r', 'FaceAlpha', 0.1, 'EdgeColor', 'none', 'DisplayName', '95% CI');

        % Add median and mode if using empirical data
        if ~isempty(iterData) && isfield(iterData, 'risk') && size(iterData.risk, 1) >= nodeIdx
            riskSamples = iterData.risk(nodeIdx, :);
            medianRisk = median(riskSamples);
            plot([medianRisk, medianRisk], yLimits, 'b--', ...
                'LineWidth', 1.5, 'DisplayName', 'Median');

            % Add statistical text box
            [~, maxIdx] = max(counts);
            modeRisk = binCenters(maxIdx);
            skewness = skewness(riskSamples);
            kurtosis_val = kurtosis(riskSamples) - 3; % Excess kurtosis

            statsText = sprintf(['μ = %.3f\n' ...
                                 'σ = %.3f\n' ...
                                 'Skew = %.2f\n' ...
                                 'Kurt = %.2f\n' ...
                                 'n = %d'], ...
                                meanRisk, stdRisk, skewness, kurtosis_val, length(riskSamples));
        else
            statsText = sprintf(['μ = %.3f\n' ...
                                 'σ = %.3f\n' ...
                                 'CI₉₅ = [%.3f, %.3f]'], ...
                                meanRisk, stdRisk, ci95_lower, ci95_upper);
        end

        text(0.98, 0.95, statsText, 'Units', 'normalized', ...
            'FontSize', 8, 'FontName', 'Courier', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
            'BackgroundColor', [1 1 1 0.8], 'EdgeColor', [0.5 0.5 0.5], 'LineWidth', 0.5);

        % Improved formatting
        xlabel('Risk Score', 'FontSize', 11, 'FontWeight', 'bold');
        ylabel('Probability Density', 'FontSize', 11, 'FontWeight', 'bold');

        % Clean node ID display
        nodeLabel = strrep(stabilityData.nodeIds{nodeIdx}, '_', '\_');
        title(sprintf('%s', nodeLabel), 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'tex');

        grid on;
        box on;
        set(gca, 'LineWidth', 1, 'FontSize', 10);
        legend('Location', 'best', 'FontSize', 8, 'Box', 'off');
        hold off;
    end

    % Overall title with sample size
    if ~isempty(iterData) && isfield(iterData, 'risk')
        nIterations = size(iterData.risk, 2);
        sgtitle(sprintf('Risk Score Distributions (n=%d MC iterations, top 6 most variable nodes)', nIterations), ...
            'FontSize', 16, 'FontWeight', 'bold');
    else
        sgtitle('Risk Score Distributions (parametric approximation)', ...
            'FontSize', 16, 'FontWeight', 'bold');
    end
    
    % Save figure with publication-quality settings
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end

        % Save as .fig for MATLAB
        savefig(fig, fullfile(figDir, 'risk_distributions.fig'));

        % Export as high-resolution PDF (vector graphics)
        try
            exportgraphics(fig, fullfile(figDir, 'risk_distributions.pdf'), ...
                'ContentType', 'vector', 'BackgroundColor', 'white', 'Resolution', 300);
        catch
            warning('PDF export failed. Only .fig saved.');
        end

        % Export as high-resolution PNG (raster for presentations)
        try
            exportgraphics(fig, fullfile(figDir, 'risk_distributions.png'), ...
                'Resolution', 300, 'BackgroundColor', 'white');
        catch
            warning('PNG export failed.');
        end

        fprintf('Figures saved to: %s\n', figDir);
        fprintf('  - risk_distributions.fig (MATLAB)\n');
        fprintf('  - risk_distributions.pdf (vector, publication-quality)\n');
        fprintf('  - risk_distributions.png (raster, 300 DPI)\n');
    end
end

