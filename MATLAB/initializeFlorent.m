function initializeFlorent(savePath)
    % INITIALIZEFLORENT Initialize MATLAB path for Florent analysis
    %
    % This function adds all necessary directories to the MATLAB path
    % so that all Florent functions can be found and called.
    %
    % Usage:
    %   initializeFlorent()              % Add paths for current session
    %   initializeFlorent(true)          % Add paths and save for future sessions
    %   initializeFlorent(false)        % Add paths but don't save
    %
    % Output:
    %   Displays confirmation and any warnings
    
    if nargin < 1
        savePath = false;
    end
    
    fprintf('\n=== Initializing Florent MATLAB Path ===\n\n');
    
    % Get the MATLAB directory (where this script is located)
    matlabDir = fileparts(mfilename('fullpath'));
    
    % Directories to add to path
    directories = {
        fullfile(matlabDir, 'Functions');
        fullfile(matlabDir, 'Scripts');
        fullfile(matlabDir, 'Config');
    };
    
    % Add directories to path
    addedCount = 0;
    alreadyOnPath = 0;
    failedCount = 0;
    
    for i = 1:length(directories)
        dirPath = directories{i};
        
        % Check if directory exists
        if ~exist(dirPath, 'dir')
            warning('Directory does not exist: %s', dirPath);
            failedCount = failedCount + 1;
            continue;
        end
        
        % Check if already on path
        if isOnPath(dirPath)
            fprintf('  [OK] Already on path: %s\n', dirPath);
            alreadyOnPath = alreadyOnPath + 1;
        else
            % Add to path
            try
                addpath(dirPath);
                fprintf('  [ADDED] %s\n', dirPath);
                addedCount = addedCount + 1;
            catch ME
                warning('Failed to add directory to path: %s\nError: %s', dirPath, ME.message);
                failedCount = failedCount + 1;
            end
        end
    end
    
    % Add subdirectories recursively using genpath
    fprintf('\nAdding subdirectories recursively...\n');
    for i = 1:length(directories)
        dirPath = directories{i};
        if exist(dirPath, 'dir')
            try
                subdirs = genpath(dirPath);
                % genpath returns semicolon-separated paths
                pathList = strsplit(subdirs, pathsep);
                for j = 1:length(pathList)
                    if ~isempty(pathList{j}) && ~isOnPath(pathList{j})
                        try
                            addpath(pathList{j});
                            fprintf('  [ADDED] %s\n', pathList{j});
                            addedCount = addedCount + 1;
                        catch
                            % Skip if fails (e.g., .git directories)
                        end
                    end
                end
            catch ME
                warning('Failed to add subdirectories for: %s\nError: %s', dirPath, ME.message);
            end
        end
    end
    
    % Verify critical functions are accessible
    fprintf('\nVerifying critical functions...\n');
    criticalFunctions = {
        'loadFlorentConfig';
        'getRiskData';
        'runFlorentAnalysis';
        'runAnalysisPipeline';
    };
    
    allFound = true;
    for i = 1:length(criticalFunctions)
        funcName = criticalFunctions{i};
        funcPath = which(funcName);
        if isempty(funcPath)
            fprintf('  [ERROR] Cannot find: %s\n', funcName);
            allFound = false;
        else
            fprintf('  [OK] Found: %s\n', funcName);
        end
    end
    
    % Save path if requested
    if savePath
        try
            savepath;
            fprintf('\n[SAVED] Path saved for future MATLAB sessions\n');
        catch ME
            warning('Failed to save path: %s\nYou may need administrator privileges.', ME.message);
        end
    end
    
    % Summary
    fprintf('\n=== Path Initialization Summary ===\n');
    fprintf('Directories added: %d\n', addedCount);
    fprintf('Already on path: %d\n', alreadyOnPath);
    fprintf('Failed: %d\n', failedCount);
    
    if allFound
        fprintf('\n[SUCCESS] All critical functions are accessible!\n');
    else
        fprintf('\n[WARNING] Some critical functions are not accessible.\n');
        fprintf('You may need to check your MATLAB path configuration.\n');
    end
    
    fprintf('\n');
end

function isOnPath = isOnPath(dirPath)
    % Check if directory is on MATLAB path
    
    % Normalize paths for comparison
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

