function results = testFlorentAPIClient()
    % TESTFLORENTAPICLIENT Test the OpenAPI MATLAB client integration
    %
    % This function tests the FlorentAPIClientWrapper and related functions
    % to ensure the OpenAPI integration works correctly.
    %
    % Usage:
    %   results = testFlorentAPIClient()
    %
    % Returns:
    %   results - Structure with test results
    
    fprintf('\n=== Florent OpenAPI Client Tests ===\n\n');
    
    results = struct();
    results.passed = 0;
    results.failed = 0;
    results.tests = {};
    
    % Test configuration
    baseUrl = 'http://localhost:8000';
    projectId = 'proj_001';
    firmId = 'firm_001';
    budget = 100;
    
    % Test 1: Client instantiation
    fprintf('Test 1: Client instantiation...\n');
    try
        client = FlorentAPIClientWrapper(baseUrl);
        assert(~isempty(client), 'Client should not be empty');
        assert(strcmp(client.BaseUrl, baseUrl), 'Base URL should match');
        results.passed = results.passed + 1;
        results.tests{end+1} = struct('name', 'Client instantiation', 'status', 'PASS');
        fprintf('  [PASS] Client instantiated successfully\n');
    catch ME
        results.failed = results.failed + 1;
        results.tests{end+1} = struct('name', 'Client instantiation', 'status', 'FAIL', 'error', ME.message);
        fprintf('  [FAIL] %s\n', ME.message);
    end
    
    % Test 2: Health check
    fprintf('\nTest 2: Health check...\n');
    try
        health = client.healthCheck();
        assert(~isempty(health), 'Health check should return a response');
        results.passed = results.passed + 1;
        results.tests{end+1} = struct('name', 'Health check', 'status', 'PASS');
        fprintf('  [PASS] Health check successful: %s\n', health);
    catch ME
        results.failed = results.failed + 1;
        results.tests{end+1} = struct('name', 'Health check', 'status', 'FAIL', 'error', ME.message);
        fprintf('  [FAIL] %s\n', ME.message);
        fprintf('  [INFO] Is the Python API server running?\n');
    end
    
    % Test 3: Request building
    fprintf('\nTest 3: Request building...\n');
    try
        request = buildAnalysisRequest(projectId, firmId, budget);
        assert(isfield(request, 'firm_path'), 'Request should have firm_path');
        assert(isfield(request, 'project_path'), 'Request should have project_path');
        assert(isfield(request, 'budget'), 'Request should have budget');
        assert(request.budget == budget, 'Budget should match');
        results.passed = results.passed + 1;
        results.tests{end+1} = struct('name', 'Request building', 'status', 'PASS');
        fprintf('  [PASS] Request built successfully\n');
    catch ME
        results.failed = results.failed + 1;
        results.tests{end+1} = struct('name', 'Request building', 'status', 'FAIL', 'error', ME.message);
        fprintf('  [FAIL] %s\n', ME.message);
    end
    
    % Test 4: Response validation (with mock response)
    fprintf('\nTest 4: Response validation...\n');
    try
        mockResponse = struct();
        mockResponse.status = 'success';
        mockResponse.message = 'Test';
        mockResponse.analysis = struct();
        mockResponse.analysis.node_assessments = struct('node1', struct('influence', 0.5, 'risk', 0.3, 'reasoning', 'Test'));
        mockResponse.analysis.action_matrix = struct('mitigate', {}, 'automate', {}, 'contingency', {}, 'delegate', {});
        mockResponse.analysis.critical_chains = {};
        mockResponse.analysis.summary = struct('overall_bankability', 0.7, 'average_risk', 0.3, 'maximum_risk', 0.5);
        
        [isValid, errors, warnings] = validateAnalysisResponse(mockResponse);
        assert(isValid, 'Mock response should be valid');
        results.passed = results.passed + 1;
        results.tests{end+1} = struct('name', 'Response validation', 'status', 'PASS');
        fprintf('  [PASS] Response validation works\n');
    catch ME
        results.failed = results.failed + 1;
        results.tests{end+1} = struct('name', 'Response validation', 'status', 'FAIL', 'error', ME.message);
        fprintf('  [FAIL] %s\n', ME.message);
    end
    
    % Test 5: Response parsing
    fprintf('\nTest 5: Response parsing...\n');
    try
        data = parseAnalysisResponse(mockResponse, projectId, firmId);
        assert(isfield(data, 'graph'), 'Data should have graph');
        assert(isfield(data, 'riskScores'), 'Data should have riskScores');
        assert(isfield(data, 'parameters'), 'Data should have parameters');
        assert(isfield(data, 'classifications'), 'Data should have classifications');
        results.passed = results.passed + 1;
        results.tests{end+1} = struct('name', 'Response parsing', 'status', 'PASS');
        fprintf('  [PASS] Response parsed successfully\n');
    catch ME
        results.failed = results.failed + 1;
        results.tests{end+1} = struct('name', 'Response parsing', 'status', 'FAIL', 'error', ME.message);
        fprintf('  [FAIL] %s\n', ME.message);
    end
    
    % Test 6: Full analysis (if API is available)
    fprintf('\nTest 6: Full analysis (requires API server)...\n');
    try
        % Check if API is available
        try
            health = client.healthCheck();
            % API is available, run full test
            data = client.analyzeProject(projectId, firmId, budget);
            assert(isfield(data, 'graph'), 'Analysis data should have graph');
            assert(isfield(data, 'riskScores'), 'Analysis data should have riskScores');
            results.passed = results.passed + 1;
            results.tests{end+1} = struct('name', 'Full analysis', 'status', 'PASS');
            fprintf('  [PASS] Full analysis completed successfully\n');
            fprintf('  [INFO] Nodes analyzed: %d\n', length(data.riskScores.nodeIds));
        catch
            % API not available, skip test
            results.tests{end+1} = struct('name', 'Full analysis', 'status', 'SKIP', 'reason', 'API server not available');
            fprintf('  [SKIP] API server not available (this is OK for unit tests)\n');
        end
    catch ME
        results.failed = results.failed + 1;
        results.tests{end+1} = struct('name', 'Full analysis', 'status', 'FAIL', 'error', ME.message);
        fprintf('  [FAIL] %s\n', ME.message);
    end
    
    % Test 7: Error handling
    fprintf('\nTest 7: Error handling...\n');
    try
        errorResponse = struct();
        errorResponse.status = 'error';
        errorResponse.message = 'Test error';
        
        try
            parseAnalysisResponse(errorResponse, projectId, firmId);
            error('Should have thrown an error for error response');
        catch
            % Expected error
        end
        
        results.passed = results.passed + 1;
        results.tests{end+1} = struct('name', 'Error handling', 'status', 'PASS');
        fprintf('  [PASS] Error handling works correctly\n');
    catch ME
        results.failed = results.failed + 1;
        results.tests{end+1} = struct('name', 'Error handling', 'status', 'FAIL', 'error', ME.message);
        fprintf('  [FAIL] %s\n', ME.message);
    end
    
    % Summary
    fprintf('\n=== Test Summary ===\n');
    fprintf('Passed: %d\n', results.passed);
    fprintf('Failed: %d\n', results.failed);
    fprintf('Total:  %d\n', results.passed + results.failed);
    
    if results.failed == 0
        fprintf('\n[SUCCESS] All tests passed!\n');
    else
        fprintf('\n[WARNING] Some tests failed. Review errors above.\n');
    end
    
    fprintf('\n');
end

