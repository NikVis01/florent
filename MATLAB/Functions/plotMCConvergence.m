function fig = plotMCConvergence(mcResults, saveFig)
    % PLOTMCCONVERGENCE Plots Monte Carlo convergence diagnostics
    %
    % Displays running mean ± 2SE bands vs iteration count to assess convergence
    % Identifies convergence point using Gelman-Rubin statistic or stabilization criteria
    %
    % Inputs:
    %   mcResults - MC results structure with convergence history
    %   saveFig - Save figure (default: true)
    %
    % Output:
    %   fig - Figure handle

    if nargin < 2
        saveFig = true;
    end

    % Use first available result with convergence history
    if isfield(mcResults, 'parameterSensitivity')
        results = mcResults.parameterSensitivity;
    elseif isfield(mcResults, 'crossEncoderUncertainty')
        results = mcResults.crossEncoderUncertainty;
    elseif isfield(mcResults, 'topologyStress')
        results = mcResults.topologyStress;
    elseif isfield(mcResults, 'failureProbDist')
        results = mcResults.failureProbDist;
    else
        error('No MC results found');
    end

    nIterations = results.nIterations;
    nNodes = length(results.nodeIds);

    % Check for actual convergence history
    hasConvergenceHistory = isfield(results, 'convergenceHistory') && ...
                           ~isempty(results.convergenceHistory);

    iterations = 1:nIterations;

    % Create figure with publication-quality settings
    fig = figure('Position', [100, 100, 1400, 900], 'Color', 'w', 'Renderer', 'painters');

    % Aggregate view (mean across all nodes)
    subplot(2, 1, 1);

    meanRisk = mean(results.meanScores.risk);
    meanInfluence = mean(results.meanScores.influence);
    stdRisk = mean(results.stdDev.risk);
    stdInfluence = mean(results.stdDev.influence);

    if hasConvergenceHistory
        % Use actual convergence data
        convHist = results.convergenceHistory;
        riskMeans = convHist.riskMeans;
        influenceMeans = convHist.influenceMeans;
        riskStdErrs = convHist.riskStdErrs;
        influenceStdErrs = convHist.influenceStdErrs;

        riskUpper = riskMeans + 2 * riskStdErrs;
        riskLower = riskMeans - 2 * riskStdErrs;
        influenceUpper = influenceMeans + 2 * influenceStdErrs;
        influenceLower = influenceMeans - 2 * influenceStdErrs;
    else
        % Compute running statistics from raw iterations if available
        if isfield(results, 'rawIterations') && ~isempty(results.rawIterations)
            iterData = results.rawIterations;

            % Calculate running means and standard errors
            riskMeans = zeros(1, nIterations);
            riskStdErrs = zeros(1, nIterations);
            influenceMeans = zeros(1, nIterations);
            influenceStdErrs = zeros(1, nIterations);

            for k = 1:nIterations
                riskMeans(k) = mean(iterData.risk(:, 1:k), 'all');
                riskStdErrs(k) = std(mean(iterData.risk(:, 1:k), 1)) / sqrt(k);
                influenceMeans(k) = mean(iterData.influence(:, 1:k), 'all');
                influenceStdErrs(k) = std(mean(iterData.influence(:, 1:k), 1)) / sqrt(k);
            end

            riskUpper = riskMeans + 2 * riskStdErrs;
            riskLower = riskMeans - 2 * riskStdErrs;
            influenceUpper = influenceMeans + 2 * influenceStdErrs;
            influenceLower = influenceMeans - 2 * influenceStdErrs;
        else
            % Fallback: parametric approximation (mark clearly)
            warning('No convergence history or raw iterations found. Using parametric approximation.');
            convergenceRate = 0.1;
            riskMeans = meanRisk + stdRisk * exp(-convergenceRate * iterations / 100);
            influenceMeans = meanInfluence + stdInfluence * exp(-convergenceRate * iterations / 100);

            riskUpper = riskMeans + 2 * stdRisk * exp(-convergenceRate * iterations / 100);
            riskLower = riskMeans - 2 * stdRisk * exp(-convergenceRate * iterations / 100);
            influenceUpper = influenceMeans + 2 * stdInfluence * exp(-convergenceRate * iterations / 100);
            influenceLower = influenceMeans - 2 * stdInfluence * exp(-convergenceRate * iterations / 100);

            text(0.98, 0.02, 'Parametric approximation', 'Units', 'normalized', ...
                'FontSize', 8, 'Color', [0.7, 0, 0], 'FontAngle', 'italic', ...
                'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
        end
    end
    
    % Plot risk convergence with confidence bands
    hold on;
    fill([iterations, fliplr(iterations)], [riskUpper, fliplr(riskLower)], ...
        [0.2, 0.4, 0.7], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'DisplayName', 'Risk ±2SE');
    plot(iterations, riskMeans, 'b-', 'LineWidth', 2.5, 'DisplayName', 'Risk Mean');

    % Plot influence convergence with confidence bands
    fill([iterations, fliplr(iterations)], [influenceUpper, fliplr(influenceLower)], ...
        [0.7, 0.2, 0.2], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'DisplayName', 'Influence ±2SE');
    plot(iterations, influenceMeans, 'r-', 'LineWidth', 2.5, 'DisplayName', 'Influence Mean');

    % Mark convergence point if identifiable
    if hasConvergenceHistory && isfield(convHist, 'convergenceIteration')
        convIter = convHist.convergenceIteration;
        if convIter > 0 && convIter <= nIterations
            xline(convIter, 'k--', 'LineWidth', 2, 'DisplayName', sprintf('Converged (n=%d)', convIter));
        end
    end

    xlabel('Monte Carlo Iteration', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Running Mean', 'FontSize', 12, 'FontWeight', 'bold');
    title('MC Convergence: Aggregate Statistics (All Nodes)', ...
        'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 10, 'Box', 'off');
    grid on;
    box on;
    set(gca, 'LineWidth', 1, 'FontSize', 11);
    hold off;
    
    % Per-node view (sample of nodes with highest variance)
    subplot(2, 1, 2);

    % Select top 5 most variable nodes
    [~, varRank] = sort(results.variance.risk, 'descend');
    sampleNodes = varRank(1:min(5, nNodes));

    colors = lines(length(sampleNodes));
    hold on;

    for i = 1:length(sampleNodes)
        nodeIdx = sampleNodes(i);
        nodeLabel = strrep(results.nodeIds{nodeIdx}, '_', '\_');

        if hasConvergenceHistory || (isfield(results, 'rawIterations') && ~isempty(results.rawIterations))
            % Calculate per-node running statistics
            if hasConvergenceHistory && isfield(convHist, 'perNode')
                nodeMeans = convHist.perNode(nodeIdx).riskMeans;
                nodeStdErrs = convHist.perNode(nodeIdx).riskStdErrs;
            else
                iterData = results.rawIterations;
                nodeMeans = cumsum(iterData.risk(nodeIdx, :)) ./ (1:nIterations);
                % Calculate running standard error
                nodeStdErrs = zeros(1, nIterations);
                for k = 2:nIterations
                    nodeStdErrs(k) = std(iterData.risk(nodeIdx, 1:k)) / sqrt(k);
                end
                nodeStdErrs(1) = nodeStdErrs(2); % Avoid division by zero
            end

            nodeUpper = nodeMeans + 2 * nodeStdErrs;
            nodeLower = nodeMeans - 2 * nodeStdErrs;

            % Plot with confidence band
            fill([iterations, fliplr(iterations)], [nodeUpper, fliplr(nodeLower)], ...
                colors(i,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            plot(iterations, nodeMeans, '-', 'Color', colors(i,:), 'LineWidth', 2, ...
                'DisplayName', nodeLabel);
        else
            % Fallback to parametric approximation
            nodeMean = results.meanScores.risk(nodeIdx);
            nodeStd = results.stdDev.risk(nodeIdx);
            convergenceRate = 0.1;

            nodeMeans = nodeMean + nodeStd * exp(-convergenceRate * iterations / 100);
            nodeUpper = nodeMeans + 2 * nodeStd * exp(-convergenceRate * iterations / 100);
            nodeLower = nodeMeans - 2 * nodeStd * exp(-convergenceRate * iterations / 100);

            fill([iterations, fliplr(iterations)], [nodeUpper, fliplr(nodeLower)], ...
                colors(i,:), 'FaceAlpha', 0.15, 'EdgeColor', 'none', 'HandleVisibility', 'off');
            plot(iterations, nodeMeans, '-', 'Color', colors(i,:), 'LineWidth', 2, ...
                'DisplayName', nodeLabel);
        end
    end

    xlabel('Monte Carlo Iteration', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Risk Score (Running Mean)', 'FontSize', 12, 'FontWeight', 'bold');
    title('MC Convergence: Top 5 Most Variable Nodes', ...
        'FontSize', 14, 'FontWeight', 'bold');
    legend('Location', 'best', 'FontSize', 9, 'Box', 'off', 'Interpreter', 'tex');
    grid on;
    box on;
    set(gca, 'LineWidth', 1, 'FontSize', 11);
    hold off;
    
    % Identify convergence point using stabilization criteria
    if hasConvergenceHistory && isfield(convHist, 'convergenceIteration')
        convergencePoint = convHist.convergenceIteration;
    elseif exist('riskMeans', 'var') && length(riskMeans) > 10
        % Detect convergence: when relative change < 0.5% for last 10% of iterations
        windowSize = max(10, floor(nIterations * 0.1));
        relChange = abs(diff(riskMeans)) ./ (abs(riskMeans(1:end-1)) + eps);

        % Find first point where all subsequent changes are small
        for k = windowSize:length(relChange)-windowSize
            if all(relChange(k:k+windowSize) < 0.005)
                convergencePoint = k;
                break;
            end
        end

        if exist('convergencePoint', 'var')
            fprintf('Estimated convergence at iteration %d (%.1f%% of total)\n', ...
                convergencePoint, 100*convergencePoint/nIterations);
        else
            fprintf('No clear convergence detected. Consider increasing iterations.\n');
            convergencePoint = [];
        end
    else
        convergencePoint = [];
    end

    % Statistical summary
    fprintf('\n=== MC Convergence Summary ===\n');
    fprintf('Total iterations: %d\n', nIterations);
    if ~isempty(convergencePoint)
        fprintf('Convergence iteration: %d\n', convergencePoint);
        fprintf('Effective sample size: %d\n', nIterations - convergencePoint);
    end
    fprintf('Final risk mean: %.4f ± %.4f (SE)\n', meanRisk, stdRisk/sqrt(nIterations));
    fprintf('Final influence mean: %.4f ± %.4f (SE)\n', meanInfluence, stdInfluence/sqrt(nIterations));
    fprintf('============================\n\n');

    % Save figure with publication-quality settings
    if saveFig
        figDir = fullfile(pwd, 'MATLAB', 'Figures');
        if ~exist(figDir, 'dir')
            mkdir(figDir);
        end

        % Save as .fig for MATLAB
        savefig(fig, fullfile(figDir, 'mc_convergence.fig'));

        % Export as high-resolution PDF (vector graphics)
        try
            exportgraphics(fig, fullfile(figDir, 'mc_convergence.pdf'), ...
                'ContentType', 'vector', 'BackgroundColor', 'white', 'Resolution', 300);
        catch
            warning('PDF export failed. Only .fig saved.');
        end

        % Export as high-resolution PNG
        try
            exportgraphics(fig, fullfile(figDir, 'mc_convergence.png'), ...
                'Resolution', 300, 'BackgroundColor', 'white');
        catch
            warning('PNG export failed.');
        end

        fprintf('Figures saved to: %s\n', figDir);
        fprintf('  - mc_convergence.fig (MATLAB)\n');
        fprintf('  - mc_convergence.pdf (vector, publication-quality)\n');
        fprintf('  - mc_convergence.png (raster, 300 DPI)\n');
    end
end

