function report = verifyPaths()
    % VERIFYPATHS Verify all required directories are on MATLAB path
    %
    % Usage:
    %   report = verifyPaths()
    %
    % Output:
    %   report - Structure with verification results
    
    fprintf('\n=== Verifying MATLAB Path Configuration ===\n\n');
    
    report = struct();
    report.requiredDirs = {};
    report.foundDirs = {};
    report.missingDirs = {};
    report.shadowingIssues = {};
    report.warnings = {};
    
    % Get MATLAB directory
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    
    % Required directories
    requiredDirs = {
        fullfile(matlabDir, 'Functions');
        fullfile(matlabDir, 'Scripts');
        fullfile(matlabDir, 'Config');
    };
    
    report.requiredDirs = requiredDirs;
    
    % Check each required directory
    fprintf('Checking required directories...\n');
    for i = 1:length(requiredDirs)
        dirPath = requiredDirs{i};
        
        % Check if directory exists
        if ~exist(dirPath, 'dir')
            report.missingDirs{end+1} = dirPath;
            fprintf('  [MISSING] Directory does not exist: %s\n', dirPath);
            continue;
        end
        
        % Check if on path
        funcPath = which('verifyPaths'); % Use a known function to test
        testFile = fullfile(dirPath, 'test_file_that_should_not_exist.m');
        
        % Try to find a function in this directory
        if isOnPath(dirPath)
            report.foundDirs{end+1} = dirPath;
            fprintf('  [OK] On path: %s\n', dirPath);
        else
            report.missingDirs{end+1} = dirPath;
            fprintf('  [NOT ON PATH] %s\n', dirPath);
        end
    end
    
    % Check for shadowing issues
    fprintf('\nChecking for shadowing issues...\n');
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
    fprintf('Shadowing issues: %d\n', length(report.shadowingIssues));
    
    if length(report.missingDirs) == 0 && length(report.shadowingIssues) == 0
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

