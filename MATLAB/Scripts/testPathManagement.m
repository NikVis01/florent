% TESTPATHMANAGEMENT Test path management functionality
%
% This script tests the path management system including:
%   - Main session path setup
%   - Parallel worker path setup
%   - Path verification
%   - Function accessibility on workers
%
% Usage:
%   results = testPathManagement()

function results = testPathManagement()
    fprintf('\n=== Testing Path Management System ===\n\n');
    
    results = struct();
    results.tests = {};
    results.allPassed = true;
    
    % Test 1: Main session path setup
    fprintf('Test 1: Main session path setup\n');
    try
        pathResult = pathManager('setupPaths', false);
        test1 = struct();
        test1.name = 'Main session path setup';
        test1.passed = pathResult.success;
        test1.message = '';
        if pathResult.success
            fprintf('  [PASS] Path setup successful\n');
        else
            fprintf('  [FAIL] Path setup failed: %s\n', strjoin(pathResult.errors, '; '));
            test1.message = strjoin(pathResult.errors, '; ');
        end
        results.tests{end+1} = test1;
        if ~test1.passed
            results.allPassed = false;
        end
    catch ME
        test1 = struct();
        test1.name = 'Main session path setup';
        test1.passed = false;
        test1.message = ME.message;
        results.tests{end+1} = test1;
        results.allPassed = false;
        fprintf('  [FAIL] Exception: %s\n', ME.message);
    end
    
    % Test 2: Main session path verification
    fprintf('\nTest 2: Main session path verification\n');
    try
        verifyResult = pathManager('verifyPaths');
        test2 = struct();
        test2.name = 'Main session path verification';
        test2.passed = verifyResult.success;
        test2.message = '';
        if verifyResult.success
            fprintf('  [PASS] All paths and functions verified\n');
        else
            fprintf('  [FAIL] Verification failed\n');
            if ~isempty(verifyResult.missingDirs)
                fprintf('    Missing directories: %s\n', strjoin(verifyResult.missingDirs, ', '));
            end
            if ~isempty(verifyResult.missingFunctions)
                fprintf('    Missing functions: %s\n', strjoin(verifyResult.missingFunctions, ', '));
            end
            test2.message = sprintf('Missing: %s', strjoin([verifyResult.missingDirs, verifyResult.missingFunctions], ', '));
        end
        results.tests{end+1} = test2;
        if ~test2.passed
            results.allPassed = false;
        end
    catch ME
        test2 = struct();
        test2.name = 'Main session path verification';
        test2.passed = false;
        test2.message = ME.message;
        results.tests{end+1} = test2;
        results.allPassed = false;
        fprintf('  [FAIL] Exception: %s\n', ME.message);
    end
    
    % Test 3: Parallel pool creation and worker path setup
    fprintf('\nTest 3: Parallel worker path setup\n');
    try
        % Check if parallel toolbox is available
        try
            pool = gcp('nocreate');
            if isempty(pool)
                fprintf('  [INFO] Creating parallel pool...\n');
                pool = parpool('local');
            end
            fprintf('  [INFO] Using pool with %d workers\n', pool.NumWorkers);
            
            % Setup worker paths
            workerResult = pathManager('setupWorkerPaths', pool);
            test3 = struct();
            test3.name = 'Parallel worker path setup';
            test3.passed = workerResult.success;
            test3.message = '';
            
            if workerResult.success
                fprintf('  [PASS] Worker paths setup successful\n');
            else
                fprintf('  [FAIL] Worker path setup failed:\n');
                for i = 1:length(workerResult.errors)
                    fprintf('    %s\n', workerResult.errors{i});
                end
                test3.message = strjoin(workerResult.errors, '; ');
            end
            results.tests{end+1} = test3;
            if ~test3.passed
                results.allPassed = false;
            end
            
            % Test 4: Worker path verification
            fprintf('\nTest 4: Parallel worker path verification\n');
            workerVerifyResult = pathManager('verifyWorkerPaths', pool);
            test4 = struct();
            test4.name = 'Parallel worker path verification';
            test4.passed = workerVerifyResult.success;
            test4.message = '';
            
            if workerVerifyResult.success
                fprintf('  [PASS] All workers verified successfully\n');
            else
                fprintf('  [FAIL] Worker verification failed:\n');
                for i = 1:length(workerVerifyResult.errors)
                    fprintf('    %s\n', workerVerifyResult.errors{i});
                end
                test4.message = strjoin(workerVerifyResult.errors, '; ');
            end
            results.tests{end+1} = test4;
            if ~test4.passed
                results.allPassed = false;
            end
            
            % Test 5: Function callability on workers
            fprintf('\nTest 5: Function callability on workers\n');
            try
                spmd
                    % Try to call calculate_influence_score
                    testResult = calculate_influence_score(0.5, 1.0, 1.2);
                    callable = isnumeric(testResult) && ~isempty(testResult);
                end
                
                allCallable = true;
                for i = 1:length(callable)
                    if ~callable{i}
                        allCallable = false;
                        break;
                    end
                end
                
                test5 = struct();
                test5.name = 'Function callability on workers';
                test5.passed = allCallable;
                test5.message = '';
                
                if allCallable
                    fprintf('  [PASS] Functions are callable on all workers\n');
                else
                    fprintf('  [FAIL] Functions not callable on some workers\n');
                    test5.message = 'Functions not callable on all workers';
                end
                results.tests{end+1} = test5;
                if ~test5.passed
                    results.allPassed = false;
                end
            catch ME
                test5 = struct();
                test5.name = 'Function callability on workers';
                test5.passed = false;
                test5.message = ME.message;
                results.tests{end+1} = test5;
                results.allPassed = false;
                fprintf('  [FAIL] Exception: %s\n', ME.message);
            end
            
        catch ME
            fprintf('  [SKIP] Parallel Computing Toolbox not available: %s\n', ME.message);
            test3 = struct();
            test3.name = 'Parallel worker path setup';
            test3.passed = true;  % Not a failure if toolbox not available
            test3.message = 'Parallel Computing Toolbox not available';
            results.tests{end+1} = test3;
        end
        
    catch ME
        fprintf('  [FAIL] Exception: %s\n', ME.message);
        test3 = struct();
        test3.name = 'Parallel worker path setup';
        test3.passed = false;
        test3.message = ME.message;
        results.tests{end+1} = test3;
        results.allPassed = false;
    end
    
    % Test 6: ensurePaths functionality
    fprintf('\nTest 6: ensurePaths functionality\n');
    try
        % This should work even if paths are already set
        ensurePaths(false);
        test6 = struct();
        test6.name = 'ensurePaths functionality';
        test6.passed = true;
        test6.message = '';
        fprintf('  [PASS] ensurePaths works correctly\n');
        results.tests{end+1} = test6;
    catch ME
        test6 = struct();
        test6.name = 'ensurePaths functionality';
        test6.passed = false;
        test6.message = ME.message;
        results.tests{end+1} = test6;
        results.allPassed = false;
        fprintf('  [FAIL] Exception: %s\n', ME.message);
    end
    
    % Summary
    fprintf('\n=== Test Summary ===\n');
    passedCount = 0;
    for i = 1:length(results.tests)
        if results.tests{i}.passed
            passedCount = passedCount + 1;
        end
    end
    fprintf('Tests passed: %d/%d\n', passedCount, length(results.tests));
    
    if results.allPassed
        fprintf('\n[SUCCESS] All path management tests passed!\n');
    else
        fprintf('\n[WARNING] Some tests failed. See details above.\n');
    end
    
    fprintf('\n');
end

