function varargout = cacheManager(operation, varargin)
    % CACHEMANAGER Manages caching for Florent analysis results
    %
    % Usage:
    %   key = cacheManager('generateKey', data, config)
    %   cached = cacheManager('load', key, config)
    %   cacheManager('save', data, key, config)
    %   cacheManager('clear', config)
    %   cacheManager('clear', config, 'all')
    %
    % Operations:
    %   'generateKey' - Generate deterministic cache key
    %   'load' - Load from cache
    %   'save' - Save to cache
    %   'clear' - Clear cache (specific or all)
    %   'exists' - Check if cache entry exists
    
    operation = lower(operation);
    
    switch operation
        case 'generatekey'
            if nargin < 3
                error('generateKey requires data and config');
            end
            varargout{1} = generateCacheKey(varargin{1}, varargin{2});
            
        case 'load'
            if nargin < 3
                error('load requires key and config');
            end
            varargout{1} = loadFromCache(varargin{1}, varargin{2});
            
        case 'save'
            if nargin < 4
                error('save requires data, key, and config');
            end
            saveToCache(varargin{1}, varargin{2}, varargin{3});
            
        case 'clear'
            if nargin < 2
                error('clear requires config');
            end
            if nargin >= 3 && strcmpi(varargin{2}, 'all')
                clearCache(varargin{1}, true);
            else
                clearCache(varargin{1}, false);
            end
            
        case 'exists'
            if nargin < 3
                error('exists requires key and config');
            end
            varargout{1} = cacheExists(varargin{1}, varargin{2});
            
        case 'migrate'
            if nargin < 2
                error('migrate requires config');
            end
            varargout{1} = migrateLegacyCache(varargin{1});
            
        otherwise
            error('Unknown operation: %s', operation);
    end
end

function cacheKey = generateCacheKey(data, config)
    % GENERATECACHEKEY Generate deterministic cache key from data and config
    
    % Create key components
    keyParts = {};
    
    % Add API version/format identifier
    if isstruct(data) && isfield(data, 'node_assessments')
        keyParts{end+1} = 'openapi'; % OpenAPI format
    else
        keyParts{end+1} = 'legacy'; % Legacy format
    end
    
    % Project and firm IDs
    if isfield(data, 'projectId')
        keyParts{end+1} = data.projectId;
    end
    if isfield(data, 'firmId')
        keyParts{end+1} = data.firmId;
    end
    
    % MC configuration
    if isfield(config, 'monteCarlo')
        keyParts{end+1} = sprintf('iter%d', config.monteCarlo.nIterations);
        keyParts{end+1} = sprintf('par%d', double(config.monteCarlo.useParallel));
    end
    
    % Parameter hash (from metrics.json if available)
    try
        metricsFile = fullfile(config.paths.pythonDataDir, 'config', 'metrics.json');
        if exist(metricsFile, 'file')
            metricsText = fileread(metricsFile);
            keyParts{end+1} = string2hash(metricsText);
        end
    catch
        % Ignore if metrics file not available
    end
    
    % Combine into single key
    cacheKey = strjoin(keyParts, '_');
    
    % Sanitize key (remove invalid filename characters)
    cacheKey = regexprep(cacheKey, '[^a-zA-Z0-9_-]', '_');
end

function hash = string2hash(str)
    % Simple hash function for strings
    hash = sprintf('%d', sum(double(str)));
end

function cached = loadFromCache(cacheKey, config)
    % LOADFROMCACHE Load data from cache
    
    cached = [];
    
    if ~config.cache.enabled
        return;
    end
    
    cacheFile = getCacheFilePath(cacheKey, config);
    
    if exist(cacheFile, 'file')
        try
            % Check if cache is expired
            fileInfo = dir(cacheFile);
            age = now - datenum(fileInfo.date);
            ageSeconds = age * 86400;
            
            if ageSeconds > config.cache.ttl
                % Cache expired
                if config.logging.verbose
                    fprintf('Cache expired for key: %s\n', cacheKey);
                end
                return;
            end
            
            % Load cache
            load(cacheFile, 'cached');
            
            % Skip legacy format files (they should have been migrated)
            if isstruct(cached) && isfield(cached, 'riskScores') && ...
               ~isfield(cached, 'node_assessments')
                % Legacy format - skip it
                if config.logging.verbose
                    fprintf('Skipping legacy cache format: %s (use migrateLegacyCache)\n', cacheKey);
                end
                cached = [];
                return;
            end
            
            if config.logging.verbose
                fprintf('Loaded from cache: %s\n', cacheKey);
            end
        catch ME
            warning('Failed to load cache: %s', ME.message);
            cached = [];
        end
    end
end

function saveToCache(data, cacheKey, config)
    % SAVETOCACHE Save data to cache
    
    if ~config.cache.enabled
        return;
    end
    
    cacheFile = getCacheFilePath(cacheKey, config);
    cacheDir = fileparts(cacheFile);
    
    % Ensure cache directory exists
    if ~exist(cacheDir, 'dir')
        mkdir(cacheDir);
    end
    
    try
        % Save with timestamp
        cached = data;
        cached.cacheTimestamp = now;
        cached.cacheKey = cacheKey;
        
        save(cacheFile, 'cached', '-v7.3');
        
        if config.logging.verbose
            fprintf('Saved to cache: %s\n', cacheKey);
        end
    catch ME
        warning('Failed to save cache: %s', ME.message);
    end
end

function exists = cacheExists(cacheKey, config)
    % CACHEEXISTS Check if cache entry exists and is valid
    
    exists = false;
    
    if ~config.cache.enabled
        return;
    end
    
    cacheFile = getCacheFilePath(cacheKey, config);
    
    if exist(cacheFile, 'file')
        % Check if expired
        fileInfo = dir(cacheFile);
        age = now - datenum(fileInfo.date);
        ageSeconds = age * 86400;
        
        exists = ageSeconds <= config.cache.ttl;
    end
end

function clearCache(config, clearAll)
    % CLEARCACHE Clear cache entries
    
    if nargin < 2
        clearAll = false;
    end
    
    cacheDir = config.paths.cacheDir;
    
    if ~exist(cacheDir, 'dir')
        return;
    end
    
    if clearAll
        % Clear all cache files
        cacheFiles = dir(fullfile(cacheDir, '*.mat'));
        for i = 1:length(cacheFiles)
            delete(fullfile(cacheDir, cacheFiles(i).name));
        end
        fprintf('Cleared all cache files\n');
    else
        % Clear expired cache files
        cacheFiles = dir(fullfile(cacheDir, '*.mat'));
        cleared = 0;
        for i = 1:length(cacheFiles)
            fileInfo = cacheFiles(i);
            age = now - datenum(fileInfo.date);
            ageSeconds = age * 86400;
            
            if ageSeconds > config.cache.ttl
                delete(fullfile(cacheDir, fileInfo.name));
                cleared = cleared + 1;
            end
        end
        if cleared > 0
            fprintf('Cleared %d expired cache files\n', cleared);
        end
    end
end

function cacheFile = getCacheFilePath(cacheKey, config)
    % GETCACHEFILEPATH Get full path to cache file
    
    cacheDir = config.paths.cacheDir;
    cacheFile = fullfile(cacheDir, [cacheKey, '.mat']);
end

function migrationResult = migrateLegacyCache(config)
    % MIGRATELEGACYCACHE Migrate legacy cache files to OpenAPI format
    %
    % This function scans the cache directory for legacy format cache files
    % and attempts to convert them to OpenAPI format. Legacy files are marked
    % for invalidation.
    %
    % Args:
    %   config - Configuration structure
    %
    % Returns:
    %   migrationResult - Structure with migration statistics
    
    migrationResult = struct();
    migrationResult.migrated = 0;
    migrationResult.failed = 0;
    migrationResult.skipped = 0;
    migrationResult.errors = {};
    
    cacheDir = config.paths.cacheDir;
    
    if ~exist(cacheDir, 'dir')
        fprintf('Cache directory does not exist: %s\n', cacheDir);
        return;
    end
    
    fprintf('Scanning cache directory for legacy files...\n');
    
    cacheFiles = dir(fullfile(cacheDir, '*.mat'));
    
    for i = 1:length(cacheFiles)
        fileInfo = cacheFiles(i);
        cacheFile = fullfile(cacheDir, fileInfo.name);
        
        try
            % Try to load cache file
            cached = [];
            load(cacheFile, 'cached');
            
            % Check if it's legacy format (has riskScores but not node_assessments)
            if isstruct(cached) && isfield(cached, 'riskScores') && ...
               ~isfield(cached, 'node_assessments')
                % Legacy format detected
                fprintf('  Found legacy cache: %s\n', fileInfo.name);
                
                % Mark for invalidation by renaming or deleting
                % For now, we'll just mark it as expired by updating timestamp
                % In production, you might want to convert it or delete it
                legacyFile = fullfile(cacheDir, ['legacy_', fileInfo.name]);
                if exist(cacheFile, 'file')
                    movefile(cacheFile, legacyFile);
                    fprintf('    Moved to: %s (will be ignored)\n', ['legacy_', fileInfo.name]);
                    migrationResult.migrated = migrationResult.migrated + 1;
                end
            elseif isstruct(cached) && isfield(cached, 'node_assessments')
                % Already OpenAPI format
                migrationResult.skipped = migrationResult.skipped + 1;
            else
                % Unknown format
                migrationResult.skipped = migrationResult.skipped + 1;
            end
            
        catch ME
            migrationResult.failed = migrationResult.failed + 1;
            migrationResult.errors{end+1} = sprintf('%s: %s', fileInfo.name, ME.message);
            warning('Failed to process cache file %s: %s', fileInfo.name, ME.message);
        end
    end
    
    fprintf('Migration complete:\n');
    fprintf('  Migrated: %d\n', migrationResult.migrated);
    fprintf('  Skipped: %d\n', migrationResult.skipped);
    fprintf('  Failed: %d\n', migrationResult.failed);
    
    if ~isempty(migrationResult.errors)
        fprintf('\nErrors:\n');
        for j = 1:length(migrationResult.errors)
            fprintf('  %s\n', migrationResult.errors{j});
        end
    end
end

