function report = verifyPaths(checkWorkers)
    % VERIFYPATHS Verify all required directories are on MATLAB path
    %
    % Usage:
    %   report = verifyPaths()              % Check main session paths only
    %   report = verifyPaths(true)          % Also check parallel worker paths
    %
    % Output:
    %   report - Structure with verification results
    
    if nargin < 1
        checkWorkers = false;
    end
    
    fprintf('\n=== Verifying MATLAB Path Configuration ===\n\n');
    
    report = struct();
    report.requiredDirs = {};
    report.foundDirs = {};
    report.missingDirs = {};
    report.shadowingIssues = {};
    report.warnings = {};
    report.workerVerification = struct();
    
    % Use centralized path manager for main session verification
    mainVerification = pathManager('verifyPaths');
    
    % Get required directories from path manager
    requiredDirs = pathManager('getRequiredDirs');
    report.requiredDirs = requiredDirs;
    
    % Check each required directory
    fprintf('Checking required directories (main session)...\n');
    for i = 1:length(requiredDirs)
        dirPath = requiredDirs{i};
        
        % Check if directory exists
        if ~exist(dirPath, 'dir')
            report.missingDirs{end+1} = dirPath;
            fprintf('  [MISSING] Directory does not exist: %s\n', dirPath);
            continue;
        end
        
        % Check if on path
        if isOnPath(dirPath)
            report.foundDirs{end+1} = dirPath;
            fprintf('  [OK] On path: %s\n', dirPath);
        else
            report.missingDirs{end+1} = dirPath;
            fprintf('  [NOT ON PATH] %s\n', dirPath);
        end
    end
    
    % Check critical functions
    fprintf('\nChecking critical functions (main session)...\n');
    report.missingFunctions = mainVerification.missingFunctions;
    report.accessibleFunctions = mainVerification.accessibleFunctions;
    
    for i = 1:length(mainVerification.accessibleFunctions)
        fprintf('  [OK] %s\n', mainVerification.accessibleFunctions{i});
    end
    
    for i = 1:length(mainVerification.missingFunctions)
        fprintf('  [MISSING] %s\n', mainVerification.missingFunctions{i});
    end
    
    % Check for shadowing issues
    fprintf('\nChecking for shadowing issues...\n');
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    commonNames = {'plot', 'figure', 'save', 'load', 'clear', 'close'};
    for i = 1:length(commonNames)
        funcName = commonNames{i};
        funcPath = which(funcName);
        
        % Check if it's a custom function (not built-in)
        if ~isempty(funcPath) && ~contains(funcPath, matlabroot)
            % Check if it's in our directories
            for j = 1:length(requiredDirs)
                if contains(funcPath, requiredDirs{j})
                    report.shadowingIssues{end+1} = struct('function', funcName, 'path', funcPath);
                    fprintf('  [WARNING] Custom function shadows built-in: %s\n', funcName);
                    fprintf('            Location: %s\n', funcPath);
                end
            end
        end
    end
    
    % Check parallel worker paths if requested
    if checkWorkers
        fprintf('\n=== Checking Parallel Worker Paths ===\n');
        pool = gcp('nocreate');
        if isempty(pool)
            fprintf('  [INFO] No parallel pool found. Skipping worker verification.\n');
            report.workerVerification.available = false;
        else
            fprintf('  [INFO] Found parallel pool with %d workers\n', pool.NumWorkers);
            report.workerVerification.available = true;
            
            % Use centralized path manager for worker verification
            workerVerification = pathManager('verifyWorkerPaths', pool);
            report.workerVerification = workerVerification;
            
            if workerVerification.success
                fprintf('  [SUCCESS] All workers have correct paths and accessible functions\n');
            else
                fprintf('  [WARNING] Worker path verification failed:\n');
                for i = 1:length(workerVerification.errors)
                    fprintf('    - %s\n', workerVerification.errors{i});
                end
            end
            
            % Display per-worker results
            if isfield(workerVerification, 'workerResults') && ~isempty(workerVerification.workerResults)
                fprintf('\n  Per-worker status:\n');
                for i = 1:length(workerVerification.workerResults)
                    wr = workerVerification.workerResults{i};
                    if wr.success
                        fprintf('    Worker %d: [OK] All functions accessible\n', wr.workerId);
                    else
                        fprintf('    Worker %d: [FAIL] Missing: %s\n', wr.workerId, ...
                            strjoin(wr.functionsMissing, ', '));
                    end
                end
            end
        end
    end
    
    % Check path order (user paths should come before system paths)
    fprintf('\nChecking path order...\n');
    currentPath = path;
    pathList = strsplit(currentPath, pathsep);
    
    userPathCount = 0;
    systemPathCount = 0;
    
    for i = 1:length(pathList)
        if contains(pathList{i}, matlabroot)
            systemPathCount = systemPathCount + 1;
        else
            userPathCount = userPathCount + 1;
        end
    end
    
    fprintf('  User paths: %d\n', userPathCount);
    fprintf('  System paths: %d\n', systemPathCount);
    
    % Summary
    fprintf('\n=== Path Verification Summary ===\n');
    fprintf('Required directories: %d\n', length(requiredDirs));
    fprintf('Found on path: %d\n', length(report.foundDirs));
    fprintf('Missing: %d\n', length(report.missingDirs));
    fprintf('Missing functions: %d\n', length(report.missingFunctions));
    fprintf('Shadowing issues: %d\n', length(report.shadowingIssues));
    
    if checkWorkers && isfield(report.workerVerification, 'available') && report.workerVerification.available
        if report.workerVerification.success
            fprintf('Worker paths: [OK]\n');
        else
            fprintf('Worker paths: [FAIL]\n');
        end
    end
    
    % Determine overall status
    mainSessionOk = length(report.missingDirs) == 0 && length(report.missingFunctions) == 0 && ...
        length(report.shadowingIssues) == 0;
    
    if checkWorkers && isfield(report.workerVerification, 'available') && report.workerVerification.available
        overallOk = mainSessionOk && report.workerVerification.success;
    else
        overallOk = mainSessionOk;
    end
    
    if overallOk
        fprintf('\n[SUCCESS] Path configuration is correct!\n');
        report.status = 'success';
    else
        fprintf('\n[WARNING] Path configuration has issues.\n');
        report.status = 'warning';
    end
    
    fprintf('\n');
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

