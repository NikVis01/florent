function config = florentConfig(mode)
    % FLORENTCONFIG Central configuration for Florent analysis pipeline
    %
    % This function loads configuration and uses OpenAPI schemas to get
    % default values from the API specification (e.g., budget default).
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
    
    % Load OpenAPI schemas to get API defaults
    % This ensures config values match the API specification
    apiDefaults = getAPIDefaultsFromSchemas();
    config.apiDefaultsLoaded = isfield(apiDefaults, 'budget') && ...
        ~isempty(apiDefaults.budget) && apiDefaults.budget ~= 100;
    
    % API Configuration
    config.api = struct();
    config.api.baseUrl = 'http://localhost:8000';
    % Use budget default from OpenAPI schema if available, otherwise 100
    if isfield(apiDefaults, 'budget')
        config.api.budget = apiDefaults.budget;
    else
        config.api.budget = 100; % Fallback default (matches OpenAPI spec default)
    end
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

function defaults = getAPIDefaultsFromSchemas()
    % GETAPIDEFAULTSFROMSCHEMAS Extract default values from OpenAPI schemas
    %
    % Loads OpenAPI schemas and extracts default values for API configuration.
    % Falls back to hardcoded defaults if schemas are not available.
    %
    % Returns:
    %   defaults - Struct with default values from schemas
    
    defaults = struct();
    
    try
        % Check if openapiHelpers is available (might not be on path yet)
        if exist('openapiHelpers', 'file') == 2
            % Try to load schemas using openapiHelpers
            schemas = openapiHelpers('getSchemas');
            
            if ~isempty(schemas) && isfield(schemas, 'schemas') && ...
               isfield(schemas.schemas, 'AnalysisRequest')
                
                requestSchema = schemas.schemas.AnalysisRequest.schema;
                
                % Extract budget default
                if isfield(requestSchema, 'properties') && ...
                   isfield(requestSchema.properties, 'budget')
                    budgetProp = requestSchema.properties.budget;
                    
                    % Handle oneOf structure (budget can be integer or null)
                    if isfield(budgetProp, 'oneOf') && iscell(budgetProp.oneOf)
                        % Check first option (integer with default)
                        for i = 1:length(budgetProp.oneOf)
                            option = budgetProp.oneOf{i};
                            if isstruct(option) && isfield(option, 'type') && ...
                               strcmp(option.type, 'integer') && isfield(option, 'default')
                                defaults.budget = option.default;
                                break;
                            end
                        end
                    elseif isfield(budgetProp, 'default')
                        % Direct default value
                        defaults.budget = budgetProp.default;
                    end
                end
                
                % Extract example if available (overrides schema default)
                if isfield(schemas.schemas.AnalysisRequest, 'example')
                    example = schemas.schemas.AnalysisRequest.example;
                    if isfield(example, 'budget')
                        defaults.budget = example.budget;
                    end
                end
            end
        else
            % Try loading schemas directly using load_florent_schemas
            if exist('load_florent_schemas', 'file') == 2
                schemas = load_florent_schemas();
                
                if ~isempty(schemas) && isfield(schemas, 'schemas') && ...
                   isfield(schemas.schemas, 'AnalysisRequest')
                    
                    requestSchema = schemas.schemas.AnalysisRequest.schema;
                    
                    % Extract budget default (same logic as above)
                    if isfield(requestSchema, 'properties') && ...
                       isfield(requestSchema.properties, 'budget')
                        budgetProp = requestSchema.properties.budget;
                        
                        if isfield(budgetProp, 'oneOf') && iscell(budgetProp.oneOf)
                            for i = 1:length(budgetProp.oneOf)
                                option = budgetProp.oneOf{i};
                                if isstruct(option) && isfield(option, 'type') && ...
                                   strcmp(option.type, 'integer') && isfield(option, 'default')
                                    defaults.budget = option.default;
                                    break;
                                end
                            end
                        elseif isfield(budgetProp, 'default')
                            defaults.budget = budgetProp.default;
                        end
                    end
                end
            end
        end
    catch ME
        % Schemas not available - use fallback defaults
        % This is expected if schemas haven't been loaded yet or paths aren't set up
        % Silently fall back to hardcoded defaults
    end
    
    % Ensure we have at least fallback defaults (matches OpenAPI spec)
    if ~isfield(defaults, 'budget')
        defaults.budget = 100; % Fallback default from OpenAPI spec
    end
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

