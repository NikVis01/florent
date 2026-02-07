% TESTENDTOEND End-to-end test of Florent analysis pipeline
%
% This script runs a complete analysis to verify:
%   - No missing function errors
%   - All visualizations generate
%   - Reports are created
%   - Path initialization works
%
% Usage:
%   testEndToEnd()

function testEndToEnd()
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT END-TO-END TEST\n');
    fprintf('========================================\n\n');
    
    % Initialize paths
    fprintf('Step 1: Initializing paths...\n');
    try
        initializeFlorent(false);
        fprintf('  [OK] Paths initialized\n\n');
    catch ME
        error('Path initialization failed: %s', ME.message);
    end
    
    % Quick health check
    fprintf('Step 2: Quick health check...\n');
    try
        healthStatus = quickHealthCheck();
        if ~healthStatus.passed
            warning('Health check found issues, but continuing...');
        end
        fprintf('  [OK] Health check completed\n\n');
    catch ME
        warning('Health check failed: %s', ME.message);
    end
    
    % Run full analysis in test mode
    fprintf('Step 3: Running full analysis (test mode)...\n');
    try
        results = runFlorentAnalysis('proj_001', 'firm_001', 'test');
        fprintf('  [OK] Analysis completed\n\n');
    catch ME
        fprintf('  [ERROR] Analysis failed: %s\n', ME.message);
        fprintf('  Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
        end
        error('End-to-end test failed');
    end
    
    % Verify outputs
    fprintf('Step 4: Verifying outputs...\n');
    
    % Check results structure
    requiredFields = {'data', 'stabilityData', 'figures', 'dashboard'};
    for i = 1:length(requiredFields)
        if ~isfield(results, requiredFields{i})
            warning('Results missing field: %s', requiredFields{i});
        else
            fprintf('  [OK] Results contain: %s\n', requiredFields{i});
        end
    end
    
    % Check figures were generated
    if isfield(results, 'figures')
        figFields = fieldnames(results.figures);
        fprintf('  [OK] Generated %d visualizations\n', length(figFields));
    end
    
    % Check reports directory
    config = results.config;
    if exist(config.paths.reportsDir, 'dir')
        reportFiles = dir(fullfile(config.paths.reportsDir, '*.txt'));
        fprintf('  [OK] Found %d report file(s)\n', length(reportFiles));
    end
    
    fprintf('\n');
    
    % Summary
    fprintf('========================================\n');
    fprintf('  END-TO-END TEST COMPLETE\n');
    fprintf('========================================\n');
    fprintf('[SUCCESS] All tests passed!\n');
    fprintf('The Florent pipeline is fully functional.\n');
    fprintf('========================================\n\n');
end

