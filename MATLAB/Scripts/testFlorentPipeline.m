% TESTFLORENTPIPELINE Test script for Florent analysis pipeline
%
% This script validates all components of the Florent pipeline:
%   - Configuration loading
%   - Data loading (API + fallback)
%   - MC simulation (small iteration count)
%   - Visualization generation
%   - Cache functionality
%   - Error handling
%
% Usage:
%   testFlorentPipeline()
%   testFlorentPipeline('verbose')  % Detailed output

function testFlorentPipeline(verbosity)
    if nargin < 1
        verbosity = 'normal';
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT PIPELINE TEST SUITE\n');
    fprintf('========================================\n\n');
    
    % Initialize paths first
    fprintf('Initializing paths...\n');
    try
        initializeFlorent(false);
        fprintf('  [OK] Paths initialized\n\n');
    catch ME
        warning('Path initialization failed: %s', ME.message);
        fprintf('  [WARNING] Continuing with current path configuration\n\n');
    end
    
    testsPassed = 0;
    testsFailed = 0;
    testsTotal = 0;
    
    % Test 1: Configuration Loading
    testsTotal = testsTotal + 1;
    fprintf('Test 1: Configuration Loading...\n');
    try
        config = loadFlorentConfig('test');
        assert(isfield(config, 'api'), 'Config missing api field');
        assert(isfield(config, 'monteCarlo'), 'Config missing monteCarlo field');
        assert(isfield(config, 'paths'), 'Config missing paths field');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 2: Data Loading
    testsTotal = testsTotal + 1;
    fprintf('Test 2: Data Loading...\n');
    try
        data = getRiskData();
        assert(isfield(data, 'graph'), 'Data missing graph field');
        assert(isfield(data, 'riskScores'), 'Data missing riskScores field');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 3: Data Validation
    testsTotal = testsTotal + 1;
    fprintf('Test 3: Data Validation...\n');
    try
        [isValid, errors] = validateData(data);
        if isValid
            fprintf('  PASSED\n');
            testsPassed = testsPassed + 1;
        else
            fprintf('  FAILED: Validation errors:\n');
            for i = 1:length(errors)
                fprintf('    - %s\n', errors{i});
            end
            testsFailed = testsFailed + 1;
        end
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 4: Cache Manager
    testsTotal = testsTotal + 1;
    fprintf('Test 4: Cache Manager...\n');
    try
        cacheKey = cacheManager('generateKey', data, config);
        assert(~isempty(cacheKey), 'Cache key generation failed');
        
        exists = cacheManager('exists', cacheKey, config);
        assert(isa(exists, 'logical'), 'Cache exists check failed');
        
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 5: MC Simulation (Quick)
    testsTotal = testsTotal + 1;
    fprintf('Test 5: Monte Carlo Simulation (10 iterations)...\n');
    try
        results = mc_parameterSensitivity(data, 10);
        assert(isfield(results, 'meanScores'), 'MC results missing meanScores');
        assert(isfield(results, 'variance'), 'MC results missing variance');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 6: Aggregation
    testsTotal = testsTotal + 1;
    fprintf('Test 6: Results Aggregation...\n');
    try
        mcResults = struct();
        mcResults.parameterSensitivity = results;
        stabilityData = calculateStabilityScores(mcResults);
        assert(isfield(stabilityData, 'overallStability'), 'Stability data missing overallStability');
        assert(isfield(stabilityData, 'meanScores'), 'Stability data missing meanScores');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 7: Visualization Generation
    testsTotal = testsTotal + 1;
    fprintf('Test 7: Visualization Generation...\n');
    try
        fig = plot2x2MatrixWithEllipses(stabilityData, data, false);
        assert(ishandle(fig), 'Figure generation failed');
        close(fig);
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 8: Safe Execute
    testsTotal = testsTotal + 1;
    fprintf('Test 8: Safe Execute Wrapper...\n');
    try
        testFunc = @(x) x * 2;
        [result, success, errorMsg] = safeExecute(testFunc, 5);
        assert(success, 'Safe execute failed');
        assert(result == 10, 'Safe execute wrong result');
        
        % Test error handling
        errorFunc = @() error('Test error');
        [~, success, errorMsg] = safeExecute(errorFunc);
        assert(~success, 'Safe execute should fail on error');
        assert(~isempty(errorMsg), 'Error message should be non-empty');
        
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 9: Pipeline Components
    testsTotal = testsTotal + 1;
    fprintf('Test 9: Pipeline Components...\n');
    try
        % Test loadData
        loadedData = runAnalysisPipeline('loadData', config, 'proj_001', 'firm_001');
        assert(isfield(loadedData, 'graph'), 'Pipeline loadData failed');
        
        % Test aggregate
        mcResults = struct();
        mcResults.parameterSensitivity = results;
        aggregated = runAnalysisPipeline('aggregate', mcResults, config);
        assert(isfield(aggregated, 'overallStability'), 'Pipeline aggregate failed');
        
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 10: Geographic Data
    testsTotal = testsTotal + 1;
    fprintf('Test 10: Geographic Data Loading...\n');
    try
        geoData = loadGeographicData('BRA', config);
        assert(isfield(geoData, 'coordinates'), 'Geo data missing coordinates');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 11: Function Callability
    testsTotal = testsTotal + 1;
    fprintf('Test 11: Function Callability Check...\n');
    try
        % Check critical functions are callable
        criticalFuncs = {'loadFlorentConfig', 'getRiskData', 'classifyQuadrant', ...
            'calculate_influence_score', 'plot2x2MatrixWithEllipses'};
        allCallable = true;
        for i = 1:length(criticalFuncs)
            funcPath = which(criticalFuncs{i});
            if isempty(funcPath)
                fprintf('    [ERROR] Cannot find: %s\n', criticalFuncs{i});
                allCallable = false;
            end
        end
        assert(allCallable, 'Some critical functions are not callable');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Summary
    fprintf('========================================\n');
    fprintf('  TEST SUMMARY\n');
    fprintf('========================================\n');
    fprintf('Total Tests: %d\n', testsTotal);
    fprintf('Passed: %d\n', testsPassed);
    fprintf('Failed: %d\n', testsFailed);
    fprintf('Success Rate: %.1f%%\n', 100*testsPassed/testsTotal);
    fprintf('========================================\n\n');
    
    if testsFailed == 0
        fprintf('All tests passed! Pipeline is ready for use.\n');
    else
        fprintf('Some tests failed. Please review errors above.\n');
    end
end

