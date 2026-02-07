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
    
    % Quick path check
    fprintf('\nChecking paths...\n');
    try
        pathReport = verifyPaths();
        if strcmp(pathReport.status, 'success')
            fprintf('  [OK] Paths configured correctly\n');
        else
            fprintf('  [WARNING] Path issues detected\n');
            status.passed = false;
        end
    catch ME
        fprintf('  [ERROR] Path check failed: %s\n', ME.message);
        status.passed = false;
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

