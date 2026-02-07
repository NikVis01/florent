% QUICKHEALTHCHECK Fast verification of critical functions
%
% This script performs a quick check of critical functions and main entry points
% to verify the codebase is in a usable state.
%
% Usage:
%   status = quickHealthCheck()

function status = quickHealthCheck()
    fprintf('\n=== Quick Health Check ===\n\n');
    
    status = struct();
    status.passed = true;
    status.checks = {};
    
    % Critical functions that must be callable
    criticalFunctions = {
        'initializeFlorent';
        'loadFlorentConfig';
        'getRiskData';
        'runFlorentAnalysis';
        'runAnalysisPipeline';
        'verifyFlorentCodebase';
    };
    
    fprintf('Checking critical functions...\n');
    allFound = true;
    
    for i = 1:length(criticalFunctions)
        funcName = criticalFunctions{i};
        funcPath = which(funcName);
        
        check = struct();
        check.function = funcName;
        
        if isempty(funcPath)
            check.status = 'missing';
            check.message = 'Function not found';
            status.checks{end+1} = check;
            allFound = false;
            fprintf('  [FAIL] %s - not found\n', funcName);
        else
            check.status = 'found';
            check.path = funcPath;
            status.checks{end+1} = check;
            fprintf('  [OK] %s\n', funcName);
        end
    end
    
    % Quick path check (main session)
    fprintf('\nChecking paths (main session)...\n');
    try
        pathReport = verifyPaths(false);  % Don't check workers yet
        if strcmp(pathReport.status, 'success')
            fprintf('  [OK] Paths configured correctly\n');
        else
            fprintf('  [WARNING] Path issues detected\n');
            if ~isempty(pathReport.missingDirs)
                fprintf('    Missing directories: %s\n', strjoin(pathReport.missingDirs, ', '));
            end
            if ~isempty(pathReport.missingFunctions)
                fprintf('    Missing functions: %s\n', strjoin(pathReport.missingFunctions, ', '));
            end
            status.passed = false;
        end
    catch ME
        fprintf('  [ERROR] Path check failed: %s\n', ME.message);
        status.passed = false;
    end
    
    % Check parallel worker paths if pool exists
    fprintf('\nChecking parallel worker paths...\n');
    try
        pool = gcp('nocreate');
        if isempty(pool)
            fprintf('  [INFO] No parallel pool found (this is OK if not using parallel processing)\n');
        else
            fprintf('  [INFO] Found parallel pool with %d workers\n', pool.NumWorkers);
            workerPathReport = verifyPaths(true);  % Check workers too
            
            if isfield(workerPathReport, 'workerVerification') && ...
                    isfield(workerPathReport.workerVerification, 'available') && ...
                    workerPathReport.workerVerification.available
                if workerPathReport.workerVerification.success
                    fprintf('  [OK] Worker paths configured correctly\n');
                else
                    fprintf('  [WARNING] Worker path issues detected\n');
                    if isfield(workerPathReport.workerVerification, 'errors')
                        for i = 1:length(workerPathReport.workerVerification.errors)
                            fprintf('    %s\n', workerPathReport.workerVerification.errors{i});
                        end
                    end
                    status.passed = false;
                end
            end
        end
    catch ME
        fprintf('  [WARNING] Worker path check failed: %s\n', ME.message);
        fprintf('  [INFO] This may be OK if parallel processing is not needed\n');
    end
    
    % Summary
    fprintf('\n=== Health Check Summary ===\n');
    if allFound && status.passed
        fprintf('[SUCCESS] All critical functions are accessible!\n');
        fprintf('The codebase appears to be in good health.\n');
    else
        fprintf('[WARNING] Some issues detected.\n');
        fprintf('Run initializeFlorent() and verifyFlorentCodebase() for details.\n');
        status.passed = false;
    end
    
    fprintf('\n');
end

