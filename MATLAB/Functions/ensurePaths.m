function ensurePaths(verbose)
    % ENSUREPATHS Ensure MATLAB paths are set correctly
    %
    % This function automatically initializes paths if they are not already set.
    % It should be called at the start of any function that requires paths.
    %
    % Usage:
    %   ensurePaths()           % Check and setup paths (quiet mode)
    %   ensurePaths(true)       % Check and setup paths (verbose mode)
    %
    % This function:
    %   - Checks if required directories are on path
    %   - Calls initializeFlorent() if paths are missing
    %   - Verifies critical functions are accessible
    %   - Provides clear error messages if setup fails
    
    if nargin < 1
        verbose = false;
    end
    
    % Check if paths are already set
    pathCheck = pathManager('isPathSet');
    
    if pathCheck.pathsSet
        % Paths are set, verify critical functions are accessible
        verification = pathManager('verifyPaths');
        
        if verification.success
            if verbose
                fprintf('Paths verified: All required directories and functions are accessible\n');
            end
            return;
        else
            % Paths are set but functions not accessible - try to fix
            if verbose
                fprintf('Paths are set but some functions are not accessible. Attempting to fix...\n');
            end
            
            % Try to setup paths again
            result = pathManager('setupPaths', false);
            if ~result.success
                error('Paths are set but functions are not accessible. Please run initializeFlorent() manually.');
            end
        end
    else
        % Paths are not set - initialize them
        if verbose
            fprintf('Paths not set. Initializing Florent paths...\n');
        end
        
        % Check if initializeFlorent exists
        if isempty(which('initializeFlorent'))
            % initializeFlorent not found - try to add MATLAB directory to path first
            matlabDir = fileparts(fileparts(mfilename('fullpath')));
            if exist(matlabDir, 'dir')
                addpath(matlabDir);
                if isempty(which('initializeFlorent'))
                    error('Cannot find initializeFlorent(). Please ensure you are in the correct directory or run: cd(''path/to/florent/MATLAB'')');
                end
            else
                error('Cannot find MATLAB directory. Please ensure you are in the correct location.');
            end
        end
        
        % Call initializeFlorent
        try
            initializeFlorent(false);  % Don't save path automatically
            if verbose
                fprintf('Paths initialized successfully\n');
            end
        catch ME
            error('Failed to initialize paths: %s\nPlease run initializeFlorent() manually.', ME.message);
        end
        
        % Verify paths are now set
        verification = pathManager('verifyPaths');
        if ~verification.success
            error('Paths were initialized but verification failed. Missing: %s', ...
                strjoin([verification.missingDirs, verification.missingFunctions], ', '));
        end
    end
end

