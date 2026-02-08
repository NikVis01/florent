function varargout = runAnalysisPipeline(operation, varargin)
    % RUNANALYSISPIPELINE Modular pipeline components for Florent analysis
    %
    % Usage:
    %   data = runAnalysisPipeline('loadData', config, projectId, firmId)
    %   results = runAnalysisPipeline('runMC', data, config)
    %   stabilityData = runAnalysisPipeline('aggregate', results, config)
    %   figs = runAnalysisPipeline('visualize', data, stabilityData, config)
    %   dashboard = runAnalysisPipeline('dashboard', data, stabilityData, figs, config)
    %   runAnalysisPipeline('export', dashboard, config)
    %
    % Operations:
    %   'loadData' - Load and validate analysis data
    %   'runMC' - Run Monte Carlo simulations
    %   'aggregate' - Aggregate MC results
    %   'visualize' - Generate all visualizations
    %   'dashboard' - Create comprehensive dashboard
    %   'export' - Export reports
    
    operation = lower(operation);
    
    switch operation
        case 'loaddata'
            if nargin < 3
                error('loadData requires config, projectId, and firmId');
            end
            varargout{1} = loadAnalysisData(varargin{1}, varargin{2}, varargin{3});
            
        case 'runmc'
            if nargin < 2
                error('runMC requires data and config');
            end
            varargout{1} = runMCSimulations(varargin{1}, varargin{2});
            
        case 'aggregate'
            if nargin < 2
                error('aggregate requires results and config');
            end
            varargout{1} = aggregateResults(varargin{1}, varargin{2});
            
        case 'visualize'
            if nargin < 3
                error('visualize requires data, stabilityData, and config');
            end
            varargout{1} = generateVisualizations(varargin{1}, varargin{2}, varargin{3});
            
        case 'dashboard'
            if nargin < 4
                error('dashboard requires data, stabilityData, figs, and config');
            end
            varargout{1} = createDashboard(varargin{1}, varargin{2}, varargin{3}, varargin{4});
            
        case 'export'
            if nargin < 2
                error('export requires dashboard and config');
            end
            exportReports(varargin{1}, varargin{2});
            
        otherwise
            error('Unknown operation: %s', operation);
    end
end

function data = loadAnalysisData(config, projectId, firmId)
    % Load and validate analysis data
    
    fprintf('Loading analysis data...\n');
    
    % Generate cache key
    tempData = struct('projectId', projectId, 'firmId', firmId);
    cacheKey = cacheManager('generateKey', tempData, config);
    cacheKey = [cacheKey, '_data'];
    
    % Try to load from cache
    if config.cache.enabled
        cached = cacheManager('load', cacheKey, config);
        if ~isempty(cached)
            fprintf('Data loaded from cache\n');
            data = cached;
            return;
        end
    end
    
    % Load from API (returns OpenAPI format by default)
    % NO FALLBACK - must get real data from API
    % Get budget from config, default to 100 if not present
    if isfield(config, 'api') && isfield(config.api, 'budget')
        budget = config.api.budget;
    else
        budget = 100; % Default budget
    end
    
    [data, success, errorMsg] = safeExecute(@getRiskData, ...
        config.api.baseUrl, projectId, firmId, budget, true); % useOpenAPIFormat=true
    
    if ~success
        error('Failed to load data from API: %s\n\nAPI must be running and accessible at %s\nProject: %s, Firm: %s', ...
            errorMsg, config.api.baseUrl, projectId, firmId);
    end
    
    if isempty(data)
        error('API returned empty data for project %s, firm %s', projectId, firmId);
    end
    
    % Validate data - must be in enhanced API format
    if ~isfield(data, 'node_assessments')
        error('Data must be in enhanced API format with node_assessments field');
    end
    
    % Validate enhanced sections are present
    enhancedSections = {'graph_topology', 'risk_distributions', 'monte_carlo_parameters'};
    missingSections = {};
    for i = 1:length(enhancedSections)
        if ~isfield(data, enhancedSections{i}) || isempty(data.(enhancedSections{i}))
            missingSections{end+1} = enhancedSections{i};
        end
    end
    
    if ~isempty(missingSections)
        warning('Missing enhanced sections: %s. Some functionality may be limited.', ...
            strjoin(missingSections, ', '));
    end
    
    % Validate data structure
    [isValid, errors, warnings] = validateData(data);
    
    if ~isValid
        error('Data validation failed:\n%s', strjoin(errors, '\n'));
    end
    
    if ~isempty(warnings)
        for i = 1:length(warnings)
            warning('Data validation warning: %s', warnings{i});
        end
    end
    
    % Store IDs (enhanced API format)
    data.projectId = projectId;
    data.firmId = firmId;
    
    % Save to cache
    if config.cache.enabled
        cacheManager('save', data, cacheKey, config);
    end
    
    fprintf('Data loaded and validated\n');
end

function results = runMCSimulations(data, config)
    % Run Monte Carlo simulations with caching
    %
    % Uses enhanced API format with monte_carlo_parameters
    
    fprintf('Running Monte Carlo simulations...\n');
    
    % Validate enhanced format
    if ~isfield(data, 'node_assessments')
        error('runMCSimulations: data must be in enhanced API format');
    end
    
    % Get MC parameters from enhanced schema (for reference only)
    mcParams = openapiHelpers('getMonteCarloParameters', data);
    % Note: Not using recommended_samples from schema - using config defaults instead
    % This keeps iterations at reasonable levels (default: 100)
    
    % Generate cache key for MC results
    cacheKey = cacheManager('generateKey', data, config);
    cacheKey = [cacheKey, '_mc'];
    
    % Try to load from cache
    if config.cache.enabled
        cached = cacheManager('load', cacheKey, config);
        if ~isempty(cached)
            fprintf('MC results loaded from cache\n');
            results = cached;
            return;
        end
    end
    
    % Run simulations
    fprintf('  Executing %d iterations per simulation...\n', config.monteCarlo.nIterations);
    
    results = struct();
    
    % Run all MC simulations (pass enhanced data directly)
    [results.parameterSensitivity, success1] = safeExecute(@mc_parameterSensitivity, ...
        data, config.monteCarlo.nIterations);
    
    [results.crossEncoderUncertainty, success2] = safeExecute(@mc_crossEncoderUncertainty, ...
        data, config.monteCarlo.nIterations);
    
    [results.topologyStress, success3] = safeExecute(@mc_topologyStress, ...
        data, config.monteCarlo.nIterations);
    
    [results.failureProbDist, success4] = safeExecute(@mc_failureProbDist, ...
        data, config.monteCarlo.nIterations);
    
    % Check if any failed
    if ~success1 || ~success2 || ~success3 || ~success4
        warning('Some MC simulations failed');
    end
    
    % Save to cache
    if config.cache.enabled
        cacheManager('save', results, cacheKey, config);
    end
    
    fprintf('Monte Carlo simulations completed\n');
end

function stabilityData = aggregateResults(results, config)
    % Aggregate MC results
    
    fprintf('Aggregating results...\n');
    
    % Generate cache key
    cacheKey = 'stability_aggregated';
    
    % Try to load from cache
    if config.cache.enabled
        cached = cacheManager('load', cacheKey, config);
        if ~isempty(cached)
            fprintf('Aggregated results loaded from cache\n');
            stabilityData = cached;
            return;
        end
    end
    
    % Aggregate
    stabilityData = calculateStabilityScores(results);
    
    % Save to cache
    if config.cache.enabled
        cacheManager('save', stabilityData, cacheKey, config);
    end
    
    fprintf('Results aggregated\n');
end

function figs = generateVisualizations(data, stabilityData, config)
    % Generate all visualizations
    
    fprintf('Generating visualizations...\n');
    
    figs = struct();
    
    % Generate each visualization (pass enhanced data directly)
    % Note: visualization functions now accept enhanced API format
    [figs.fig2x2, success1] = safeExecute(@plot2x2MatrixWithEllipses, ...
        data, stabilityData, true); % Pass data as first param (enhanced format)
    
    [figs.fig3d, success2] = safeExecute(@plot3DRiskLandscape, ...
        data, stabilityData, true); % Pass data as first param (enhanced format)
    
    % Globe visualization removed - unnecessary
    
    [figs.figStability, success3] = safeExecute(@plotStabilityNetwork, ...
        data, stabilityData, true); % Pass data as first param (enhanced format)
    
    [figs.figHeatmap, success5] = safeExecute(@plotParameterSensitivity, ...
        struct('parameterSensitivity', stabilityData.allResults.parameterSensitivity), true);
    
    [figs.figConvergence, success6] = safeExecute(@plotMCConvergence, ...
        stabilityData.allResults, true);
    
    [figs.figParallel, success7] = safeExecute(@plotParallelCoordinates, ...
        stabilityData, data, true);
    
    [figs.figHistogram, success8] = safeExecute(@plotRiskDistributions, ...
        stabilityData, stabilityData.allResults, true);
    
    fprintf('Visualizations generated\n');
end

function dashboard = createDashboard(data, stabilityData, figs, config)
    % Create comprehensive dashboard (NO FIGURES - handled separately)
    
    fprintf('Creating dashboard structure (no figures)...\n');
    
    dashboard = struct();
    dashboard.data = data;
    dashboard.stabilityData = stabilityData;
    dashboard.figures = figs;
    dashboard.config = config;
    dashboard.timestamp = now;
    
    % Skip dashboard figure creation - handled by runFlorentVisualization
    dashboard.fig = [];
    
    fprintf('Dashboard structure created (no figures)\n');
end

function exportReports(dashboard, config)
    % Export reports
    
    fprintf('Exporting reports...\n');
    
    % Generate text report
    if config.report.includeExecutiveSummary || config.report.includeDetailedAnalysis
        [~, success] = safeExecute(@generateTextReport, ...
            dashboard.data, dashboard.stabilityData, config);
        if success
            fprintf('Text report generated\n');
        end
    end
    
    % Export PDF if configured
    if config.report.exportPDF && isfield(dashboard, 'fig') && ~isempty(dashboard.fig)
        try
            reportFile = fullfile(config.paths.reportsDir, 'risk_analysis_dashboard.pdf');
            exportgraphics(dashboard.fig, reportFile, ...
                'ContentType', 'vector', 'Resolution', config.visualization.dpi);
            fprintf('PDF report exported: %s\n', reportFile);
        catch ME
            warning('PDF export failed: %s', ME.message);
        end
    end
    
    fprintf('Reports exported\n');
end

