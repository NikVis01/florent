function batchProcessProjects()
    % BATCHPROCESSPROJECTS Process all 20 POC projects sequentially
    %
    % Processes project_000.json through project_019.json with firm.json
    % Collects all quantitative data and creates aggregate visualizations
    %
    % Usage:
    %   batchProcessProjects()
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT: BATCH RISK ANALYSIS\n');
    fprintf('  Processing 20 Infrastructure Projects\n');
    fprintf('  Dependency Mapping & Risk Propagation\n');
    fprintf('========================================\n\n');
    
    % Step 1: Locate workspace root
    fprintf('[STEP 1] Locating workspace root...\n');
    scriptPath = fileparts(mfilename('fullpath'));
    matlabDir = fileparts(scriptPath);
    workspaceRoot = fileparts(matlabDir);
    fprintf('  [OK] Workspace root: %s\n', workspaceRoot);
    fprintf('\n');
    
    % Step 2: Find all project files
    fprintf('[STEP 2] Finding project files...\n');
    pocDir = fullfile(workspaceRoot, 'src', 'data', 'poc');
    firmPath = fullfile(pocDir, 'firm.json');
    
    % Get all project files (project_000.json through project_019.json)
    projectFiles = {};
    for i = 0:19
        projectFile = fullfile(pocDir, sprintf('project_%03d.json', i));
        if isfile(projectFile)
            projectFiles{end+1} = sprintf('project_%03d.json', i);
        else
            warning('Project file not found: %s', projectFile);
        end
    end
    
    nProjects = length(projectFiles);
    fprintf('  [OK] Found %d project files\n', nProjects);
    fprintf('  [OK] Firm file: firm.json\n');
    fprintf('\n');
    
    if nProjects == 0
        error('No project files found!');
    end
    
    % Step 3: Initialize Florent
    fprintf('[STEP 3] Initializing Florent...\n');
    try
        initializeFlorent(false);
        fprintf('  [OK] Florent initialized\n');
    catch ME
        warning('Initialization warning: %s', ME.message);
    end
    fprintf('\n');
    
    % Step 4: Load configuration
    fprintf('[STEP 4] Loading configuration...\n');
    mode = 'test';
    nIterations = 100;
    try
        config = loadFlorentConfig(mode);
        config.monteCarlo.nIterations = nIterations;
        % Increase timeout significantly for batch processing (10 minutes)
        config.api.timeout = 600; % 10 minutes
        fprintf('  [OK] Config loaded (mode: %s, MC iterations: %d)\n', mode, nIterations);
        fprintf('  [OK] API timeout set to %d seconds for batch processing\n', config.api.timeout);
    catch ME
        warning('Config load failed: %s', ME.message);
        config = struct();
        config.api = struct();
        config.api.baseUrl = 'http://localhost:8000';
        config.api.timeout = 600; % 10 minutes
        config.api.retryAttempts = 3;
        config.api.retryDelay = 2;
        config.monteCarlo = struct();
        config.monteCarlo.nIterations = nIterations;
    end
    fprintf('\n');
    
    % Step 4.5: Check API health before starting
    fprintf('[STEP 4.5] Checking API health...\n');
    try
        client = FlorentAPIClientWrapper(config);
        healthResult = client.healthCheck();
        fprintf('  [OK] API is responding\n');
    catch ME
        warning('API health check failed: %s', ME.message);
        fprintf('  [WARNING] API may not be running. Continuing anyway...\n');
        fprintf('  [INFO] Make sure the Python API server is running at %s\n', config.api.baseUrl);
    end
    fprintf('\n');
    
    % Step 5: Process each project in parallel
    fprintf('[STEP 5] Processing projects in parallel...\n');
    fprintf('========================================\n\n');
    
    % Initialize parallel pool
    fprintf('Initializing parallel pool...\n');
    warning('off', 'parallel:convenience:LocalPoolStartup');
    warning('off', 'parallel:convenience:LocalPoolShutdown');
    
    pool = gcp('nocreate');
    if isempty(pool)
        fprintf('  Creating new parallel pool...\n');
        pool = parpool('local');
        fprintf('  [OK] Created parallel pool with %d workers\n', pool.NumWorkers);
        
        % Setup paths on workers
        fprintf('  Configuring worker paths...\n');
        workerPathResult = pathManager('setupWorkerPaths', pool);
        if workerPathResult.success
            fprintf('  [OK] Worker paths configured successfully\n');
        else
            warning('  [WARNING] Worker path setup had issues: %s', strjoin(workerPathResult.errors, '; '));
        end
    else
        fprintf('  [OK] Reusing existing parallel pool with %d workers\n', pool.NumWorkers);
    end
    fprintf('\n');
    
    % Storage for all results (pre-allocate for parfor)
    % Use separate arrays for parfor compatibility
    projectFilesOut = cell(nProjects, 1);
    analysesOut = cell(nProjects, 1);
    stabilityDataOut = cell(nProjects, 1);
    mcResultsOut = cell(nProjects, 1);
    summariesOut = cell(nProjects, 1);
    
    % Load firm.json once (same for all projects)
    fprintf('Loading firm.json...\n');
    try
        firmJsonPath = fullfile(pocDir, 'firm.json');
        firmJsonText = fileread(firmJsonPath);
        firmDataTemplate = jsondecode(firmJsonText);
        fprintf('  [OK] Firm data loaded\n');
    catch ME
        error('Failed to load firm.json: %s', ME.message);
    end
    fprintf('\n');
    
    % Process projects in parallel
    fprintf('Processing %d projects in parallel...\n', nProjects);
    tic;
    
    parfor i = 1:nProjects
        projectFile = projectFiles{i};
        projectJsonPath = fullfile(pocDir, projectFile);
        
        fprintf('[Worker %d] --- Processing Project %d/%d: %s ---\n', labindex, i, nProjects, projectFile);
        tic;
        
        try
            % Load project JSON file
            fprintf('[Worker %d] Loading project JSON for %s...\n', labindex, projectFile);
            projectJsonText = fileread(projectJsonPath);
            projectData = jsondecode(projectJsonText);
            fprintf('[Worker %d] [OK] Project data loaded for %s\n', labindex, projectFile);
            
            % Create a fresh copy of firmData for this request to avoid reference issues
            % Convert to JSON string and back to ensure deep copy
            firmDataJson = jsonencode(firmDataTemplate);
            firmData = jsondecode(firmDataJson);
            
            % Validate JSON structure has required fields
            if ~isfield(projectData, 'id')
                warning('[Worker %d] Project JSON missing "id" field, using filename as ID', labindex);
                [~, projectName, ~] = fileparts(projectFile);
                projectData.id = projectName;
            end
            if ~isfield(firmData, 'id')
                warning('[Worker %d] Firm JSON missing "id" field, using default', labindex);
                firmData.id = 'firm_001';
            end
            
            % Validate data structures are valid (not empty, have required fields)
            if isempty(projectData) || ~isstruct(projectData)
                error('[Worker %d] Project data is empty or invalid', labindex);
            end
            if isempty(firmData) || ~isstruct(firmData)
                error('[Worker %d] Firm data is empty or invalid', labindex);
            end
            
            % Log request details for debugging
            fprintf('[Worker %d] [DEBUG] Request details for %s:\n', labindex, projectFile);
            fprintf('[Worker %d]     Project ID: %s\n', labindex, projectData.id);
            fprintf('[Worker %d]     Firm ID: %s\n', labindex, firmData.id);
            fprintf('[Worker %d]     Budget: %d\n', labindex, config.api.budget);
            
            % Run analysis with inline data (not paths)
            % We need to manually call the API with inline data and then run the pipeline
            fprintf('[Worker %d] Calling API with inline data for %s...\n', labindex, projectFile);
            
            % Create API client
            client = FlorentAPIClientWrapper(config);
            
            % Initialize variables for parfor
            analysisData = [];
            mcResults = struct();
            stabilityData = [];
            
            % Call API with inline data - wrap in try-catch to get detailed error
            try
                fprintf('[Worker %d] [DEBUG] About to call analyzeProjectWithData for %s...\n', ...
                    labindex, projectFile);
                tic;
                analysisData = client.analyzeProjectWithData(firmData, projectData, config.api.budget, true);
                elapsed = toc;
                fprintf('[Worker %d] [OK] API call successful for %s (took %.2f seconds)\n', ...
                    labindex, projectFile, elapsed);
            catch ME
                % Try to get more detailed error information
                if contains(ME.message, '400') || contains(ME.message, 'Bad Request')
                    fprintf('[Worker %d] [ERROR] API rejected request with 400 Bad Request\n', labindex);
                    fprintf('[Worker %d] [DEBUG] Project ID: %s\n', labindex, projectData.id);
                    fprintf('[Worker %d] [DEBUG] Firm ID: %s\n', labindex, firmData.id);
                    fprintf('[Worker %d] [DEBUG] Budget: %d\n', labindex, config.api.budget);
                    fprintf('[Worker %d] [INFO] Check Python API server logs for detailed error message\n', labindex);
                end
                rethrow(ME);
            end
            
            % Now run the rest of the pipeline manually
            results = struct();
            results.projectId = projectFile;
            results.firmId = 'firm.json';
            results.mode = mode;
            results.config = config;
            results.startTime = now;
            results.data = analysisData;
            
            % Phase 3: Run MC simulations
            fprintf('[Worker %d] Running Monte Carlo simulations for %s...\n', labindex, projectFile);
            try
                mcResults = runAnalysisPipeline('runMC', analysisData, config);
                results.mcResults = mcResults;
            catch ME
                warning('[Worker %d] MC simulations failed for %s: %s', labindex, projectFile, ME.message);
                results.mcResults = struct();
                mcResults = struct(); % Ensure it's set
            end
            
            % Phase 4: Aggregate results
            fprintf('[Worker %d] Aggregating results for %s...\n', labindex, projectFile);
            try
                stabilityData = runAnalysisPipeline('aggregate', mcResults, config);
                results.stabilityData = stabilityData;
            catch ME
                error('[Worker %d] Failed to aggregate results for %s: %s', labindex, projectFile, ME.message);
            end
            
            results.endTime = now;
            results.duration = toc;
            
            % Store results (use separate arrays for parfor)
            projectFilesOut{i} = projectFile;
            analysesOut{i} = results.data;
            stabilityDataOut{i} = results.stabilityData;
            mcResultsOut{i} = results.mcResults;
            
            % Extract summary metrics
            summary = extractProjectSummary(results);
            summariesOut{i} = summary;
            
            fprintf('[Worker %d] [OK] Project %s processed successfully (%.2f seconds)\n', ...
                labindex, projectFile, results.duration);
            
        catch ME
            warning('[Worker %d] Project %s failed: %s', labindex, projectFile, ME.message);
            fprintf('[Worker %d] [FAILED] Project %s failed\n', labindex, projectFile);
            
            % Store empty results for failed project (use separate arrays for parfor)
            projectFilesOut{i} = projectFile;
            analysesOut{i} = [];
            stabilityDataOut{i} = [];
            mcResultsOut{i} = [];
            summariesOut{i} = struct();
        end
    end
    
    % Reconstruct allResults struct after parfor
    allResults = struct();
    allResults.projects = projectFilesOut;
    allResults.analyses = analysesOut;
    allResults.stabilityData = stabilityDataOut;
    allResults.mcResults = mcResultsOut;
    allResults.summaries = summariesOut;
    
    % Calculate success/fail counts
    successCount = 0;
    failCount = 0;
    for i = 1:nProjects
        if ~isempty(analysesOut{i})
            successCount = successCount + 1;
        else
            failCount = failCount + 1;
        end
    end
    
    totalTime = toc;
    fprintf('\n');
    fprintf('Parallel processing completed in %.2f seconds\n', totalTime);
    fprintf('Average time per project: %.2f seconds\n', totalTime / nProjects);
    
    % Note: We keep the parallel pool open for potential reuse
    % (don't delete it, as it may be used by MC simulations)
    
    % Re-enable warnings
    warning('on', 'parallel:convenience:LocalPoolStartup');
    warning('on', 'parallel:convenience:LocalPoolShutdown');
    
    fprintf('========================================\n');
    fprintf('Processing complete: %d successful, %d failed\n', successCount, failCount);
    fprintf('========================================\n\n');
    
    % Step 6: Create aggregate visualizations
    fprintf('[STEP 6] Creating aggregate visualizations...\n');
    try
        % Option 1: Use the new batch visualization function
        runFlorentVisualizationBatch(allResults, config);
        fprintf('  [OK] Aggregate visualizations created\n');
    catch ME
        warning('Failed to create aggregate visualizations: %s', ME.message);
        % Fallback to old method
        try
            createAggregateVisualizations(allResults, config);
            fprintf('  [OK] Aggregate visualizations created (fallback method)\n');
        catch ME2
            warning('Fallback visualization also failed: %s', ME2.message);
        end
    end
    fprintf('\n');
    
    % Step 7: Display summary statistics
    fprintf('[STEP 7] Summary Statistics\n');
    fprintf('========================================\n');
    displayBatchSummary(allResults);
    fprintf('========================================\n\n');
    
    fprintf('=== BATCH PROCESSING COMPLETE ===\n\n');
end

function summary = extractProjectSummary(results)
    % Extract key metrics from a single project's results
    
    summary = struct();
    summary.projectId = results.projectId;
    summary.firmId = results.firmId;
    
    % Extract from analysis data
    if ~isempty(results.data) && isfield(results.data, 'node_assessments')
        analysis = results.data;
        
        % Node counts
        nodeIds = openapiHelpers('getNodeIds', analysis);
        summary.nNodes = length(nodeIds);
        
        % Average scores
        risk = openapiHelpers('getAllRiskLevels', analysis);
        influence = openapiHelpers('getAllInfluenceScores', analysis);
        summary.avgRisk = mean(risk);
        summary.avgInfluence = mean(influence);
        
        % Summary metrics
        if isfield(analysis, 'summary')
            s = analysis.summary;
            if isfield(s, 'aggregate_project_score')
                summary.aggregateProjectScore = s.aggregate_project_score;
            end
            if isfield(s, 'critical_failure_likelihood')
                summary.criticalFailureLikelihood = s.critical_failure_likelihood;
            end
        end
        
        % Risk assessment confidence (if available)
        if isfield(analysis, 'recommendation')
            rec = analysis.recommendation;
            if isfield(rec, 'confidence')
                summary.assessmentConfidence = rec.confidence;
            end
        end
        
        % Quadrant distribution
        if isfield(analysis, 'matrix_classifications')
            matrix = analysis.matrix_classifications;
            summary.q1Count = countQuadrantNodes(matrix, 'TYPE_A');
            summary.q2Count = countQuadrantNodes(matrix, 'TYPE_B');
            summary.q3Count = countQuadrantNodes(matrix, 'TYPE_C');
            summary.q4Count = countQuadrantNodes(matrix, 'TYPE_D');
        end
    end
    
    % Stability metrics
    if ~isempty(results.stabilityData) && isfield(results.stabilityData, 'overallStability')
        summary.avgStability = mean(results.stabilityData.overallStability);
    end
end

function count = countQuadrantNodes(matrix, quadrantType)
    % Count nodes in a quadrant
    count = 0;
    if isfield(matrix, quadrantType)
        q = matrix.(quadrantType);
        if iscell(q)
            count = length(q);
        elseif isstruct(q)
            count = length(q);
        end
    end
end

function createAggregateVisualizations(allResults, config)
    % Create aggregate visualizations across all projects
    
    fprintf('  Creating aggregate visualizations...\n');
    
    % Filter out failed projects
    validIndices = [];
    for i = 1:length(allResults.analyses)
        if ~isempty(allResults.analyses{i})
            validIndices(end+1) = i;
        end
    end
    
    if isempty(validIndices)
        warning('No valid projects to visualize');
        return;
    end
    
    nValid = length(validIndices);
    fprintf('    Processing %d valid projects for visualization\n', nValid);
    
    % Create figures directory
    figDir = fullfile(pwd, 'MATLAB', 'Figures', 'batch');
    if ~exist(figDir, 'dir')
        mkdir(figDir);
    end
    
    % 1. Aggregate Project Scores Distribution
    fprintf('    - Project Scores Distribution\n');
    try
        scores = [];
        for i = validIndices
            if isfield(allResults.summaries{i}, 'aggregateProjectScore')
                scores(end+1) = allResults.summaries{i}.aggregateProjectScore;
            end
        end
        
        if ~isempty(scores)
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Risk Assessment Score Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            % Modern histogram with gradient colors
            h = histogram(ax, scores, 20, ...
                'FaceColor', [0.2, 0.5, 0.8], ...
                'EdgeColor', [0.1, 0.3, 0.6], ...
                'LineWidth', 1.5, ...
                'FaceAlpha', 0.85);
            
            % Add mean line
            hold(ax, 'on');
            meanScore = mean(scores);
            yLim = ylim(ax);
            plot(ax, [meanScore, meanScore], yLim, 'r--', 'LineWidth', 2.5, ...
                'DisplayName', sprintf('Mean: %.3f', meanScore));
            hold(ax, 'off');
            
            xlabel(ax, 'Risk Assessment Score', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            ylabel(ax, 'Number of Projects', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Risk Assessment Score Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.85, 0.85, 0.85];
            ax.GridAlpha = 0.6;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            
            legend(ax, 'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            savefig(fig, fullfile(figDir, 'aggregate_scores_distribution.fig'));
            % Keep figure open for viewing
            fprintf('      Saved: aggregate_scores_distribution.fig\n');
        end
    catch ME
        warning('Failed to create scores distribution: %s', ME.message);
    end
    
    % 2. Risk vs Influence Scatter (all projects)
    fprintf('    - Risk vs Influence Scatter (All Projects)\n');
    try
        allRisk = [];
        allInfluence = [];
        projectLabels = {};
        projectScores = [];
        
        for i = validIndices
            if isfield(allResults.summaries{i}, 'avgRisk') && ...
               isfield(allResults.summaries{i}, 'avgInfluence')
                allRisk(end+1) = allResults.summaries{i}.avgRisk;
                allInfluence(end+1) = allResults.summaries{i}.avgInfluence;
                projectLabels{end+1} = allResults.projects{i};
                if isfield(allResults.summaries{i}, 'aggregateProjectScore')
                    projectScores(end+1) = allResults.summaries{i}.aggregateProjectScore;
                else
                    projectScores(end+1) = 0.5;
                end
            end
        end
        
        if ~isempty(allRisk)
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Risk vs Influence Analysis');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            % Modern scatter with color-coded scores
            hold(ax, 'on');
            scatter(ax, allRisk, allInfluence, 150, projectScores, 'filled', ...
                'MarkerFaceAlpha', 0.75, 'MarkerEdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 1.5, 'DisplayName', 'Projects');
            colormap(ax, 'viridis');
            c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial', 'Location', 'eastoutside');
            c.Label.String = 'Project Risk Score';
            c.Label.FontSize = 13;
            c.Label.FontWeight = 'bold';
            c.Label.Color = [0.2, 0.2, 0.2];
            c.Color = [0.2, 0.2, 0.2];
            
            % Add quadrant lines (modern style)
            h1 = plot(ax, [0.5, 0.5], [0, 1], '--', 'LineWidth', 2.5, ...
                'Color', [0.6, 0.6, 0.6], 'DisplayName', 'Risk Threshold (0.5)');
            h2 = plot(ax, [0, 1], [0.5, 0.5], '--', 'LineWidth', 2.5, ...
                'Color', [0.6, 0.6, 0.6], 'DisplayName', 'Influence Threshold (0.5)');
            
            % Add quadrant labels
            text(ax, 0.25, 0.75, 'Q1: High Risk\nHigh Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            text(ax, 0.75, 0.75, 'Q2: High Risk\nLow Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            text(ax, 0.25, 0.25, 'Q3: Low Risk\nHigh Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            text(ax, 0.75, 0.25, 'Q4: Low Risk\nLow Influence', ...
                'FontSize', 11, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                'Color', [0.5, 0.5, 0.5], 'HorizontalAlignment', 'center', ...
                'BackgroundColor', [1, 1, 1, 0.8], 'EdgeColor', [0.7, 0.7, 0.7]);
            
            % Add project labels to each point
            for i = 1:length(allRisk)
                % Clean project label
                labelText = projectLabels{i};
                labelText = strrep(labelText, '_', ' ');
                labelText = strrep(labelText, '.json', '');
                labelText = strrep(labelText, 'project ', 'P');
                text(ax, allRisk(i), allInfluence(i) + 0.03, ...
                    labelText, ...
                    'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'bold', ...
                    'Color', [0.2, 0.2, 0.2], ...
                    'HorizontalAlignment', 'center', ...
                    'BackgroundColor', [1, 1, 1, 0.85], ...
                    'EdgeColor', [0.5, 0.5, 0.5], ...
                    'LineWidth', 0.5);
            end
            hold(ax, 'off');
            
            % Set axis labels and properties
            xlabel(ax, 'Average Risk Level', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            ylabel(ax, 'Average Influence Score', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Risk vs Influence: Portfolio Analysis', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            subtitle(ax, 'Quadrant-based risk classification across all projects', ...
                'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
            
            % Set axis properties
            ax.XColor = [0.3, 0.3, 0.3];
            ax.YColor = [0.3, 0.3, 0.3];
            ax.GridColor = [0.9, 0.9, 0.9];
            ax.GridAlpha = 0.8;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            xlim(ax, [0, 1]);
            ylim(ax, [0, 1]);
            
            % Add comprehensive legend
            legend(ax, {'Projects', 'Risk Threshold (0.5)', 'Influence Threshold (0.5)'}, ...
                'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on', ...
                'BackgroundColor', [1, 1, 1, 0.95]);
            
            savefig(fig, fullfile(figDir, 'risk_vs_influence_all_projects.fig'));
            % Keep figure open for viewing
            fprintf('      Saved: risk_vs_influence_all_projects.fig\n');
        end
    catch ME
        warning('Failed to create risk/influence scatter: %s', ME.message);
    end
    
    % 3. Risk Level Distribution (High/Medium/Low Risk Projects)
    fprintf('    - Risk Level Distribution\n');
    try
        highRiskCount = 0;
        mediumRiskCount = 0;
        lowRiskCount = 0;
        
        for i = validIndices
            if isfield(allResults.summaries{i}, 'avgRisk')
                avgRisk = allResults.summaries{i}.avgRisk;
                if avgRisk >= 0.6
                    highRiskCount = highRiskCount + 1;
                elseif avgRisk >= 0.3
                    mediumRiskCount = mediumRiskCount + 1;
                else
                    lowRiskCount = lowRiskCount + 1;
                end
            end
        end
        
        if highRiskCount + mediumRiskCount + lowRiskCount > 0
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Risk Level Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            categories = {'High Risk\n(≥0.6)', 'Medium Risk\n(0.3-0.6)', 'Low Risk\n(<0.3)'};
            counts = [highRiskCount, mediumRiskCount, lowRiskCount];
            
            % Modern bar chart with gradient colors
            colors = [0.85, 0.2, 0.2;  % High risk - red
                      1.0, 0.65, 0.0;  % Medium risk - orange
                      0.2, 0.7, 0.3];   % Low risk - green
            
            b = bar(ax, counts, 'FaceColor', 'flat', 'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2, 'BarWidth', 0.6);
            b.CData = colors;
            
            % Add value labels on bars
            for i = 1:length(counts)
                if counts(i) > 0
                    text(ax, i, counts(i) + 0.5, num2str(counts(i)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 13, ...
                        'FontWeight', 'bold', 'FontName', 'Arial', ...
                        'Color', [0.2, 0.2, 0.2]);
                end
            end
            
            set(ax, 'XTickLabel', categories, 'XTickLabelRotation', 0);
            ylabel(ax, 'Number of Projects', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Risk Level Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.9, 0.9, 0.9];
            ax.GridAlpha = 0.8;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            ylim(ax, [0, max(counts) * 1.2]);
            
            % Add x-axis label
            xlabel(ax, 'Risk Category', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            
            % Add legend for colors
            legend(ax, {'High Risk', 'Medium Risk', 'Low Risk'}, ...
                'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            savefig(fig, fullfile(figDir, 'risk_level_distribution.fig'));
            % Keep figure open for viewing
            fprintf('      Saved: risk_level_distribution.fig\n');
        end
    catch ME
        warning('Failed to create risk level distribution: %s', ME.message);
    end
    
    % 4. Quadrant Distribution Comparison
    fprintf('    - Quadrant Distribution Comparison\n');
    try
        q1Total = 0; q2Total = 0; q3Total = 0; q4Total = 0;
        
        for i = validIndices
            if isfield(allResults.summaries{i}, 'q1Count')
                q1Total = q1Total + allResults.summaries{i}.q1Count;
                q2Total = q2Total + allResults.summaries{i}.q2Count;
                q3Total = q3Total + allResults.summaries{i}.q3Count;
                q4Total = q4Total + allResults.summaries{i}.q4Count;
            end
        end
        
        if q1Total + q2Total + q3Total + q4Total > 0
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Quadrant Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            categories = {'Q1: Mitigate\n(High Risk/High Influence)', ...
                         'Q2: Automate\n(High Risk/Low Influence)', ...
                         'Q3: Contingency\n(Low Risk/High Influence)', ...
                         'Q4: Delegate\n(Low Risk/Low Influence)'};
            counts = [q1Total, q2Total, q3Total, q4Total];
            
            % Modern color scheme for quadrants
            colors = [0.9, 0.2, 0.2;   % Q1 - Red (high risk, high influence)
                      1.0, 0.5, 0.0;   % Q2 - Orange (high risk, low influence)
                      0.2, 0.6, 0.9;   % Q3 - Blue (low risk, high influence)
                      0.5, 0.5, 0.5];  % Q4 - Gray (low risk, low influence)
            
            b = bar(ax, counts, 'FaceColor', 'flat', 'EdgeColor', [0.3, 0.3, 0.3], ...
                'LineWidth', 2, 'BarWidth', 0.7);
            b.CData = colors;
            
            % Add value labels
            for i = 1:length(counts)
                if counts(i) > 0
                    text(ax, i, counts(i) + max(counts)*0.02, num2str(counts(i)), ...
                        'HorizontalAlignment', 'center', 'FontSize', 13, ...
                        'FontWeight', 'bold', 'FontName', 'Arial', ...
                        'Color', [0.2, 0.2, 0.2]);
                end
            end
            
            set(ax, 'XTickLabel', categories, 'XTickLabelRotation', 0);
            ylabel(ax, 'Total Nodes Across All Projects', 'FontSize', 15, ...
                'FontWeight', 'bold', 'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Aggregate Quadrant Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.9, 0.9, 0.9];
            ax.GridAlpha = 0.8;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            ylim(ax, [0, max(counts) * 1.15]);
            
            % Add x-axis label
            xlabel(ax, 'Quadrant Category', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            
            % Add legend
            legend(ax, {'Q1: Mitigate', 'Q2: Automate', 'Q3: Contingency', 'Q4: Delegate'}, ...
                'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            savefig(fig, fullfile(figDir, 'quadrant_distribution_aggregate.fig'));
            % Keep figure open for viewing
            fprintf('      Saved: quadrant_distribution_aggregate.fig\n');
        end
    catch ME
        warning('Failed to create quadrant distribution: %s', ME.message);
    end
    
    % 5. Critical Failure Likelihood Distribution
    fprintf('    - Critical Failure Likelihood Distribution\n');
    try
        failureLikelihoods = [];
        for i = validIndices
            if isfield(allResults.summaries{i}, 'criticalFailureLikelihood')
                failureLikelihoods(end+1) = allResults.summaries{i}.criticalFailureLikelihood;
            end
        end
        
        if ~isempty(failureLikelihoods)
            fig = figure('Position', [100, 100, 1400, 900], ...
                'Color', 'white', 'Name', 'Critical Failure Likelihood Distribution');
            ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12);
            
            % Modern histogram with gradient
            h = histogram(ax, failureLikelihoods, 20, ...
                'FaceColor', [0.85, 0.25, 0.25], ...
                'EdgeColor', [0.6, 0.1, 0.1], ...
                'LineWidth', 1.5, ...
                'FaceAlpha', 0.85);
            
            % Add mean and median lines
            hold(ax, 'on');
            meanLikelihood = mean(failureLikelihoods);
            medianLikelihood = median(failureLikelihoods);
            yLim = ylim(ax);
            plot(ax, [meanLikelihood, meanLikelihood], yLim, 'r--', 'LineWidth', 2.5, ...
                'DisplayName', sprintf('Mean: %.3f', meanLikelihood));
            plot(ax, [medianLikelihood, medianLikelihood], yLim, 'b--', 'LineWidth', 2.5, ...
                'DisplayName', sprintf('Median: %.3f', medianLikelihood));
            hold(ax, 'off');
            
            xlabel(ax, 'Critical Failure Likelihood', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            ylabel(ax, 'Number of Projects', 'FontSize', 15, 'FontWeight', 'bold', ...
                'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
            title(ax, 'Critical Failure Likelihood Distribution', ...
                'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
                'Color', [0.15, 0.15, 0.15]);
            
            ax.GridColor = [0.85, 0.85, 0.85];
            ax.GridAlpha = 0.6;
            ax.GridLineStyle = '-';
            grid(ax, 'on');
            ax.Box = 'on';
            ax.LineWidth = 1.5;
            
            legend(ax, 'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
                'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on');
            
            savefig(fig, fullfile(figDir, 'failure_likelihood_distribution.fig'));
            % Keep figure open for viewing
            fprintf('      Saved: failure_likelihood_distribution.fig\n');
        end
    catch ME
        warning('Failed to create failure likelihood distribution: %s', ME.message);
    end
    
    % 6. 3D Risk Landscape
    fprintf('    - 3D Risk Landscape\n');
    try
        plot3DRiskLandscape(allResults, validIndices, figDir);
        fprintf('      Saved: 3d_risk_landscape.fig\n');
    catch ME
        warning('Failed to create 3D risk landscape: %s', ME.message);
    end
    
    % 7. Monte Carlo Uncertainty Fan
    fprintf('    - Monte Carlo Uncertainty Fan\n');
    try
        plotMCUncertaintyFan(allResults, validIndices, figDir);
        fprintf('      Saved: mc_uncertainty_fan.fig\n');
    catch ME
        warning('Failed to create MC uncertainty fan: %s', ME.message);
    end
    
    % 8. Parameter Sensitivity Heatmap (aggregate across projects)
    fprintf('    - Parameter Sensitivity Heatmap\n');
    try
        plotParameterSensitivityAggregate(allResults, validIndices, figDir);
        fprintf('      Saved: parameter_sensitivity_heatmap_aggregate.fig\n');
    catch ME
        warning('Failed to create parameter sensitivity heatmap: %s', ME.message);
    end
    
    fprintf('  [OK] All aggregate visualizations saved to: %s\n', figDir);
end

function plot3DRiskLandscape(allResults, validIndices, figDir)
    % PLOT3DRISKLANDSCAPE Create a 3D topographical map of risk
    %
    % Creates a 3D surface where:
    % - X-axis: Influence score
    % - Y-axis: Project index / complexity
    % - Z-axis: Risk level (peaks = high risk, valleys = low risk)
    % - Surface interpolated using griddata
    % - Colormap: hot (burning peaks effect)
    % - Shows "ball rolling" concept with local minima/maxima markers
    
    nValid = length(validIndices);
    if nValid < 3
        warning('Need at least 3 projects for 3D landscape visualization');
        return;
    end
    
    % Extract data points
    xData = []; % Influence
    yData = []; % Project complexity/index
    zData = []; % Risk
    projectLabels = {};
    
    for idx = 1:nValid
        i = validIndices(idx);
        if ~isempty(allResults.summaries{i})
            summary = allResults.summaries{i};
            
            % Get influence and risk
            if isfield(summary, 'avgInfluence') && isfield(summary, 'avgRisk')
                influence = summary.avgInfluence;
                risk = summary.avgRisk;
                
                % Use project complexity or index for Y-axis
                if isfield(summary, 'nNodes')
                    complexity = summary.nNodes;
                else
                    complexity = idx; % Fallback to index
                end
                
                xData(end+1) = influence;
                yData(end+1) = complexity;
                zData(end+1) = risk;
                % Clean project name for labeling
                projName = allResults.projects{i};
                projName = strrep(projName, '_', ' ');
                projName = strrep(projName, '.json', '');
                projName = strrep(projName, 'project ', 'P');
                projectLabels{end+1} = projName;
            end
        end
    end
    
    if length(xData) < 3
        warning('Insufficient data points for 3D landscape');
        return;
    end
    
    % Create interpolation grid
    xMin = min(xData); xMax = max(xData);
    yMin = min(yData); yMax = max(yData);
    
    % Expand grid slightly for better visualization
    xRange = xMax - xMin;
    yRange = yMax - yMin;
    xMin = xMin - 0.1 * xRange;
    xMax = xMax + 0.1 * xRange;
    yMin = yMin - 0.1 * yRange;
    yMax = yMax + 0.1 * yRange;
    
    % Create fine grid for smooth surface
    gridRes = 50;
    xi = linspace(xMin, xMax, gridRes);
    yi = linspace(yMin, yMax, gridRes);
    [XI, YI] = meshgrid(xi, yi);
    
    % Interpolate using griddata (cubic interpolation for smooth surface)
    try
        ZI = griddata(xData, yData, zData, XI, YI, 'cubic');
        
        % Fill NaN values (extrapolation regions) with nearest neighbor
        nanMask = isnan(ZI);
        if any(nanMask(:))
            ZI(nanMask) = griddata(xData, yData, zData, XI(nanMask), YI(nanMask), 'nearest');
        end
    catch
        % Fallback to linear interpolation if cubic fails
        ZI = griddata(xData, yData, zData, XI, YI, 'linear');
        nanMask = isnan(ZI);
        if any(nanMask(:))
            ZI(nanMask) = griddata(xData, yData, zData, XI(nanMask), YI(nanMask), 'nearest');
        end
    end
    
    % Create figure with modern styling
    fig = figure('Position', [100, 100, 1600, 1200], ...
        'Name', '3D Risk Landscape - Topographical Risk Map', ...
        'Color', 'white');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    
    % Create 3D surface with modern styling
    surf(ax, XI, YI, ZI, 'EdgeColor', 'none', 'FaceColor', 'interp', ...
        'FaceAlpha', 0.85, 'FaceLighting', 'gouraud');
    
    % Apply modern colormap
    colormap(ax, 'viridis');
    c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial');
    c.Label.String = 'Risk Level';
    c.Label.FontSize = 13;
    c.Label.FontWeight = 'bold';
    c.Label.Color = [0.2, 0.2, 0.2];
    c.Color = [0.2, 0.2, 0.2];
    
    % Add modern lighting for 3D effect
    light(ax, 'Position', [1, 1, 1], 'Style', 'infinite', 'Color', [1, 1, 1]);
    light(ax, 'Position', [-1, -1, 0.5], 'Style', 'infinite', 'Color', [0.8, 0.8, 0.9]);
    lighting(ax, 'gouraud');
    material(ax, 'shiny');
    
    % Add original data points as markers with modern styling
    hold(ax, 'on');
    scatter3(ax, xData, yData, zData, 140, zData, 'filled', ...
        'MarkerEdgeColor', [0.3, 0.3, 0.3], 'LineWidth', 1.5, ...
        'MarkerFaceAlpha', 0.85);
    
    % Find local minima and maxima (where ball would get stuck)
    % Local minima = stable low-risk zones (valleys)
    % Local maxima = volatile high-risk zones (peaks)
    
    % Find peaks (local maxima) - high risk zones
    [peaks, peakLocs] = findpeaks2D(ZI);
    if ~isempty(peaks)
        peakX = XI(peakLocs);
        peakY = YI(peakLocs);
        peakZ = peaks;
        % Only show significant peaks (above median)
        medianZ = median(ZI(:));
        significantPeaks = peakZ > medianZ;
        if any(significantPeaks)
            scatter3(ax, peakX(significantPeaks), peakY(significantPeaks), ...
                peakZ(significantPeaks), 320, [0.85, 0.2, 0.2], '^', 'filled', ...
                'MarkerEdgeColor', [0.5, 0.1, 0.1], 'LineWidth', 2.5, ...
                'DisplayName', 'High-Risk Peaks');
        end
    end
    
    % Find valleys (local minima) - stable zones
    [valleys, valleyLocs] = findpeaks2D(-ZI); % Invert to find minima
    if ~isempty(valleys)
        valleyX = XI(valleyLocs);
        valleyY = YI(valleyLocs);
        valleyZ = -valleys; % Invert back
        % Only show significant valleys (below median)
        significantValleys = valleyZ < medianZ;
        if any(significantValleys)
            scatter3(ax, valleyX(significantValleys), valleyY(significantValleys), ...
                valleyZ(significantValleys), 320, [0.2, 0.7, 0.3], 'v', 'filled', ...
                'MarkerEdgeColor', [0.1, 0.5, 0.1], 'LineWidth', 2.5, ...
                'DisplayName', 'Stable Valleys');
        end
    end
    
    % Add labels for data points with project names
    for i = 1:length(xData)
        % Get project name if available
        if i <= length(projectLabels) && ~isempty(projectLabels{i})
            labelText = strrep(projectLabels{i}, '_', ' ');
            labelText = strrep(labelText, '.json', '');
        else
            labelText = sprintf('P%d', i);
        end
        text(ax, xData(i), yData(i), zData(i) + 0.05, ...
            labelText, ...
            'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold', ...
            'Color', [0.2, 0.2, 0.2], ...
            'HorizontalAlignment', 'center', ...
            'BackgroundColor', [1, 1, 1, 0.85], ...
            'EdgeColor', [0.5, 0.5, 0.5], ...
            'LineWidth', 1);
    end
    
    hold(ax, 'off');
    
    % Labels and title with modern styling
    xlabel(ax, 'Influence Score', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Project Complexity (Node Count)', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    zlabel(ax, 'Risk Level', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, '3D Risk Landscape: Topographical Risk Map', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, 'Peaks = High Risk Zones | Valleys = Stable Zones', ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    % Set axis properties with modern styling
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.ZColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.85, 0.85, 0.85];
    ax.GridAlpha = 0.5;
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    
    % Set view angle for best visualization
    view(ax, 45, 30);
    
    % Add legend
    legendEntries = {};
    if exist('significantPeaks', 'var') && any(significantPeaks)
        legendEntries{end+1} = 'High-Risk Peaks';
    end
    if exist('significantValleys', 'var') && any(significantValleys)
        legendEntries{end+1} = 'Stable Valleys';
    end
    if ~isempty(legendEntries)
        legend(ax, legendEntries, 'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
            'TextColor', [0.2, 0.2, 0.2], 'EdgeColor', [0.7, 0.7, 0.7], ...
            'Box', 'on', 'BackgroundColor', [1, 1, 1, 0.95]);
    end
    
    % Save figure
    savefig(fig, fullfile(figDir, '3d_risk_landscape.fig'));
    % Keep figure open for viewing
end

function [peaks, locs] = findpeaks2D(Z)
    % FINDPEAKS2D Find local maxima in 2D matrix
    % Simple implementation: a point is a peak if it's greater than its 8 neighbors
    
    [m, n] = size(Z);
    peaks = [];
    locs = [];
    
    for i = 2:(m-1)
        for j = 2:(n-1)
            center = Z(i, j);
            neighbors = [
                Z(i-1, j-1), Z(i-1, j), Z(i-1, j+1);
                Z(i, j-1),              Z(i, j+1);
                Z(i+1, j-1), Z(i+1, j), Z(i+1, j+1)
            ];
            
            if center > max(neighbors(:))
                peaks(end+1) = center;
                locs(end+1, :) = [i, j];
            end
        end
    end
end

function plotMCUncertaintyFan(allResults, validIndices, figDir)
    % PLOTMCUNCERTAINTYFAN Create uncertainty fan plot from Monte Carlo results
    %
    % Creates an area plot showing:
    % - Central line: Expected/median risk
    % - Shaded areas: Confidence intervals (5th-95th, 25th-75th percentiles)
    % - Uses fill() for shaded confidence intervals
    % - Uses plot() for the median line
    % - Glowing semi-transparent clouds effect
    
    nValid = length(validIndices);
    if nValid < 2
        warning('Need at least 2 projects for uncertainty fan visualization');
        return;
    end
    
    % Collect MC results across all projects
    projectIndices = [];
    meanRisks = [];
    stdDevRisks = [];
    projectNames = {};
    
    for idx = 1:nValid
        i = validIndices(idx);
        if ~isempty(allResults.mcResults{i})
            mcResults = allResults.mcResults{i};
            
            % Try to get mean and stdDev from MC results
            % Check different possible structures
            meanRisk = [];
            stdDevRisk = [];
            
            % Check if we have aggregated results with meanScores
            if isfield(mcResults, 'parameterSensitivity') && ...
               isfield(mcResults.parameterSensitivity, 'meanScores')
                meanRisk = mean(mcResults.parameterSensitivity.meanScores.risk);
                if isfield(mcResults.parameterSensitivity, 'stdDev')
                    stdDevRisk = mean(mcResults.parameterSensitivity.stdDev.risk);
                end
            elseif isfield(mcResults, 'failureProbDist') && ...
                   isfield(mcResults.failureProbDist, 'meanScores')
                meanRisk = mean(mcResults.failureProbDist.meanScores.risk);
                if isfield(mcResults.failureProbDist, 'stdDev')
                    stdDevRisk = mean(mcResults.failureProbDist.stdDev.risk);
                end
            elseif isfield(mcResults, 'meanScores')
                meanRisk = mean(mcResults.meanScores.risk);
                if isfield(mcResults, 'stdDev')
                    stdDevRisk = mean(mcResults.stdDev.risk);
                end
            end
            
            % Fallback: use summary statistics if MC results not available
            if isempty(meanRisk) && ~isempty(allResults.summaries{i})
                summary = allResults.summaries{i};
                if isfield(summary, 'avgRisk')
                    meanRisk = summary.avgRisk;
                    % Estimate stdDev from variance if available
                    if isfield(summary, 'avgStability')
                        % Use stability as proxy for uncertainty
                        stdDevRisk = (1 - summary.avgStability) * 0.3; % Rough estimate
                    else
                        stdDevRisk = 0.1; % Default uncertainty
                    end
                end
            end
            
            if ~isempty(meanRisk)
                projectIndices(end+1) = idx;
                meanRisks(end+1) = meanRisk;
                stdDevRisks(end+1) = stdDevRisk;
                projectNames{end+1} = allResults.projects{i};
            end
        end
    end
    
    if length(meanRisks) < 2
        warning('Insufficient MC data for uncertainty fan visualization');
        return;
    end
    
    % Sort by project index for sequential display
    [~, sortIdx] = sort(projectIndices);
    meanRisks = meanRisks(sortIdx);
    stdDevRisks = stdDevRisks(sortIdx);
    projectNames = projectNames(sortIdx);
    xAxis = 1:length(meanRisks);
    
    % Calculate percentiles using normal approximation
    % p5 = mean - 1.645*std, p25 = mean - 0.674*std, etc.
    p5 = meanRisks - 1.645 * stdDevRisks;   % 5th percentile
    p25 = meanRisks - 0.674 * stdDevRisks;  % 25th percentile
    p50 = meanRisks;                         % 50th percentile (median = mean for normal)
    p75 = meanRisks + 0.674 * stdDevRisks;  % 75th percentile
    p95 = meanRisks + 1.645 * stdDevRisks;  % 95th percentile
    
    % Ensure percentiles are within [0, 1] range
    p5 = max(0, min(1, p5));
    p25 = max(0, min(1, p25));
    p50 = max(0, min(1, p50));
    p75 = max(0, min(1, p75));
    p95 = max(0, min(1, p95));
    
    % Create figure with modern styling
    fig = figure('Position', [100, 100, 1600, 1000], ...
        'Name', 'Monte Carlo Uncertainty Fan - Risk Confidence Intervals', ...
        'Color', 'white');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    hold(ax, 'on');
    
    % Plot outer confidence interval (5th-95th percentile) - largest cloud
    xFill = [xAxis, fliplr(xAxis)];
    yFill95 = [p5, fliplr(p95)];
    fill(ax, xFill, yFill95, [0.95, 0.6, 0.3], ...
        'FaceAlpha', 0.25, ...
        'EdgeColor', 'none', ...
        'DisplayName', '90% Confidence Interval (5th-95th percentile)');
    
    % Plot inner confidence interval (25th-75th percentile) - inner cloud
    yFill75 = [p25, fliplr(p75)];
    fill(ax, xFill, yFill75, [0.95, 0.75, 0.5], ...
        'FaceAlpha', 0.45, ...
        'EdgeColor', 'none', ...
        'DisplayName', '50% Confidence Interval (25th-75th percentile)');
    
    % Plot median/expected line (central line) with modern styling
    plot(ax, xAxis, p50, '-', 'LineWidth', 3.5, ...
        'Color', [0.2, 0.4, 0.8], ...
        'DisplayName', 'Expected Risk (Median)', ...
        'Marker', 'o', 'MarkerSize', 10, ...
        'MarkerFaceColor', [0.2, 0.4, 0.8], ...
        'MarkerEdgeColor', [0.1, 0.2, 0.5], ...
        'MarkerEdgeWidth', 1.5);
    
    % Add subtle glow effect to central line
    for glow = 1:2
        plot(ax, xAxis, p50, '-', 'LineWidth', 3.5 + glow*1.5, ...
            'Color', [0.2, 0.4, 0.8, 0.15], ...
            'HandleVisibility', 'off');
    end
    
    % Add data point markers with modern styling
    scatter(ax, xAxis, meanRisks, 120, meanRisks, 'filled', ...
        'MarkerEdgeColor', [0.3, 0.3, 0.3], 'LineWidth', 1.5, ...
        'MarkerFaceAlpha', 0.85, ...
        'HandleVisibility', 'off');
    
    % Add project labels with project names
    for i = 1:length(xAxis)
        % Get project name
        if i <= length(projectNames) && ~isempty(projectNames{i})
            labelText = strrep(projectNames{i}, '_', ' ');
            labelText = strrep(labelText, '.json', '');
            labelText = strrep(labelText, 'project ', 'P');
        else
            labelText = sprintf('P%d', i);
        end
        text(ax, xAxis(i), p95(i) + 0.03, ...
            labelText, ...
            'FontSize', 10, 'FontName', 'Arial', ...
            'Color', [0.2, 0.2, 0.2], ...
            'HorizontalAlignment', 'center', ...
            'Rotation', 45, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', [1, 1, 1, 0.8], ...
            'EdgeColor', [0.5, 0.5, 0.5], ...
            'LineWidth', 0.5);
    end
    
    % Add value labels on the central line
    for i = 1:length(xAxis)
        text(ax, xAxis(i), p50(i) - 0.05, ...
            sprintf('%.2f', p50(i)), ...
            'FontSize', 9, 'FontName', 'Arial', ...
            'Color', [0.2, 0.4, 0.8], ...
            'HorizontalAlignment', 'center', ...
            'FontWeight', 'bold', ...
            'BackgroundColor', [1, 1, 1, 0.7]);
    end
    
    hold(ax, 'off');
    
    % Modern formatting with proper labels
    xlabel(ax, 'Project Index', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Risk Level', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, 'Monte Carlo Uncertainty Fan: Risk Confidence Intervals', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, 'Central line = Expected Risk | Shaded areas = Confidence intervals', ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    % Set axis properties with modern styling
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.9, 0.9, 0.9];
    ax.GridAlpha = 0.6;
    ax.GridLineStyle = '-';
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    xlim(ax, [0.5, length(xAxis) + 0.5]);
    ylim(ax, [0, 1]);
    
    % Add modern legend
    legend(ax, 'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
        'TextColor', [0.2, 0.2, 0.2], 'EdgeColor', [0.7, 0.7, 0.7], ...
        'Box', 'on', 'BackgroundColor', [1, 1, 1, 0.95]);
    
    % Add modern colorbar
    colormap(ax, 'viridis');
    c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial');
    c.Label.String = 'Risk Level';
    c.Label.FontSize = 13;
    c.Label.FontWeight = 'bold';
    c.Label.Color = [0.2, 0.2, 0.2];
    c.Color = [0.2, 0.2, 0.2];
    caxis(ax, [0, 1]);
    
    % Save figure
    savefig(fig, fullfile(figDir, 'mc_uncertainty_fan.fig'));
    % Keep figure open for viewing
end

function plotParameterSensitivityAggregate(allResults, validIndices, figDir)
    % PLOTPARAMETERSENSITIVITYAGGREGATE Creates aggregate parameter sensitivity heatmap
    %
    % Aggregates sensitivity data across all projects and creates a heatmap
    % showing which parameters are most sensitive across the portfolio
    
    nValid = length(validIndices);
    if nValid < 1
        warning('No valid projects for parameter sensitivity visualization');
        return;
    end
    
    % Collect sensitivity matrices from all projects
    allSensitivityMatrices = [];
    projectNames = {};
    paramNames = {'Attenuation Factor', 'Risk Multiplier', 'Alignment Weights'};
    
    for idx = 1:nValid
        i = validIndices(idx);
        if ~isempty(allResults.mcResults{i}) && ...
           isfield(allResults.mcResults{i}, 'parameterSensitivity') && ...
           isfield(allResults.mcResults{i}.parameterSensitivity, 'sensitivityMatrix')
            
            sens = allResults.mcResults{i}.parameterSensitivity.sensitivityMatrix;
            if isfield(sens, 'attenuation_factor') && ...
               isfield(sens, 'risk_multiplier') && ...
               isfield(sens, 'alignment_weights')
                
                % Build sensitivity matrix for this project
                sensMatrix = [
                    sens.attenuation_factor';
                    sens.risk_multiplier';
                    sens.alignment_weights';
                ];
                
                % Aggregate by taking mean across all projects
                if isempty(allSensitivityMatrices)
                    allSensitivityMatrices = sensMatrix;
                else
                    % Average with existing matrix
                    [nParams, nNodes] = size(sensMatrix);
                    [nParamsExisting, nNodesExisting] = size(allSensitivityMatrices);
                    
                    % Handle different node counts by padding or truncating
                    if nNodes == nNodesExisting
                        allSensitivityMatrices = (allSensitivityMatrices + sensMatrix) / 2;
                    elseif nNodes < nNodesExisting
                        % Pad with zeros
                        padded = [sensMatrix, zeros(nParams, nNodesExisting - nNodes)];
                        allSensitivityMatrices = (allSensitivityMatrices + padded) / 2;
                    else
                        % Truncate existing
                        allSensitivityMatrices = (allSensitivityMatrices(:, 1:nNodes) + sensMatrix) / 2;
                    end
                end
                
                % Store project name
                projName = allResults.projects{i};
                projName = strrep(projName, '_', ' ');
                projName = strrep(projName, '.json', '');
                projectNames{end+1} = projName;
            end
        end
    end
    
    if isempty(allSensitivityMatrices)
        warning('No parameter sensitivity data found for visualization');
        return;
    end
    
    % Create figure with modern styling
    fig = figure('Position', [100, 100, 1600, 800], ...
        'Color', 'white', 'Name', 'Parameter Sensitivity Heatmap - Aggregate');
    ax = axes('Parent', fig, 'FontName', 'Arial', 'FontSize', 12, 'Color', 'white');
    
    % Create heatmap with modern colormap
    imagesc(ax, allSensitivityMatrices);
    colormap(ax, 'viridis');
    c = colorbar(ax, 'FontSize', 11, 'FontName', 'Arial', 'Location', 'eastoutside');
    c.Label.String = 'Average Sensitivity Magnitude';
    c.Label.FontSize = 13;
    c.Label.FontWeight = 'bold';
    c.Label.Color = [0.2, 0.2, 0.2];
    c.Color = [0.2, 0.2, 0.2];
    caxis(ax, [0, max(allSensitivityMatrices(:))]);
    
    % Set axis labels
    nNodes = size(allSensitivityMatrices, 2);
    set(ax, 'XTick', 1:nNodes);
    set(ax, 'XTickLabel', arrayfun(@(x) sprintf('Node %d', x), 1:nNodes, 'UniformOutput', false));
    set(ax, 'XTickLabelRotation', 45);
    set(ax, 'YTick', 1:length(paramNames));
    set(ax, 'YTickLabel', paramNames);
    
    xlabel(ax, 'Nodes (Aggregated Across Projects)', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    ylabel(ax, 'Parameters', 'FontSize', 15, 'FontWeight', 'bold', ...
        'FontName', 'Arial', 'Color', [0.2, 0.2, 0.2]);
    title(ax, 'Parameter Sensitivity Heatmap: Portfolio Aggregate', ...
        'FontSize', 18, 'FontWeight', 'bold', 'FontName', 'Arial', ...
        'Color', [0.15, 0.15, 0.15]);
    subtitle(ax, sprintf('Average sensitivity across %d projects', length(projectNames)), ...
        'FontSize', 12, 'FontName', 'Arial', 'Color', [0.4, 0.4, 0.4]);
    
    % Set axis properties
    ax.XColor = [0.3, 0.3, 0.3];
    ax.YColor = [0.3, 0.3, 0.3];
    ax.GridColor = [0.9, 0.9, 0.9];
    ax.GridAlpha = 0.5;
    ax.LineWidth = 1.5;
    grid(ax, 'on');
    ax.Box = 'on';
    
    % Add contour lines for sensitivity thresholds
    hold(ax, 'on');
    threshold75 = prctile(allSensitivityMatrices(:), 75);
    threshold90 = prctile(allSensitivityMatrices(:), 90);
    
    % Plot 75th percentile threshold
    [C75, h75] = contour(ax, allSensitivityMatrices, [threshold75, threshold75], ...
        'LineColor', [0.2, 0.6, 0.9], 'LineWidth', 2, 'LineStyle', '--');
    clabel(C75, h75, 'FontSize', 10, 'FontName', 'Arial', 'Color', [0.2, 0.6, 0.9], ...
        'FontWeight', 'bold', 'LabelSpacing', 200);
    
    % Plot 90th percentile threshold
    [C90, h90] = contour(ax, allSensitivityMatrices, [threshold90, threshold90], ...
        'LineColor', [0.9, 0.2, 0.2], 'LineWidth', 2.5, 'LineStyle', '-');
    clabel(C90, h90, 'FontSize', 10, 'FontName', 'Arial', 'Color', [0.9, 0.2, 0.2], ...
        'FontWeight', 'bold', 'LabelSpacing', 200);
    hold(ax, 'off');
    
    % Add text annotations for high sensitivity regions
    [highSensRows, highSensCols] = find(allSensitivityMatrices >= threshold90);
    if ~isempty(highSensRows)
        hold(ax, 'on');
        for i = 1:min(length(highSensRows), 20) % Limit annotations
            text(ax, highSensCols(i), highSensRows(i), '★', ...
                'Color', [1, 0.8, 0], 'FontSize', 14, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
        end
        hold(ax, 'off');
    end
    
    % Add legend
    legendEntries = {};
    legendHandles = [];
    if ~isempty(highSensRows)
        hStar = plot(ax, NaN, NaN, 'w*', 'MarkerSize', 14, ...
            'MarkerFaceColor', [1, 0.8, 0], 'MarkerEdgeColor', [1, 0.8, 0], ...
            'LineWidth', 2);
        legendEntries{end+1} = 'High Sensitivity (≥90th percentile)';
        legendHandles(end+1) = hStar;
    end
    h75_legend = plot(ax, NaN, NaN, '--', 'Color', [0.2, 0.6, 0.9], 'LineWidth', 2);
    legendEntries{end+1} = '75th Percentile Threshold';
    legendHandles(end+1) = h75_legend;
    h90_legend = plot(ax, NaN, NaN, '-', 'Color', [0.9, 0.2, 0.2], 'LineWidth', 2.5);
    legendEntries{end+1} = '90th Percentile Threshold';
    legendHandles(end+1) = h90_legend;
    
    legend(ax, legendHandles, legendEntries, ...
        'Location', 'best', 'FontSize', 11, 'FontName', 'Arial', ...
        'EdgeColor', [0.7, 0.7, 0.7], 'Box', 'on', ...
        'BackgroundColor', [1, 1, 1, 0.95], 'TextColor', [0.2, 0.2, 0.2]);
    
    % Add summary statistics
    meanSens = mean(allSensitivityMatrices(:));
    maxSens = max(allSensitivityMatrices(:));
    minSens = min(allSensitivityMatrices(:));
    stdSens = std(allSensitivityMatrices(:));
    
    summaryText = sprintf('Portfolio Summary:\nMean: %.4f\nMax: %.4f\nMin: %.4f\nStd: %.4f\n\nProjects: %d', ...
        meanSens, maxSens, minSens, stdSens, length(projectNames));
    
    text(ax, 0.02, 0.98, summaryText, ...
        'Units', 'normalized', ...
        'FontSize', 10, 'FontName', 'Arial', ...
        'Color', [0.2, 0.2, 0.2], ...
        'VerticalAlignment', 'top', ...
        'HorizontalAlignment', 'left', ...
        'BackgroundColor', [1, 1, 1, 0.9], ...
        'EdgeColor', [0.5, 0.5, 0.5], ...
        'LineWidth', 1, ...
        'Margin', 5);
    
    % Save figure
    savefig(fig, fullfile(figDir, 'parameter_sensitivity_heatmap_aggregate.fig'));
    % Keep figure open for viewing
end

function displayBatchSummary(allResults)
    % Display summary statistics across all projects
    
    % Filter valid projects
    validIndices = [];
    for i = 1:length(allResults.analyses)
        if ~isempty(allResults.analyses{i})
            validIndices(end+1) = i;
        end
    end
    
    nValid = length(validIndices);
    fprintf('Total Projects Processed: %d\n', length(allResults.projects));
    fprintf('Successful: %d\n', nValid);
    fprintf('Failed: %d\n', length(allResults.projects) - nValid);
    fprintf('\n');
    
    if nValid == 0
        fprintf('No valid projects to summarize\n');
        return;
    end
    
    % Aggregate statistics
    totalNodes = 0;
    avgRisks = [];
    avgInfluences = [];
    projectScores = [];
    failureLikelihoods = [];
    
    for i = validIndices
        s = allResults.summaries{i};
        if isfield(s, 'nNodes')
            totalNodes = totalNodes + s.nNodes;
        end
        if isfield(s, 'avgRisk')
            avgRisks(end+1) = s.avgRisk;
        end
        if isfield(s, 'avgInfluence')
            avgInfluences(end+1) = s.avgInfluence;
        end
        if isfield(s, 'aggregateProjectScore')
            projectScores(end+1) = s.aggregateProjectScore;
        end
        if isfield(s, 'criticalFailureLikelihood')
            failureLikelihoods(end+1) = s.criticalFailureLikelihood;
        end
    end
    
    fprintf('--- Aggregate Statistics ---\n');
    fprintf('Total Nodes (all projects): %d\n', totalNodes);
    fprintf('Average Nodes per Project: %.1f\n', totalNodes / nValid);
    
    if ~isempty(avgRisks)
        fprintf('Average Risk (across projects): %.3f\n', mean(avgRisks));
        fprintf('Risk Range: [%.3f, %.3f]\n', min(avgRisks), max(avgRisks));
    end
    
    if ~isempty(avgInfluences)
        fprintf('Average Influence (across projects): %.3f\n', mean(avgInfluences));
        fprintf('Influence Range: [%.3f, %.3f]\n', min(avgInfluences), max(avgInfluences));
    end
    
    if ~isempty(projectScores)
        fprintf('Average Risk Assessment Score: %.3f\n', mean(projectScores));
        fprintf('Score Range: [%.3f, %.3f]\n', min(projectScores), max(projectScores));
    end
    
    if ~isempty(failureLikelihoods)
        fprintf('Average Failure Likelihood: %.3f\n', mean(failureLikelihoods));
        fprintf('Failure Likelihood Range: [%.3f, %.3f]\n', min(failureLikelihoods), max(failureLikelihoods));
    end
    
    % Risk assessment summary
    if ~isempty(avgRisks)
        highRiskProjects = sum(avgRisks >= 0.6);
        fprintf('High Risk Projects (≥0.6): %d/%d (%.1f%%)\n', ...
            highRiskProjects, nValid, 100*highRiskProjects/nValid);
    end
end

