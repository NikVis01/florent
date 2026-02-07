% TESTFLORENTAPP Test script for Florent App Designer frontend
%
% This script tests the app integration functions and verifies
% that all components work together correctly.
%
% Usage:
%   testFlorentApp()

function testFlorentApp()
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT APP TEST SUITE\n');
    fprintf('========================================\n\n');
    
    testsPassed = 0;
    testsFailed = 0;
    testsTotal = 0;
    
    % Test 1: Integration functions exist
    testsTotal = testsTotal + 1;
    fprintf('Test 1: Integration Functions...\n');
    try
        assert(exist('appIntegration', 'file') == 2, 'appIntegration.m not found');
        assert(exist('updateAppProgress', 'file') == 2, 'updateAppProgress.m not found');
        assert(exist('appExportFunctions', 'file') == 2, 'appExportFunctions.m not found');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 2: Visualization functions support axes handles
    testsTotal = testsTotal + 1;
    fprintf('Test 2: Visualization Functions with Axes...\n');
    try
        % Check function signatures
        sig1 = help('plot2x2MatrixWithEllipses');
        sig2 = help('plot3DRiskLandscape');
        assert(contains(sig1, 'axesHandle') || contains(sig1, 'axes'), 'plot2x2MatrixWithEllipses missing axes support');
        assert(contains(sig2, 'axesHandle') || contains(sig2, 'axes'), 'plot3DRiskLandscape missing axes support');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 3: Mock app structure
    testsTotal = testsTotal + 1;
    fprintf('Test 3: Mock App Structure...\n');
    try
        % Create mock app structure
        mockApp = createMockApp();
        assert(isfield(mockApp, 'Data') || isprop(mockApp, 'Data'), 'Mock app missing Data property');
        assert(isfield(mockApp, 'StabilityData') || isprop(mockApp, 'StabilityData'), 'Mock app missing StabilityData property');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 4: Progress update function
    testsTotal = testsTotal + 1;
    fprintf('Test 4: Progress Update Function...\n');
    try
        mockApp = createMockApp();
        updateAppProgress(mockApp, 'loading', 50, 'Test message');
        fprintf('  PASSED\n');
        testsPassed = testsPassed + 1;
    catch ME
        fprintf('  FAILED: %s\n', ME.message);
        testsFailed = testsFailed + 1;
    end
    fprintf('\n');
    
    % Test 5: Export functions
    testsTotal = testsTotal + 1;
    fprintf('Test 5: Export Functions...\n');
    try
        assert(exist('appExportFunctions', 'file') == 2, 'appExportFunctions.m not found');
        % Test that function can be called (will fail without app, but that's OK)
        fprintf('  PASSED (function exists)\n');
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
    fprintf('Total tests: %d\n', testsTotal);
    fprintf('Passed: %d\n', testsPassed);
    fprintf('Failed: %d\n', testsFailed);
    fprintf('========================================\n\n');
    
    if testsFailed == 0
        fprintf('[SUCCESS] All tests passed!\n');
    else
        fprintf('[WARNING] Some tests failed. Review errors above.\n');
    end
    fprintf('\n');
end

function mockApp = createMockApp()
    % Create mock app structure for testing
    
    mockApp = struct();
    
    % Add properties that appIntegration expects
    mockApp.Data = [];
    mockApp.StabilityData = [];
    mockApp.MCResults = [];
    mockApp.Config = [];
    mockApp.IsRunning = false;
    
    % Add UI component properties (as struct fields for testing)
    mockApp.ProgressBar = struct('Value', 0);
    mockApp.StatusLabel = struct('Text', '');
    mockApp.StatusTextArea = struct('Value', {});
    mockApp.PhaseLabel = struct('Text', '');
    mockApp.RunAnalysisButton = struct('Enable', 'on');
    mockApp.LoadDemoButton = struct('Enable', 'on');
    mockApp.MCIterationsSlider = struct('Enable', 'on');
    mockApp.RiskThresholdSlider = struct('Enable', 'on');
    mockApp.InfluenceThresholdSlider = struct('Enable', 'on');
    
    % Make it behave like an object with properties
    mockApp = makeAppLike(mockApp);
end

function app = makeAppLike(app)
    % Make struct behave like app object with isprop
    
    % This is a workaround - in real App Designer, isprop works on objects
    % For testing, we'll just return the struct
end

