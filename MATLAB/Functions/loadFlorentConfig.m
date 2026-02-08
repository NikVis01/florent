function config = loadFlorentConfig(mode, customConfig)
    % LOADFLORENTCONFIG Loads and validates Florent configuration
    %
    % Usage:
    %   config = loadFlorentConfig()
    %   config = loadFlorentConfig('test')
    %   config = loadFlorentConfig('production', customConfig)
    %
    % Inputs:
    %   mode - Configuration mode: 'test', 'production', 'interactive'
    %   customConfig - Struct with custom overrides (optional)
    %
    % Output:
    %   config - Validated configuration structure
    
    if nargin < 1
        mode = 'production';
    end
    if nargin < 2
        customConfig = struct();
    end
    
    % Load base configuration
    config = florentConfig(mode);
    
    % Apply custom overrides
    if ~isempty(fieldnames(customConfig))
        config = mergeConfig(config, customConfig);
    end
    
    % Validate configuration
    [isValid, errors] = validateConfig(config);
    if ~isValid
        warning('Configuration validation failed:');
        for i = 1:length(errors)
            warning('  - %s', errors{i});
        end
    end
    
    % Log configuration (if enabled)
    if config.logging.enabled && config.logging.verbose
        logConfig(config);
    end
end

function config = mergeConfig(baseConfig, overrides)
    % Merge custom configuration overrides into base config
    
    config = baseConfig;
    fields = fieldnames(overrides);
    
    for i = 1:length(fields)
        field = fields{i};
        if isstruct(overrides.(field)) && isfield(config, field) && isstruct(config.(field))
            % Recursive merge for nested structs
            config.(field) = mergeStructs(config.(field), overrides.(field));
        else
            % Direct assignment
            config.(field) = overrides.(field);
        end
    end
end

function merged = mergeStructs(base, override)
    % Recursively merge two structs
    
    merged = base;
    fields = fieldnames(override);
    
    for i = 1:length(fields)
        field = fields{i};
        if isstruct(override.(field)) && isfield(merged, field) && isstruct(merged.(field))
            merged.(field) = mergeStructs(merged.(field), override.(field));
        else
            merged.(field) = override.(field);
        end
    end
end

function [isValid, errors] = validateConfig(config)
    % Validate configuration structure
    
    errors = {};
    isValid = true;
    
    % Check required fields
    requiredFields = {'api', 'monteCarlo', 'thresholds', 'paths', 'visualization', 'mode'};
    for i = 1:length(requiredFields)
        if ~isfield(config, requiredFields{i})
            errors{end+1} = sprintf('Missing required field: %s', requiredFields{i});
            isValid = false;
        end
    end
    
    % Validate paths exist or can be created
    if isfield(config, 'paths')
        pathFields = fieldnames(config.paths);
        for i = 1:length(pathFields)
            path = config.paths.(pathFields{i});
            if ~ischar(path) && ~isstring(path)
                errors{end+1} = sprintf('Invalid path type for: %s', pathFields{i});
                isValid = false;
            end
        end
    end
    
    % Validate MC iterations
    if isfield(config, 'monteCarlo') && isfield(config.monteCarlo, 'nIterations')
        if config.monteCarlo.nIterations < 1
            errors{end+1} = 'MC iterations must be >= 1';
            isValid = false;
        end
    end
    
    % Validate mode
    validModes = {'test', 'production', 'interactive'};
    if isfield(config, 'mode') && ~ismember(config.mode, validModes)
        errors{end+1} = sprintf('Invalid mode: %s (must be one of: %s)', ...
            config.mode, strjoin(validModes, ', '));
        isValid = false;
    end
end

function logConfig(config)
    % Log configuration summary
    
    fprintf('\n=== Florent Configuration ===\n');
    fprintf('Mode: %s\n', config.mode);
    fprintf('MC Iterations: %d\n', config.monteCarlo.nIterations);
    fprintf('Parallel: %s\n', mat2str(config.monteCarlo.useParallel));
    fprintf('Cache Enabled: %s\n', mat2str(config.cache.enabled));
    fprintf('API Base URL: %s\n', config.api.baseUrl);
    if isfield(config.api, 'budget')
        budgetSource = '';
        if isfield(config, 'apiDefaultsLoaded') && config.apiDefaultsLoaded
            budgetSource = ' (from OpenAPI schema)';
        end
        fprintf('API Budget: %d%s\n', config.api.budget, budgetSource);
    end
    fprintf('Data Dir: %s\n', config.paths.dataDir);
    fprintf('Figures Dir: %s\n', config.paths.figuresDir);
    fprintf('=============================\n\n');
end

