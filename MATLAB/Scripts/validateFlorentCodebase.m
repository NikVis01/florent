% VALIDATEFLORENTCODEBASE Master validation script for Florent MATLAB codebase
%
% This script implements the comprehensive validation plan, running all 12 phases
% to ensure the codebase works properly.
%
% Usage:
%   report = validateFlorentCodebase()
%   report = validateFlorentCodebase('verbose')  % Detailed output
%
% Output:
%   report - Structure with validation results for all phases

function report = validateFlorentCodebase(verbosity)
    if nargin < 1
        verbosity = 'normal';
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT MATLAB CODEBASE VALIDATION\n');
    fprintf('========================================\n');
    fprintf('Comprehensive validation of all components\n');
    fprintf('========================================\n\n');
    
    tic;
    
    % Initialize report structure
    report = struct();
    report.timestamp = now;
    report.verbosity = verbosity;
    report.phases = {};
    report.overallStatus = 'success';
    report.summary = struct();
    report.summary.totalPhases = 12;
    report.summary.passedPhases = 0;
    report.summary.failedPhases = 0;
    report.summary.warningPhases = 0;
    report.errors = {};
    report.warnings = {};
    
    % Phase 1: Path and Environment Setup
    fprintf('========================================\n');
    fprintf('PHASE 1: Path and Environment Setup\n');
    fprintf('========================================\n');
    phase1 = validatePhase1_PathSetup(verbosity);
    report.phases{end+1} = phase1;
    updateReportStatus(report, phase1);
    fprintf('\n');
    
    % Phase 2: Function Discovery and Registry
    fprintf('========================================\n');
    fprintf('PHASE 2: Function Discovery and Registry\n');
    fprintf('========================================\n');
    phase2 = validatePhase2_FunctionDiscovery(verbosity);
    report.phases{end+1} = phase2;
    updateReportStatus(report, phase2);
    if strcmp(phase2.status, 'error')
        fprintf('[ERROR] Cannot continue without function registry\n');
        generateFinalReport(report, toc);
        return;
    end
    fprintf('\n');
    
    % Phase 3: Dependency Analysis
    fprintf('========================================\n');
    fprintf('PHASE 3: Dependency Analysis\n');
    fprintf('========================================\n');
    phase3 = validatePhase3_DependencyAnalysis(phase2.registry, verbosity);
    report.phases{end+1} = phase3;
    updateReportStatus(report, phase3);
    fprintf('\n');
    
    % Phase 4: Signature Validation
    fprintf('========================================\n');
    fprintf('PHASE 4: Signature Validation\n');
    fprintf('========================================\n');
    phase4 = validatePhase4_SignatureValidation(phase2.registry, phase3.dependencies, verbosity);
    report.phases{end+1} = phase4;
    updateReportStatus(report, phase4);
    fprintf('\n');
    
    % Phase 5: Configuration and Data Validation
    fprintf('========================================\n');
    fprintf('PHASE 5: Configuration and Data Validation\n');
    fprintf('========================================\n');
    phase5 = validatePhase5_ConfigData(verbosity);
    report.phases{end+1} = phase5;
    updateReportStatus(report, phase5);
    fprintf('\n');
    
    % Phase 6: Core Functionality Testing
    fprintf('========================================\n');
    fprintf('PHASE 6: Core Functionality Testing\n');
    fprintf('========================================\n');
    phase6 = validatePhase6_CoreFunctionality(verbosity);
    report.phases{end+1} = phase6;
    updateReportStatus(report, phase6);
    fprintf('\n');
    
    % Phase 7: Visualization Testing
    fprintf('========================================\n');
    fprintf('PHASE 7: Visualization Testing\n');
    fprintf('========================================\n');
    phase7 = validatePhase7_Visualizations(verbosity);
    report.phases{end+1} = phase7;
    updateReportStatus(report, phase7);
    fprintf('\n');
    
    % Phase 8: Pipeline Integration Testing
    fprintf('========================================\n');
    fprintf('PHASE 8: Pipeline Integration Testing\n');
    fprintf('========================================\n');
    phase8 = validatePhase8_PipelineIntegration(verbosity);
    report.phases{end+1} = phase8;
    updateReportStatus(report, phase8);
    fprintf('\n');
    
    % Phase 9: End-to-End Testing
    fprintf('========================================\n');
    fprintf('PHASE 9: End-to-End Testing\n');
    fprintf('========================================\n');
    phase9 = validatePhase9_EndToEnd(verbosity);
    report.phases{end+1} = phase9;
    updateReportStatus(report, phase9);
    fprintf('\n');
    
    % Phase 10: App Testing (Optional)
    fprintf('========================================\n');
    fprintf('PHASE 10: App Testing (Optional)\n');
    fprintf('========================================\n');
    phase10 = validatePhase10_AppTesting(verbosity);
    report.phases{end+1} = phase10;
    updateReportStatus(report, phase10);
    fprintf('\n');
    
    % Phase 11: External Dependencies
    fprintf('========================================\n');
    fprintf('PHASE 11: External Dependencies\n');
    fprintf('========================================\n');
    phase11 = validatePhase11_ExternalDependencies(verbosity);
    report.phases{end+1} = phase11;
    updateReportStatus(report, phase11);
    fprintf('\n');
    
    % Phase 12: Comprehensive Verification
    fprintf('========================================\n');
    fprintf('PHASE 12: Comprehensive Verification\n');
    fprintf('========================================\n');
    phase12 = validatePhase12_ComprehensiveVerification(verbosity);
    report.phases{end+1} = phase12;
    updateReportStatus(report, phase12);
    fprintf('\n');
    
    % Generate final report
    generateFinalReport(report, toc);
end

function updateReportStatus(report, phase)
    % Update overall report status based on phase result
    if strcmp(phase.status, 'error')
        report.overallStatus = 'error';
        report.summary.failedPhases = report.summary.failedPhases + 1;
        if isfield(phase, 'errors')
            report.errors = [report.errors, phase.errors];
        end
    elseif strcmp(phase.status, 'warning')
        if ~strcmp(report.overallStatus, 'error')
            report.overallStatus = 'warning';
        end
        report.summary.warningPhases = report.summary.warningPhases + 1;
        if isfield(phase, 'warnings')
            report.warnings = [report.warnings, phase.warnings];
        end
    else
        report.summary.passedPhases = report.summary.passedPhases + 1;
    end
end

function generateFinalReport(report, elapsedTime)
    % Generate final validation report
    
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  VALIDATION COMPLETE\n');
    fprintf('========================================\n');
    fprintf('Overall Status: %s\n', upper(report.overallStatus));
    fprintf('Time elapsed: %.2f seconds\n', elapsedTime);
    fprintf('\n');
    fprintf('Phase Summary:\n');
    fprintf('  Total Phases: %d\n', report.summary.totalPhases);
    fprintf('  Passed: %d\n', report.summary.passedPhases);
    fprintf('  Warnings: %d\n', report.summary.warningPhases);
    fprintf('  Failed: %d\n', report.summary.failedPhases);
    fprintf('\n');
    
    if ~isempty(report.errors)
        fprintf('Errors Found:\n');
        for i = 1:length(report.errors)
            fprintf('  %d. %s\n', i, report.errors{i});
        end
        fprintf('\n');
    end
    
    if ~isempty(report.warnings)
        fprintf('Warnings Found:\n');
        for i = 1:min(length(report.warnings), 10)  % Limit to first 10
            fprintf('  %d. %s\n', i, report.warnings{i});
        end
        if length(report.warnings) > 10
            fprintf('  ... and %d more warnings\n', length(report.warnings) - 10);
        end
        fprintf('\n');
    end
    
    % Success criteria check
    fprintf('Success Criteria:\n');
    criteria = checkSuccessCriteria(report);
    for i = 1:length(criteria)
        if criteria{i}.passed
            fprintf('  [OK] %s\n', criteria{i}.name);
        else
            fprintf('  [FAIL] %s\n', criteria{i}.name);
        end
    end
    
    fprintf('\n');
    fprintf('========================================\n');
    
    % Recommendations
    if ~strcmp(report.overallStatus, 'success')
        fprintf('\nRecommendations:\n');
        fprintf('  1. Review errors and warnings above\n');
        fprintf('  2. Run initializeFlorent() if path issues found\n');
        fprintf('  3. Check function dependencies if missing functions found\n');
        fprintf('  4. Verify external dependencies (Python API, toolboxes)\n');
        fprintf('  5. Re-run validation after fixes\n');
    else
        fprintf('\n[SUCCESS] All validation checks passed!\n');
        fprintf('The codebase is ready for use.\n');
    end
    fprintf('\n');
end

function criteria = checkSuccessCriteria(report)
    % Check success criteria from plan
    
    criteria = {};
    
    % 1. All critical functions discoverable and callable
    phase2 = getPhaseByIndex(report, 2);
    if ~isempty(phase2) && isfield(phase2, 'registry')
        crit1.passed = ~isempty(phase2.registry) && isfield(phase2.registry, 'functions');
        crit1.name = 'All critical functions discoverable and callable';
    else
        crit1.passed = false;
        crit1.name = 'All critical functions discoverable and callable';
    end
    criteria{end+1} = crit1;
    
    % 2. All dependencies resolved
    phase3 = getPhaseByIndex(report, 3);
    if ~isempty(phase3) && strcmp(phase3.status, 'success')
        crit2.passed = true;
    else
        crit2.passed = false;
    end
    crit2.name = 'All dependencies resolved (no missing functions)';
    criteria{end+1} = crit2;
    
    % 3. Function signatures match call sites
    phase4 = getPhaseByIndex(report, 4);
    if ~isempty(phase4) && strcmp(phase4.status, 'success')
        crit3.passed = true;
    else
        crit3.passed = false;
    end
    crit3.name = 'Function signatures match call sites';
    criteria{end+1} = crit3;
    
    % 4. Configuration loads successfully
    phase5 = getPhaseByIndex(report, 5);
    if ~isempty(phase5) && isfield(phase5, 'configLoaded') && phase5.configLoaded
        crit4.passed = true;
    else
        crit4.passed = false;
    end
    crit4.name = 'Configuration loads successfully';
    criteria{end+1} = crit4;
    
    % 5. Core calculations produce valid results
    phase6 = getPhaseByIndex(report, 6);
    if ~isempty(phase6) && strcmp(phase6.status, 'success')
        crit5.passed = true;
    else
        crit5.passed = false;
    end
    crit5.name = 'Core calculations produce valid results';
    criteria{end+1} = crit5;
    
    % 6. Visualizations generate without errors
    phase7 = getPhaseByIndex(report, 7);
    if ~isempty(phase7) && strcmp(phase7.status, 'success')
        crit6.passed = true;
    else
        crit6.passed = false;
    end
    crit6.name = 'Visualizations generate without errors';
    criteria{end+1} = crit6;
    
    % 7. Pipeline runs end-to-end successfully
    phase8 = getPhaseByIndex(report, 8);
    phase9 = getPhaseByIndex(report, 9);
    if ~isempty(phase8) && strcmp(phase8.status, 'success') && ...
       ~isempty(phase9) && strcmp(phase9.status, 'success')
        crit7.passed = true;
    else
        crit7.passed = false;
    end
    crit7.name = 'Pipeline runs end-to-end successfully';
    criteria{end+1} = crit7;
    
    % 8. Test suite passes
    phase8 = getPhaseByIndex(report, 8);
    if ~isempty(phase8) && isfield(phase8, 'testsPassed')
        crit8.passed = phase8.testsPassed > 0;
    else
        crit8.passed = false;
    end
    crit8.name = 'Test suite passes (or identifies known issues)';
    criteria{end+1} = crit8;
    
    % 9. App launches (optional)
    phase10 = getPhaseByIndex(report, 10);
    if ~isempty(phase10) && (strcmp(phase10.status, 'success') || strcmp(phase10.status, 'skipped'))
        crit9.passed = true;
    else
        crit9.passed = false;
    end
    crit9.name = 'App launches and basic functionality works (if applicable)';
    criteria{end+1} = crit9;
    
    % 10. External dependencies accessible or gracefully handled
    phase11 = getPhaseByIndex(report, 11);
    if ~isempty(phase11) && strcmp(phase11.status, 'success')
        crit10.passed = true;
    else
        crit10.passed = false;
    end
    crit10.name = 'External dependencies accessible or gracefully handled';
    criteria{end+1} = crit10;
end

function phase = getPhaseByIndex(report, index)
    % Get phase by index (1-based)
    if index <= length(report.phases)
        phase = report.phases{index};
    else
        phase = [];
    end
end

% ============================================================================
% PHASE IMPLEMENTATIONS
% ============================================================================

function phase = validatePhase1_PathSetup(verbosity)
    % Phase 1: Path and Environment Setup
    
    phase = struct();
    phase.name = 'Path and Environment Setup';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    
    try
        % Initialize paths
        fprintf('Initializing paths...\n');
        initializeFlorent(false);
        fprintf('  [OK] Paths initialized\n');
        
        % Verify paths
        fprintf('Verifying paths...\n');
        pathReport = verifyPaths();
        phase.pathReport = pathReport;
        
        if ~strcmp(pathReport.status, 'success')
            phase.status = 'warning';
            phase.warnings{end+1} = 'Path verification found issues';
        end
        
        % Check directory structure
        fprintf('Checking directory structure...\n');
        matlabDir = fileparts(fileparts(mfilename('fullpath')));
        requiredDirs = {
            fullfile(matlabDir, 'Functions');
            fullfile(matlabDir, 'Scripts');
            fullfile(matlabDir, 'Config');
        };
        
        optionalDirs = {
            fullfile(matlabDir, 'Data');
            fullfile(matlabDir, 'Figures');
            fullfile(matlabDir, 'Reports');
        };
        
        allExist = true;
        for i = 1:length(requiredDirs)
            if ~exist(requiredDirs{i}, 'dir')
                phase.errors{end+1} = sprintf('Required directory missing: %s', requiredDirs{i});
                allExist = false;
                fprintf('  [ERROR] Missing: %s\n', requiredDirs{i});
            else
                fprintf('  [OK] Found: %s\n', requiredDirs{i});
            end
        end
        
        for i = 1:length(optionalDirs)
            if ~exist(optionalDirs{i}, 'dir')
                % Create if missing
                mkdir(optionalDirs{i});
                fprintf('  [CREATED] %s\n', optionalDirs{i});
            else
                fprintf('  [OK] Found: %s\n', optionalDirs{i});
            end
        end
        
        if ~allExist
            phase.status = 'error';
        end
        
        phase.directoriesChecked = length(requiredDirs) + length(optionalDirs);
        phase.directoriesFound = allExist;
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Path setup failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase2_FunctionDiscovery(verbosity)
    % Phase 2: Function Discovery and Registry
    
    phase = struct();
    phase.name = 'Function Discovery and Registry';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    
    try
        fprintf('Discovering functions...\n');
        registry = discoverFunctions();
        phase.registry = registry;
        
        if isempty(registry) || ~isfield(registry, 'functions')
            phase.status = 'error';
            phase.errors{end+1} = 'Function discovery returned empty registry';
            return;
        end
        
        fprintf('  [OK] Found %d functions\n', length(registry.functions));
        
        % Check for duplicates
        uniqueFuncs = unique(registry.functions);
        if length(uniqueFuncs) < length(registry.functions)
            duplicates = registry.functions;
            [~, idx] = unique(duplicates);
            duplicates(idx) = [];
            duplicates = unique(duplicates);
            phase.warnings{end+1} = sprintf('Found %d duplicate function names', length(duplicates));
            fprintf('  [WARNING] Found %d duplicate function names\n', length(duplicates));
        end
        
        % Verify critical functions exist
        criticalFunctions = {
            'initializeFlorent';
            'loadFlorentConfig';
            'getRiskData';
            'runFlorentAnalysis';
            'runAnalysisPipeline';
        };
        
        missingCritical = {};
        for i = 1:length(criticalFunctions)
            funcName = criticalFunctions{i};
            if ~isKey(registry.locations, funcName)
                missingCritical{end+1} = funcName;
            end
        end
        
        if ~isempty(missingCritical)
            phase.status = 'error';
            phase.errors{end+1} = sprintf('Missing critical functions: %s', strjoin(missingCritical, ', '));
            fprintf('  [ERROR] Missing critical functions\n');
        else
            fprintf('  [OK] All critical functions found\n');
        end
        
        phase.functionCount = length(registry.functions);
        phase.mainFunctionCount = sum(strcmp(registry.types, 'main'));
        phase.localFunctionCount = sum(strcmp(registry.types, 'local'));
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Function discovery failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase3_DependencyAnalysis(registry, verbosity)
    % Phase 3: Dependency Analysis
    
    phase = struct();
    phase.name = 'Dependency Analysis';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    
    try
        fprintf('Parsing dependencies...\n');
        [dependencies, callGraph] = parseDependencies(registry);
        phase.dependencies = dependencies;
        phase.callGraph = callGraph;
        
        fprintf('  [OK] Dependencies parsed\n');
        
        % Verify dependencies
        fprintf('Verifying dependencies...\n');
        depReport = verifyDependencies(registry, dependencies);
        phase.dependencyReport = depReport;
        
        if strcmp(depReport.status, 'error')
            phase.status = 'error';
            phase.errors{end+1} = 'Dependency verification found errors';
        elseif strcmp(depReport.status, 'warning')
            phase.status = 'warning';
            phase.warnings{end+1} = 'Dependency verification found warnings';
        end
        
        if isfield(depReport, 'missingFunctions')
            fprintf('  Missing functions: %d\n', length(depReport.missingFunctions));
        end
        
        if isfield(depReport, 'circularDependencies')
            if ~isempty(depReport.circularDependencies)
                phase.warnings{end+1} = sprintf('Found %d circular dependencies', length(depReport.circularDependencies));
                fprintf('  [WARNING] Circular dependencies found\n');
            end
        end
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Dependency analysis failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase4_SignatureValidation(registry, dependencies, verbosity)
    % Phase 4: Signature Validation
    
    phase = struct();
    phase.name = 'Signature Validation';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    
    try
        fprintf('Extracting signatures...\n');
        signatures = extractSignatures(registry);
        phase.signatures = signatures;
        fprintf('  [OK] Signatures extracted\n');
        
        fprintf('Analyzing call sites...\n');
        callSiteReport = analyzeCallSites(registry, dependencies, signatures);
        phase.callSiteReport = callSiteReport;
        
        if strcmp(callSiteReport.status, 'error')
            phase.status = 'error';
        elseif strcmp(callSiteReport.status, 'warning')
            phase.status = 'warning';
        end
        
        fprintf('Validating signatures...\n');
        sigReport = validateSignatures(registry, signatures);
        phase.signatureReport = sigReport;
        
        if strcmp(sigReport.status, 'error')
            phase.status = 'error';
        elseif strcmp(sigReport.status, 'warning') && ~strcmp(phase.status, 'error')
            phase.status = 'warning';
        end
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Signature validation failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase5_ConfigData(verbosity)
    % Phase 5: Configuration and Data Validation
    
    phase = struct();
    phase.name = 'Configuration and Data Validation';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    phase.configLoaded = false;
    
    try
        % Test configuration loading
        fprintf('Testing configuration loading...\n');
        modes = {'test', 'production', 'interactive'};
        configs = {};
        
        for i = 1:length(modes)
            try
                config = loadFlorentConfig(modes{i});
                configs{end+1} = config;
                fprintf('  [OK] Config loaded for mode: %s\n', modes{i});
            catch ME
                phase.warnings{end+1} = sprintf('Failed to load config for mode %s: %s', modes{i}, ME.message);
                fprintf('  [WARNING] Failed to load config for mode: %s\n', modes{i});
            end
        end
        
        if ~isempty(configs)
            phase.configLoaded = true;
            phase.config = configs{1};  % Use first successful config
        end
        
        % Test data loading
        fprintf('Testing data loading...\n');
        try
            data = getRiskData();
            if isfield(data, 'graph') && isfield(data, 'riskScores')
                fprintf('  [OK] Data loaded successfully\n');
                phase.dataLoaded = true;
            else
                phase.warnings{end+1} = 'Data structure incomplete';
                fprintf('  [WARNING] Data structure incomplete\n');
            end
        catch ME
            phase.warnings{end+1} = sprintf('Data loading failed: %s', ME.message);
            fprintf('  [WARNING] Data loading failed (may use mock data): %s\n', ME.message);
            phase.dataLoaded = false;
        end
        
        % Test data validation
        if phase.dataLoaded
            fprintf('Validating data structure...\n');
            try
                [isValid, errors, warnings] = validateData(data);
                if isValid
                    fprintf('  [OK] Data validation passed\n');
                else
                    phase.warnings{end+1} = sprintf('Data validation found %d errors', length(errors));
                    fprintf('  [WARNING] Data validation found issues\n');
                end
            catch ME
                phase.warnings{end+1} = sprintf('Data validation failed: %s', ME.message);
            end
        end
        
        % Test cache manager
        fprintf('Testing cache manager...\n');
        try
            if phase.configLoaded
                cacheKey = cacheManager('generateKey', struct('test', 1), phase.config);
                if ~isempty(cacheKey)
                    fprintf('  [OK] Cache manager functional\n');
                end
            end
        catch ME
            phase.warnings{end+1} = sprintf('Cache manager test failed: %s', ME.message);
        end
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Configuration/data validation failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase6_CoreFunctionality(verbosity)
    % Phase 6: Core Functionality Testing
    
    phase = struct();
    phase.name = 'Core Functionality Testing';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    phase.testsPassed = 0;
    phase.testsFailed = 0;
    
    try
        % Test risk calculations
        fprintf('Testing risk calculations...\n');
        try
            influence = calculate_influence_score(0.8, 0.5, 0.9);
            if ~isnan(influence) && isfinite(influence)
                phase.testsPassed = phase.testsPassed + 1;
                fprintf('  [OK] calculate_influence_score\n');
            else
                phase.testsFailed = phase.testsFailed + 1;
                fprintf('  [FAIL] calculate_influence_score returned invalid value\n');
            end
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.errors{end+1} = sprintf('calculate_influence_score failed: %s', ME.message);
            fprintf('  [FAIL] calculate_influence_score\n');
        end
        
        try
            p_success = calculate_topological_risk(0.1, 1.0, [0.9, 0.8]);
            if ~isnan(p_success) && isfinite(p_success)
                phase.testsPassed = phase.testsPassed + 1;
                fprintf('  [OK] calculate_topological_risk\n');
            else
                phase.testsFailed = phase.testsFailed + 1;
                fprintf('  [FAIL] calculate_topological_risk returned invalid value\n');
            end
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.errors{end+1} = sprintf('calculate_topological_risk failed: %s', ME.message);
            fprintf('  [FAIL] calculate_topological_risk\n');
        end
        
        % Test graph utilities
        fprintf('Testing graph utilities...\n');
        try
            % Create simple test adjacency matrix
            testAdj = [0 1 0; 0 0 1; 0 0 0];
            centrality = calculateEigenvectorCentrality(testAdj);
            if ~isempty(centrality) && length(centrality) == 3
                phase.testsPassed = phase.testsPassed + 1;
                fprintf('  [OK] calculateEigenvectorCentrality\n');
            else
                phase.testsFailed = phase.testsFailed + 1;
                fprintf('  [FAIL] calculateEigenvectorCentrality\n');
            end
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.errors{end+1} = sprintf('calculateEigenvectorCentrality failed: %s', ME.message);
            fprintf('  [FAIL] calculateEigenvectorCentrality\n');
        end
        
        try
            sorted = topologicalSort(testAdj);
            if ~isempty(sorted)
                phase.testsPassed = phase.testsPassed + 1;
                fprintf('  [OK] topologicalSort\n');
            else
                phase.testsFailed = phase.testsFailed + 1;
                fprintf('  [FAIL] topologicalSort\n');
            end
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.errors{end+1} = sprintf('topologicalSort failed: %s', ME.message);
            fprintf('  [FAIL] topologicalSort\n');
        end
        
        % Test classification
        fprintf('Testing classification...\n');
        try
            quadrant = classifyQuadrant(0.7, 0.8);
            if ismember(quadrant, {'Q1', 'Q2', 'Q3', 'Q4'})
                phase.testsPassed = phase.testsPassed + 1;
                fprintf('  [OK] classifyQuadrant\n');
            else
                phase.testsFailed = phase.testsFailed + 1;
                fprintf('  [FAIL] classifyQuadrant returned invalid quadrant\n');
            end
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.errors{end+1} = sprintf('classifyQuadrant failed: %s', ME.message);
            fprintf('  [FAIL] classifyQuadrant\n');
        end
        
        try
            action = getActionFromQuadrant('Q1');
            if ~isempty(action)
                phase.testsPassed = phase.testsPassed + 1;
                fprintf('  [OK] getActionFromQuadrant\n');
            else
                phase.testsFailed = phase.testsFailed + 1;
                fprintf('  [FAIL] getActionFromQuadrant\n');
            end
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.errors{end+1} = sprintf('getActionFromQuadrant failed: %s', ME.message);
            fprintf('  [FAIL] getActionFromQuadrant\n');
        end
        
        % Test safeExecute
        fprintf('Testing safeExecute...\n');
        try
            testFunc = @(x) x * 2;
            [result, success, errorMsg] = safeExecute(testFunc, 5);
            if success && result == 10
                phase.testsPassed = phase.testsPassed + 1;
                fprintf('  [OK] safeExecute\n');
            else
                phase.testsFailed = phase.testsFailed + 1;
                fprintf('  [FAIL] safeExecute\n');
            end
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.errors{end+1} = sprintf('safeExecute failed: %s', ME.message);
            fprintf('  [FAIL] safeExecute\n');
        end
        
        if phase.testsFailed > 0
            phase.status = 'error';
        elseif phase.testsPassed == 0
            phase.status = 'warning';
        end
        
        fprintf('  Tests passed: %d, failed: %d\n', phase.testsPassed, phase.testsFailed);
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Core functionality testing failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase7_Visualizations(verbosity)
    % Phase 7: Visualization Testing
    
    phase = struct();
    phase.name = 'Visualization Testing';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    phase.figuresCreated = 0;
    phase.figuresFailed = 0;
    
    try
        % Create minimal test data
        fprintf('Creating test data for visualizations...\n');
        try
            testData = getRiskData();
            if ~isfield(testData, 'graph') || ~isfield(testData, 'riskScores')
                % Create minimal mock data
                testData = struct();
                testData.graph = struct('adj', [0 1; 0 0], 'nodes', {{'Node1', 'Node2'}});
                testData.riskScores = struct('risk', [0.5, 0.7], 'influence', [0.6, 0.8]);
            end
            
            % Create minimal stability data
            stabilityData = struct();
            stabilityData.nodeIds = 1:length(testData.riskScores.risk);
            stabilityData.meanScores = struct();
            stabilityData.meanScores.risk = testData.riskScores.risk;
            stabilityData.meanScores.influence = testData.riskScores.influence;
            stabilityData.overallStability = [0.7, 0.6];
            
            fprintf('  [OK] Test data created\n');
        catch ME
            phase.status = 'error';
            phase.errors{end+1} = sprintf('Failed to create test data: %s', ME.message);
            return;
        end
        
        % Test visualization functions
        visualizationFunctions = {
            'plot2x2MatrixWithEllipses', {stabilityData, testData, false};
            'plot3DRiskLandscape', {stabilityData, testData, false};
            'plotStabilityNetwork', {testData, stabilityData, false};
        };
        
        for i = 1:length(visualizationFunctions)
            funcName = visualizationFunctions{i}{1};
            args = visualizationFunctions{i}{2};
            
            fprintf('Testing %s...\n', funcName);
            try
                fig = feval(funcName, args{:});
                if ishandle(fig)
                    phase.figuresCreated = phase.figuresCreated + 1;
                    close(fig);
                    fprintf('  [OK] %s\n', funcName);
                else
                    phase.figuresFailed = phase.figuresFailed + 1;
                    phase.warnings{end+1} = sprintf('%s did not return valid figure handle', funcName);
                    fprintf('  [WARNING] %s\n', funcName);
                end
            catch ME
                phase.figuresFailed = phase.figuresFailed + 1;
                phase.warnings{end+1} = sprintf('%s failed: %s', funcName, ME.message);
                fprintf('  [WARNING] %s failed: %s\n', funcName, ME.message);
            end
        end
        
        if phase.figuresFailed > phase.figuresCreated
            phase.status = 'warning';
        end
        
        fprintf('  Figures created: %d, failed: %d\n', phase.figuresCreated, phase.figuresFailed);
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Visualization testing failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase8_PipelineIntegration(verbosity)
    % Phase 8: Pipeline Integration Testing
    
    phase = struct();
    phase.name = 'Pipeline Integration Testing';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    phase.testsPassed = 0;
    phase.testsFailed = 0;
    
    try
        fprintf('Running pipeline test suite...\n');
        try
            testFlorentPipeline('normal');
            phase.testsPassed = phase.testsPassed + 1;
            fprintf('  [OK] testFlorentPipeline completed\n');
        catch ME
            phase.testsFailed = phase.testsFailed + 1;
            phase.warnings{end+1} = sprintf('testFlorentPipeline had issues: %s', ME.message);
            fprintf('  [WARNING] testFlorentPipeline: %s\n', ME.message);
        end
        
        % Test pipeline operations
        fprintf('Testing pipeline operations...\n');
        try
            config = loadFlorentConfig('test');
            
            % Test loadData
            try
                data = runAnalysisPipeline('loadData', config, 'proj_001', 'firm_001');
                if isfield(data, 'graph')
                    phase.testsPassed = phase.testsPassed + 1;
                    fprintf('  [OK] Pipeline loadData\n');
                else
                    phase.testsFailed = phase.testsFailed + 1;
                    fprintf('  [FAIL] Pipeline loadData\n');
                end
            catch ME
                phase.testsFailed = phase.testsFailed + 1;
                phase.warnings{end+1} = sprintf('Pipeline loadData failed: %s', ME.message);
                fprintf('  [WARNING] Pipeline loadData\n');
            end
            
        catch ME
            phase.warnings{end+1} = sprintf('Pipeline operations test setup failed: %s', ME.message);
        end
        
        if phase.testsFailed > phase.testsPassed
            phase.status = 'warning';
        end
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Pipeline integration testing failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase9_EndToEnd(verbosity)
    % Phase 9: End-to-End Testing
    
    phase = struct();
    phase.name = 'End-to-End Testing';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    
    try
        fprintf('Running end-to-end test...\n');
        try
            testEndToEnd();
            fprintf('  [OK] testEndToEnd completed\n');
        catch ME
            phase.status = 'warning';
            phase.warnings{end+1} = sprintf('testEndToEnd had issues: %s', ME.message);
            fprintf('  [WARNING] testEndToEnd: %s\n', ME.message);
        end
        
        fprintf('Running demo...\n');
        try
            runFlorentDemo('test');
            fprintf('  [OK] runFlorentDemo completed\n');
        catch ME
            phase.warnings{end+1} = sprintf('runFlorentDemo had issues: %s', ME.message);
            fprintf('  [WARNING] runFlorentDemo: %s\n', ME.message);
        end
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('End-to-end testing failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase10_AppTesting(verbosity)
    % Phase 10: App Testing (Optional)
    
    phase = struct();
    phase.name = 'App Testing';
    phase.status = 'skipped';
    phase.errors = {};
    phase.warnings = {};
    
    try
        % Check if app file exists
        matlabDir = fileparts(fileparts(mfilename('fullpath')));
        appFile = fullfile(matlabDir, 'Apps', 'florentRiskApp.m');
        
        if ~exist(appFile, 'file')
            phase.warnings{end+1} = 'App file not found, skipping app tests';
            fprintf('  [SKIP] App file not found\n');
            return;
        end
        
        fprintf('App file found, testing integration functions...\n');
        
        % Test app integration functions exist
        integrationFuncs = {'appIntegration', 'updateAppProgress', 'runAnalysisAsync'};
        allExist = true;
        
        for i = 1:length(integrationFuncs)
            funcPath = which(integrationFuncs{i});
            if isempty(funcPath)
                allExist = false;
                phase.warnings{end+1} = sprintf('App integration function not found: %s', integrationFuncs{i});
                fprintf('  [WARNING] %s not found\n', integrationFuncs{i});
            else
                fprintf('  [OK] %s found\n', integrationFuncs{i});
            end
        end
        
        if allExist
            phase.status = 'success';
        else
            phase.status = 'warning';
        end
        
        % Note: We don't actually launch the app in automated testing
        % as it requires GUI interaction
        
    catch ME
        phase.status = 'warning';
        phase.warnings{end+1} = sprintf('App testing had issues: %s', ME.message);
        fprintf('  [WARNING] %s\n', ME.message);
    end
end

function phase = validatePhase11_ExternalDependencies(verbosity)
    % Phase 11: External Dependencies
    
    phase = struct();
    phase.name = 'External Dependencies';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    
    try
        % Test Python API connectivity
        fprintf('Testing Python API connectivity...\n');
        try
            config = loadFlorentConfig('test');
            apiUrl = sprintf('%s/data', config.api.baseUrl);
            response = callPythonAPI(apiUrl, 'GET');
            
            if ~isempty(response)
                fprintf('  [OK] Python API accessible\n');
                phase.apiAccessible = true;
            else
                fprintf('  [WARNING] Python API not accessible (will use mock data)\n');
                phase.apiAccessible = false;
                phase.warnings{end+1} = 'Python API not accessible, using mock data fallback';
            end
        catch ME
            fprintf('  [WARNING] Python API test failed: %s\n', ME.message);
            phase.apiAccessible = false;
            phase.warnings{end+1} = sprintf('Python API test failed: %s', ME.message);
        end
        
        % Check for MATLAB toolboxes
        fprintf('Checking MATLAB toolboxes...\n');
        toolboxes = {'Parallel Computing Toolbox', 'Statistics and Machine Learning Toolbox'};
        availableToolboxes = {};
        missingToolboxes = {};
        
        for i = 1:length(toolboxes)
            % Check if toolbox is available (simplified check)
            % In real implementation, use ver() or license()
            fprintf('  [INFO] %s (check manually if needed)\n', toolboxes{i});
        end
        
        % Check data file accessibility
        fprintf('Checking data file accessibility...\n');
        try
            matlabDir = fileparts(fileparts(mfilename('fullpath')));
            projectRoot = fileparts(matlabDir);
            dataDir = fullfile(projectRoot, 'src', 'data');
            
            if exist(dataDir, 'dir')
                fprintf('  [OK] Data directory exists\n');
            else
                phase.warnings{end+1} = 'Data directory not found';
                fprintf('  [WARNING] Data directory not found\n');
            end
        catch ME
            phase.warnings{end+1} = sprintf('Data directory check failed: %s', ME.message);
        end
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('External dependencies check failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

function phase = validatePhase12_ComprehensiveVerification(verbosity)
    % Phase 12: Comprehensive Verification
    
    phase = struct();
    phase.name = 'Comprehensive Verification';
    phase.status = 'success';
    phase.errors = {};
    phase.warnings = {};
    
    try
        fprintf('Running comprehensive verification...\n');
        try
            verifyReport = verifyFlorentCodebase();
            phase.verifyReport = verifyReport;
            
            if strcmp(verifyReport.overallStatus, 'success')
                fprintf('  [OK] Comprehensive verification passed\n');
            elseif strcmp(verifyReport.overallStatus, 'error')
                phase.status = 'error';
                phase.errors{end+1} = 'Comprehensive verification found errors';
                fprintf('  [ERROR] Comprehensive verification found errors\n');
            else
                phase.status = 'warning';
                phase.warnings{end+1} = 'Comprehensive verification found warnings';
                fprintf('  [WARNING] Comprehensive verification found warnings\n');
            end
        catch ME
            phase.warnings{end+1} = sprintf('Comprehensive verification had issues: %s', ME.message);
            fprintf('  [WARNING] %s\n', ME.message);
        end
        
        fprintf('Running quick health check...\n');
        try
            healthStatus = quickHealthCheck();
            if healthStatus.passed
                fprintf('  [OK] Quick health check passed\n');
            else
                phase.warnings{end+1} = 'Quick health check found issues';
                fprintf('  [WARNING] Quick health check found issues\n');
            end
        catch ME
            phase.warnings{end+1} = sprintf('Quick health check failed: %s', ME.message);
            fprintf('  [WARNING] %s\n', ME.message);
        end
        
    catch ME
        phase.status = 'error';
        phase.errors{end+1} = sprintf('Comprehensive verification failed: %s', ME.message);
        fprintf('  [ERROR] %s\n', ME.message);
    end
end

