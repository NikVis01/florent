function result = pathManager(operation, varargin)
    % PATHMANAGER Centralized path management for Florent MATLAB codebase
    %
    % This function provides a single source of truth for all path operations,
    % including both main MATLAB session and parallel worker paths.
    %
    % Usage:
    %   result = pathManager('setupPaths')              % Setup paths for main session
    %   result = pathManager('setupWorkerPaths', pool)  % Setup paths for parallel workers
    %   result = pathManager('verifyPaths')             % Verify main session paths
    %   result = pathManager('verifyWorkerPaths', pool)  % Verify worker paths
    %   result = pathManager('getRequiredDirs')         % Get list of required directories
    %
    % Output:
    %   result - Structure with status and diagnostic information
    
    if nargin < 1
        error('pathManager requires an operation argument');
    end
    
    operation = lower(operation);
    
    switch operation
        case 'setuppaths'
            result = setupPaths(varargin{:});
        case 'setupworkerpaths'
            result = setupWorkerPaths(varargin{:});
        case 'verifypaths'
            result = verifyMainPaths(varargin{:});
        case 'verifyworkerpaths'
            result = verifyWorkerPaths(varargin{:});
        case 'getrequireddirs'
            result = getRequiredDirs();
        case 'ispathset'
            result = isPathSet(varargin{:});
        otherwise
            error('Unknown operation: %s', operation);
    end
end

function result = setupPaths(savePath)
    % Setup paths for main MATLAB session
    
    if nargin < 1
        savePath = false;
    end
    
    result = struct();
    result.success = false;
    result.directories = {};
    result.added = {};
    result.alreadyOnPath = {};
    result.failed = {};
    result.errors = {};
    
    % Get required directories
    requiredDirs = getRequiredDirs();
    result.directories = requiredDirs;
    
    % Add each directory to path
    for i = 1:length(requiredDirs)
        dirPath = requiredDirs{i};
        
        % Check if directory exists
        if ~exist(dirPath, 'dir')
            result.failed{end+1} = dirPath;
            result.errors{end+1} = sprintf('Directory does not exist: %s', dirPath);
            continue;
        end
        
        % Check if already on path
        if isOnPath(dirPath)
            result.alreadyOnPath{end+1} = dirPath;
        else
            % Add to path
            try
                addpath(dirPath);
                result.added{end+1} = dirPath;
            catch ME
                result.failed{end+1} = dirPath;
                result.errors{end+1} = ME.message;
            end
        end
    end
    
    % Add subdirectories recursively
    for i = 1:length(requiredDirs)
        dirPath = requiredDirs{i};
        if exist(dirPath, 'dir')
            try
                subdirs = genpath(dirPath);
                pathList = strsplit(subdirs, pathsep);
                for j = 1:length(pathList)
                    if ~isempty(pathList{j}) && ~isOnPath(pathList{j})
                        try
                            addpath(pathList{j});
                            result.added{end+1} = pathList{j};
                        catch
                            % Skip if fails (e.g., .git directories)
                        end
                    end
                end
            catch ME
                result.errors{end+1} = sprintf('Failed to add subdirectories for %s: %s', dirPath, ME.message);
            end
        end
    end
    
    % Save path if requested
    if savePath
        try
            savepath;
            result.pathSaved = true;
        catch ME
            result.pathSaved = false;
            result.errors{end+1} = sprintf('Failed to save path: %s', ME.message);
        end
    end
    
    % Determine success
    result.success = length(result.failed) == 0;
    
    % Verify critical functions are accessible
    result.verification = verifyMainPaths();
end

function result = setupWorkerPaths(pool)
    % Setup paths for parallel workers
    
    result = struct();
    result.success = false;
    result.errors = {};
    result.workerStatus = {};
    
    if nargin < 1 || isempty(pool)
        % Try to get existing pool
        pool = gcp('nocreate');
        if isempty(pool)
            result.errors{end+1} = 'No parallel pool provided and no existing pool found';
            return;
        end
    end
    
    % Get required directories
    requiredDirs = getRequiredDirs();
    
    % Get absolute paths
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    functionsDir = fullfile(matlabDir, 'Functions');
    
    % Setup paths on all workers using spmd
    try
        spmd
            % Add each required directory to path
            for i = 1:length(requiredDirs)
                dirPath = requiredDirs{i};
                if exist(dirPath, 'dir')
                    if ~isOnPath(dirPath)
                        addpath(dirPath);
                    end
                end
            end
            
            % Force path refresh
            rehash path;
            
            % Store status
            workerStatus = struct();
            workerStatus.workerId = labindex;
            workerStatus.pathSet = true;
            
            % Verify that riskCalculations.m functions are callable
            % (calculate_influence_score is a local function, so we test by calling it)
            workerStatus.functionAccessible = true;  % Assume true if path is set
            workerStatus.functionCallable = false;
            
            % Try to actually call the function (it's local, so which() won't find it)
            try
                testResult = calculate_influence_score(0.5, 1.0, 1.2);
                workerStatus.functionCallable = isnumeric(testResult) && ~isempty(testResult);
            catch
                workerStatus.functionCallable = false;
            end
        end
        
        % Extract worker status
        result.workerStatus = workerStatus;
        
        % Check if all workers succeeded
        allWorkersOk = true;
        for i = 1:length(workerStatus)
            if ~workerStatus{i}.functionCallable
                allWorkersOk = false;
                result.errors{end+1} = sprintf('Worker %d: function not callable', i);
            end
        end
        
        result.success = allWorkersOk;
        
    catch ME
        result.success = false;
        result.errors{end+1} = ME.message;
    end
    
    % Attach required function files to pool
    if exist('functionsDir', 'var') && exist(functionsDir, 'dir')
        requiredFiles = {
            fullfile(functionsDir, 'riskCalculations.m');
            fullfile(functionsDir, 'calculateEigenvectorCentrality.m');
            fullfile(functionsDir, 'getParentNodes.m');
            fullfile(functionsDir, 'getChildNodes.m');
            fullfile(functionsDir, 'classifyQuadrant.m');
        };
        
        existingFiles = {};
        for i = 1:length(requiredFiles)
            if exist(requiredFiles{i}, 'file')
                existingFiles{end+1} = requiredFiles{i};
            end
        end
        
        if ~isempty(existingFiles)
            try
                addAttachedFiles(pool, existingFiles);
                result.filesAttached = length(existingFiles);
            catch ME
                result.errors{end+1} = sprintf('Failed to attach files: %s', ME.message);
            end
        end
    end
end

function result = verifyMainPaths()
    % Verify paths are set correctly in main session
    
    result = struct();
    result.success = false;
    result.missingDirs = {};
    result.missingFunctions = {};
    result.accessibleFunctions = {};
    
    % Get required directories
    requiredDirs = getRequiredDirs();
    
    % Check each directory
    for i = 1:length(requiredDirs)
        dirPath = requiredDirs{i};
        if ~isOnPath(dirPath)
            result.missingDirs{end+1} = dirPath;
        end
    end
    
    % Check critical functions (only top-level functions, not local functions)
    % Note: calculate_influence_score and calculate_topological_risk are local
    % functions in riskCalculations.m, so we check that file exists instead
    criticalFunctions = {
        'classifyQuadrant';
        'getParentNodes';
        'calculateEigenvectorCentrality';
        'getRiskData';
        'loadFlorentConfig';
    };
    
    % Check that critical calculation functions exist as separate files
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    calcFiles = {
        fullfile(matlabDir, 'Functions', 'calculate_influence_score.m');
        fullfile(matlabDir, 'Functions', 'calculate_topological_risk.m');
        fullfile(matlabDir, 'Functions', 'sigmoid.m');
    };
    for i = 1:length(calcFiles)
        if exist(calcFiles{i}, 'file')
            [~, funcName, ~] = fileparts(calcFiles{i});
            result.accessibleFunctions{end+1} = funcName;
        else
            [~, funcName, ~] = fileparts(calcFiles{i});
            result.missingFunctions{end+1} = funcName;
        end
    end
    
    for i = 1:length(criticalFunctions)
        funcName = criticalFunctions{i};
        funcPath = which(funcName);
        if isempty(funcPath)
            result.missingFunctions{end+1} = funcName;
        else
            result.accessibleFunctions{end+1} = funcName;
        end
    end
    
    result.success = length(result.missingDirs) == 0 && length(result.missingFunctions) == 0;
end

function result = verifyWorkerPaths(pool)
    % Verify paths are set correctly on parallel workers
    
    result = struct();
    result.success = false;
    result.errors = {};
    result.workerResults = {};
    
    if nargin < 1 || isempty(pool)
        pool = gcp('nocreate');
        if isempty(pool)
            result.errors{end+1} = 'No parallel pool available';
            return;
        end
    end
    
    % Critical functions to test (only top-level callable functions)
    % Note: calculate_influence_score and calculate_topological_risk are local
    % functions, so we test them by actually calling them, not using which()
    criticalFunctions = {
        'classifyQuadrant';
    };
    
    % Verify calculation functions exist as separate files
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    calcFiles = {
        fullfile(matlabDir, 'Functions', 'calculate_influence_score.m');
        fullfile(matlabDir, 'Functions', 'calculate_topological_risk.m');
    };
    calcFilesExist = true;
    for i = 1:length(calcFiles)
        if ~exist(calcFiles{i}, 'file')
            calcFilesExist = false;
            break;
        end
    end
    
    try
        spmd
            workerResult = struct();
            workerResult.workerId = labindex;
            workerResult.functionsFound = {};
            workerResult.functionsMissing = {};
            workerResult.functionsCallable = {};
            workerResult.functionsNotCallable = {};
            
            % Check each function
            for i = 1:length(criticalFunctions)
                funcName = criticalFunctions{i};
                funcPath = which(funcName);
                
                if isempty(funcPath)
                    workerResult.functionsMissing{end+1} = funcName;
                else
                    workerResult.functionsFound{end+1} = funcName;
                    
                    % Try to call it
                    try
                        if strcmp(funcName, 'classifyQuadrant')
                            testResult = classifyQuadrant([0.5, 0.6], [0.4, 0.5]);
                            if ~isempty(testResult)
                                workerResult.functionsCallable{end+1} = funcName;
                            else
                                workerResult.functionsNotCallable{end+1} = funcName;
                            end
                        else
                            workerResult.functionsCallable{end+1} = funcName;
                        end
                    catch
                        workerResult.functionsNotCallable{end+1} = funcName;
                    end
                end
            end
            
                % Also test calculation functions by calling them
                % (do this once, outside the for loop)
                if calcFilesExist
                try
                    % Test calculate_influence_score (local function)
                    testResult1 = calculate_influence_score(0.5, 1.0, 1.2);
                    % Test calculate_topological_risk (local function)
                    testResult2 = calculate_topological_risk(0.3, 1.25, [0.9, 0.8]);
                    if isnumeric(testResult1) && isnumeric(testResult2)
                        workerResult.functionsCallable{end+1} = 'calculate_influence_score (local)';
                        workerResult.functionsCallable{end+1} = 'calculate_topological_risk (local)';
                    else
                        workerResult.functionsNotCallable{end+1} = 'calculate_influence_score (local)';
                        workerResult.functionsNotCallable{end+1} = 'calculate_topological_risk (local)';
                    end
                catch
                    workerResult.functionsNotCallable{end+1} = 'calculate_influence_score (local)';
                    workerResult.functionsNotCallable{end+1} = 'calculate_topological_risk (local)';
                end
            else
                workerResult.functionsMissing{end+1} = 'riskCalculations.m';
            end
            
            workerResult.success = length(workerResult.functionsMissing) == 0 && ...
                length(workerResult.functionsNotCallable) == 0;
        end
        
        % Extract results
        result.workerResults = workerResult;
        
        % Check if all workers succeeded
        allWorkersOk = true;
        for i = 1:length(workerResult)
            if ~workerResult{i}.success
                allWorkersOk = false;
                result.errors{end+1} = sprintf('Worker %d: verification failed', i);
            end
        end
        
        result.success = allWorkersOk;
        
    catch ME
        result.success = false;
        result.errors{end+1} = ME.message;
    end
end

function dirs = getRequiredDirs()
    % Get list of required directories that must be on path
    
    % Get MATLAB directory
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    % Get project root (one level up from MATLAB)
    projectRoot = fileparts(matlabDir);
    
    dirs = {
        fullfile(matlabDir, 'Functions');
        fullfile(matlabDir, 'Scripts');
        fullfile(matlabDir, 'Config');
        fullfile(projectRoot, 'docs', 'openapi_export', 'matlab');  % Enhanced schemas loader
    };
end

function result = isPathSet()
    % Quick check if paths are set
    
    result = struct();
    result.pathsSet = false;
    result.missingDirs = {};
    
    requiredDirs = getRequiredDirs();
    allOnPath = true;
    
    for i = 1:length(requiredDirs)
        if ~isOnPath(requiredDirs{i})
            allOnPath = false;
            result.missingDirs{end+1} = requiredDirs{i};
        end
    end
    
    result.pathsSet = allOnPath;
end

function isOnPath = isOnPath(dirPath)
    % Check if directory is on MATLAB path
    
    dirPath = fullfile(dirPath);
    currentPath = path;
    pathList = strsplit(currentPath, pathsep);
    
    isOnPath = false;
    for i = 1:length(pathList)
        if strcmp(fullfile(pathList{i}), dirPath)
            isOnPath = true;
            return;
        end
    end
end

