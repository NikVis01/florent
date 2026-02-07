function config = florentConfig(mode)
    % FLORENTCONFIG Central configuration for Florent analysis pipeline
    %
    % Usage:
    %   config = florentConfig()           % Default: 'production'
    %   config = florentConfig('test')     % Test mode
    %   config = florentConfig('production') % Production mode
    %   config = florentConfig('interactive') % Interactive mode
    %
    % Returns configuration structure with all parameters
    
    if nargin < 1
        mode = 'production';
    end
    
    % Base paths (relative to MATLAB directory)
    baseDir = fileparts(mfilename('fullpath'));
    matlabDir = fileparts(baseDir);
    projectRoot = fileparts(matlabDir);
    
    % Default configuration
    config = struct();
    
    % API Configuration
    config.api = struct();
    config.api.baseUrl = 'http://localhost:8000';
    config.api.timeout = 120; % Increased for long-running analysis (10-60 seconds typical)
    config.api.retryAttempts = 3;
    config.api.retryDelay = 2; % seconds
    
    % API Client Configuration
    config.api.client = struct();
    config.api.client.useGeneratedClient = true; % Use generated OpenAPI client if available (optional)
    config.api.client.fallbackToManual = true; % Always fallback to manual HTTP calls (webread/webwrite) - this is the default
    config.api.client.clientPath = fullfile(matlabDir, 'Classes', 'FlorentAPIClient'); % Path to generated client (if generated)
    
    % Monte Carlo Configuration
    config.monteCarlo = struct();
    config.monteCarlo.useParallel = true;
    config.monteCarlo.cacheResults = true;
    
    % Mode-specific MC iterations
    switch lower(mode)
        case 'test'
            config.monteCarlo.nIterations = 100;
        case 'interactive'
            config.monteCarlo.nIterations = 1000;
        otherwise % 'production'
            config.monteCarlo.nIterations = 10000;
    end
    
    % Thresholds
    config.thresholds = struct();
    config.thresholds.riskThreshold = []; % Auto: median
    config.thresholds.influenceThreshold = []; % Auto: median
    config.thresholds.stabilityThreshold = 0.5; % Below = unstable
    config.thresholds.unstablePercentile = 25; % Bottom X% = unstable
    
    % Paths
    config.paths = struct();
    config.paths.dataDir = fullfile(matlabDir, 'Data');
    config.paths.figuresDir = fullfile(matlabDir, 'Figures');
    config.paths.reportsDir = fullfile(matlabDir, 'Reports');
    config.paths.cacheDir = fullfile(matlabDir, 'Data', 'Cache');
    config.paths.configDir = baseDir;
    config.paths.projectRoot = projectRoot;
    config.paths.pythonDataDir = fullfile(projectRoot, 'src', 'data');
    
    % Visualization Configuration
    config.visualization = struct();
    config.visualization.figureSize = [1400, 900]; % [width, height]
    config.visualization.saveFormats = {'fig', 'png'}; % Formats to save
    config.visualization.dpi = 300; % For PNG/PDF export
    config.visualization.fontSize = 12;
    config.visualization.titleFontSize = 14;
    
    % Mode
    config.mode = mode;
    
    % Logging
    config.logging = struct();
    config.logging.enabled = true;
    config.logging.level = 'info'; % 'debug', 'info', 'warning', 'error'
    config.logging.verbose = true; % Print to console
    
    % Cache Configuration
    config.cache = struct();
    config.cache.enabled = true;
    config.cache.ttl = 86400; % Time to live in seconds (24 hours)
    config.cache.autoInvalidate = true; % Invalidate on config changes
    
    % Report Configuration
    config.report = struct();
    config.report.includeExecutiveSummary = true;
    config.report.includeDetailedAnalysis = true;
    config.report.includeMethodology = true;
    config.report.includeAppendices = true;
    config.report.exportPDF = true;
    config.report.exportHTML = false; % Optional
    
    % Validation
    config.validation = struct();
    config.validation.strictMode = false; % Strict validation or graceful degradation
    config.validation.checkGraphStructure = true;
    config.validation.checkScoreRanges = true;
    
    % Ensure directories exist
    ensureDirectories(config);
end

function ensureDirectories(config)
    % Ensure all required directories exist
    
    dirs = {
        config.paths.dataDir,
        config.paths.figuresDir,
        config.paths.reportsDir,
        config.paths.cacheDir
    };
    
    for i = 1:length(dirs)
        if ~exist(dirs{i}, 'dir')
            mkdir(dirs{i});
        end
    end
end

