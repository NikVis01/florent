function initializeFlorent(savePath, setupParallelPaths)
    % INITIALIZEFLORENT Initialize MATLAB path for Florent analysis
    %
    % This function adds all necessary directories to the MATLAB path
    % so that all Florent functions can be found and called.
    %
    % Usage:
    %   initializeFlorent()                    % Add paths for current session
    %   initializeFlorent(true)                % Add paths and save for future sessions
    %   initializeFlorent(false, true)         % Add paths and setup parallel worker paths
    %   initializeFlorent(true, true)         % Save paths and setup parallel worker paths
    %
    % Output:
    %   Displays confirmation and any warnings
    
    if nargin < 1
        savePath = false;
    end
    if nargin < 2
        setupParallelPaths = false;
    end
    
    fprintf('\n=== Initializing Florent MATLAB Path ===\n\n');
    
    % Check if pathManager is available (it should be if we're in the right location)
    if isempty(which('pathManager'))
        % Try to add Functions directory to path first
        matlabDir = fileparts(mfilename('fullpath'));
        functionsDir = fullfile(matlabDir, 'Functions');
        if exist(functionsDir, 'dir')
            addpath(functionsDir);
        end
    end
    
    % Use centralized path manager to setup paths
    fprintf('Setting up paths using centralized path manager...\n');
    pathResult = pathManager('setupPaths', savePath);
    
    if pathResult.success
        fprintf('Paths setup successfully\n');
    else
        warning('Path setup had some issues:');
        for i = 1:length(pathResult.errors)
            warning('  %s', pathResult.errors{i});
        end
    end
    
    % Display what was added
    if ~isempty(pathResult.added)
        fprintf('\nDirectories added to path:\n');
        for i = 1:length(pathResult.added)
            fprintf('  [ADDED] %s\n', pathResult.added{i});
        end
    end
    
    if ~isempty(pathResult.alreadyOnPath)
        fprintf('\nDirectories already on path:\n');
        for i = 1:length(pathResult.alreadyOnPath)
            fprintf('  [OK] %s\n', pathResult.alreadyOnPath{i});
        end
    end
    
    % Verify paths
    fprintf('\nVerifying path setup...\n');
    verification = pathResult.verification;
    
    if verification.success
        fprintf('  [SUCCESS] All required directories and functions are accessible\n');
    else
        fprintf('  [WARNING] Some issues detected:\n');
        if ~isempty(verification.missingDirs)
            fprintf('    Missing directories: %s\n', strjoin(verification.missingDirs, ', '));
        end
        if ~isempty(verification.missingFunctions)
            fprintf('    Missing functions: %s\n', strjoin(verification.missingFunctions, ', '));
            fprintf('\n    Solution: Ensure all required files are in the Functions directory.\n');
        end
    end
    
    % Setup parallel worker paths if requested
    if setupParallelPaths
        fprintf('\n=== Setting Up Parallel Worker Paths ===\n');
        pool = gcp('nocreate');
        if isempty(pool)
            fprintf('  [INFO] No parallel pool found. Creating one...\n');
            try
                pool = parpool('local');
                fprintf('  [OK] Created parallel pool with %d workers\n', pool.NumWorkers);
            catch ME
                warning('  [WARNING] Could not create parallel pool: %s', ME.message);
                fprintf('  [INFO] Parallel worker paths will be set up when a pool is created\n');
            end
        end
        
        if ~isempty(pool)
            fprintf('  [INFO] Setting up paths on %d workers...\n', pool.NumWorkers);
            workerResult = pathManager('setupWorkerPaths', pool);
            
            if workerResult.success
                fprintf('  [SUCCESS] Worker paths configured successfully\n');
            else
                warning('  [WARNING] Worker path setup had issues:');
                for i = 1:length(workerResult.errors)
                    warning('    %s', workerResult.errors{i});
                end
                fprintf('  [INFO] You may need to run pathManager(''setupWorkerPaths'', pool) manually\n');
            end
        end
    end
    
    % Summary
    fprintf('\n=== Path Initialization Summary ===\n');
    fprintf('Directories added: %d\n', length(pathResult.added));
    fprintf('Already on path: %d\n', length(pathResult.alreadyOnPath));
    fprintf('Failed: %d\n', length(pathResult.failed));
    
    if verification.success
        fprintf('\n[SUCCESS] All critical functions are accessible!\n');
        if setupParallelPaths && exist('workerResult', 'var') && workerResult.success
            fprintf('[SUCCESS] Parallel worker paths are also configured!\n');
        end
    else
        fprintf('\n[WARNING] Some critical functions are not accessible.\n');
        fprintf('You may need to check your MATLAB path configuration.\n');
        fprintf('\nTroubleshooting:\n');
        fprintf('  1. Ensure you are in the correct directory\n');
        fprintf('  2. Check that all required files exist in Functions/\n');
        fprintf('  3. Try running: verifyPaths() to see detailed diagnostics\n');
    end
    
    fprintf('\n');
end


