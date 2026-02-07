% VERIFYFLORENTCODEBASE Comprehensive verification of Florent codebase
%
% This script runs all verification checks:
%   1. Initialize paths
%   2. Discover all functions
%   3. Parse dependencies
%   4. Verify dependencies exist
%   5. Extract signatures
%   6. Analyze call sites
%   7. Validate signatures
%   8. Audit file organization
%   9. Generate comprehensive report
%
% Usage:
%   report = verifyFlorentCodebase()

function report = verifyFlorentCodebase()
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT CODEBASE VERIFICATION\n');
    fprintf('========================================\n\n');
    
    tic;
    
    report = struct();
    report.timestamp = now;
    report.phases = {};
    report.overallStatus = 'success';
    
    % Phase 1: Initialize paths
    fprintf('Phase 1: Initializing paths...\n');
    try
        initializeFlorent(false); % Don't save path
        report.phases{end+1} = struct('name', 'Path Initialization', 'status', 'success');
        fprintf('  [OK] Paths initialized\n\n');
    catch ME
        report.phases{end+1} = struct('name', 'Path Initialization', 'status', 'error', 'error', ME.message);
        report.overallStatus = 'error';
        fprintf('  [ERROR] %s\n\n', ME.message);
    end
    
    % Phase 2: Verify paths
    fprintf('Phase 2: Verifying paths...\n');
    try
        pathReport = verifyPaths();
        report.pathReport = pathReport;
        if strcmp(pathReport.status, 'success')
            report.phases{end+1} = struct('name', 'Path Verification', 'status', 'success');
            fprintf('  [OK] Paths verified\n\n');
        else
            report.phases{end+1} = struct('name', 'Path Verification', 'status', 'warning');
            report.overallStatus = 'warning';
            fprintf('  [WARNING] Path issues found\n\n');
        end
    catch ME
        report.phases{end+1} = struct('name', 'Path Verification', 'status', 'error', 'error', ME.message);
        report.overallStatus = 'error';
        fprintf('  [ERROR] %s\n\n', ME.message);
    end
    
    % Phase 3: Discover functions
    fprintf('Phase 3: Discovering functions...\n');
    try
        registry = discoverFunctions();
        report.registry = registry;
        report.phases{end+1} = struct('name', 'Function Discovery', 'status', 'success');
        fprintf('  [OK] Functions discovered\n\n');
    catch ME
        report.phases{end+1} = struct('name', 'Function Discovery', 'status', 'error', 'error', ME.message);
        report.overallStatus = 'error';
        fprintf('  [ERROR] %s\n\n', ME.message);
        return; % Can't continue without registry
    end
    
    % Phase 4: Parse dependencies
    fprintf('Phase 4: Parsing dependencies...\n');
    try
        [dependencies, callGraph] = parseDependencies(registry);
        report.dependencies = dependencies;
        report.callGraph = callGraph;
        report.phases{end+1} = struct('name', 'Dependency Parsing', 'status', 'success');
        fprintf('  [OK] Dependencies parsed\n\n');
    catch ME
        report.phases{end+1} = struct('name', 'Dependency Parsing', 'status', 'error', 'error', ME.message);
        report.overallStatus = 'error';
        fprintf('  [ERROR] %s\n\n', ME.message);
        dependencies = containers.Map();
    end
    
    % Phase 5: Verify dependencies
    fprintf('Phase 5: Verifying dependencies...\n');
    try
        depReport = verifyDependencies(registry, dependencies);
        report.dependencyReport = depReport;
        if strcmp(depReport.status, 'success')
            report.phases{end+1} = struct('name', 'Dependency Verification', 'status', 'success');
            fprintf('  [OK] Dependencies verified\n\n');
        else
            report.phases{end+1} = struct('name', 'Dependency Verification', 'status', depReport.status);
            if strcmp(depReport.status, 'error')
                report.overallStatus = 'error';
            elseif ~strcmp(report.overallStatus, 'error')
                report.overallStatus = 'warning';
            end
            fprintf('  [%s] Dependency issues found\n\n', upper(depReport.status));
        end
    catch ME
        report.phases{end+1} = struct('name', 'Dependency Verification', 'status', 'error', 'error', ME.message);
        report.overallStatus = 'error';
        fprintf('  [ERROR] %s\n\n', ME.message);
    end
    
    % Phase 6: Extract signatures
    fprintf('Phase 6: Extracting signatures...\n');
    try
        signatures = extractSignatures(registry);
        report.signatures = signatures;
        report.phases{end+1} = struct('name', 'Signature Extraction', 'status', 'success');
        fprintf('  [OK] Signatures extracted\n\n');
    catch ME
        report.phases{end+1} = struct('name', 'Signature Extraction', 'status', 'error', 'error', ME.message);
        report.overallStatus = 'error';
        fprintf('  [ERROR] %s\n\n', ME.message);
        signatures = containers.Map();
    end
    
    % Phase 7: Analyze call sites
    fprintf('Phase 7: Analyzing call sites...\n');
    try
        callSiteReport = analyzeCallSites(registry, dependencies, signatures);
        report.callSiteReport = callSiteReport;
        if strcmp(callSiteReport.status, 'success')
            report.phases{end+1} = struct('name', 'Call Site Analysis', 'status', 'success');
            fprintf('  [OK] Call sites analyzed\n\n');
        else
            report.phases{end+1} = struct('name', 'Call Site Analysis', 'status', callSiteReport.status);
            if strcmp(callSiteReport.status, 'error')
                report.overallStatus = 'error';
            elseif ~strcmp(report.overallStatus, 'error')
                report.overallStatus = 'warning';
            end
            fprintf('  [%s] Call site issues found\n\n', upper(callSiteReport.status));
        end
    catch ME
        report.phases{end+1} = struct('name', 'Call Site Analysis', 'status', 'error', 'error', ME.message);
        report.overallStatus = 'error';
        fprintf('  [ERROR] %s\n\n', ME.message);
    end
    
    % Phase 8: Validate signatures
    fprintf('Phase 8: Validating signatures...\n');
    try
        sigReport = validateSignatures(registry, signatures);
        report.signatureReport = sigReport;
        if strcmp(sigReport.status, 'success')
            report.phases{end+1} = struct('name', 'Signature Validation', 'status', 'success');
            fprintf('  [OK] Signatures validated\n\n');
        else
            report.phases{end+1} = struct('name', 'Signature Validation', 'status', sigReport.status);
            if ~strcmp(report.overallStatus, 'error')
                report.overallStatus = 'warning';
            end
            fprintf('  [%s] Signature issues found\n\n', upper(sigReport.status));
        end
    catch ME
        report.phases{end+1} = struct('name', 'Signature Validation', 'status', 'error', 'error', ME.message);
        fprintf('  [ERROR] %s\n\n', ME.message);
    end
    
    % Phase 9: Detect multi-function files
    fprintf('Phase 9: Detecting multi-function files...\n');
    try
        multiFuncReport = detectMultiFunctionFiles(registry, dependencies);
        report.multiFunctionReport = multiFuncReport;
        if strcmp(multiFuncReport.status, 'success')
            report.phases{end+1} = struct('name', 'Multi-Function Detection', 'status', 'success');
            fprintf('  [OK] Multi-function files checked\n\n');
        else
            report.phases{end+1} = struct('name', 'Multi-Function Detection', 'status', multiFuncReport.status);
            if strcmp(multiFuncReport.status, 'error')
                report.overallStatus = 'error';
            elseif ~strcmp(report.overallStatus, 'error')
                report.overallStatus = 'warning';
            end
            fprintf('  [%s] Multi-function file issues found\n\n', upper(multiFuncReport.status));
        end
    catch ME
        report.phases{end+1} = struct('name', 'Multi-Function Detection', 'status', 'error', 'error', ME.message);
        fprintf('  [ERROR] %s\n\n', ME.message);
    end
    
    % Phase 10: Validate function placement
    fprintf('Phase 10: Validating function placement...\n');
    try
        placementReport = validateFunctionPlacement(registry, dependencies);
        report.placementReport = placementReport;
        if strcmp(placementReport.status, 'success')
            report.phases{end+1} = struct('name', 'Function Placement', 'status', 'success');
            fprintf('  [OK] Function placement validated\n\n');
        else
            report.phases{end+1} = struct('name', 'Function Placement', 'status', placementReport.status);
            if ~strcmp(report.overallStatus, 'error')
                report.overallStatus = 'warning';
            end
            fprintf('  [%s] Placement issues found\n\n', upper(placementReport.status));
        end
    catch ME
        report.phases{end+1} = struct('name', 'Function Placement', 'status', 'error', 'error', ME.message);
        fprintf('  [ERROR] %s\n\n', ME.message);
    end
    
    % Final summary
    elapsed = toc;
    
    fprintf('========================================\n');
    fprintf('  VERIFICATION COMPLETE\n');
    fprintf('========================================\n');
    fprintf('Overall Status: %s\n', upper(report.overallStatus));
    fprintf('Time elapsed: %.2f seconds\n', elapsed);
    fprintf('Phases completed: %d\n', length(report.phases));
    
    % Count issues
    errorCount = 0;
    warningCount = 0;
    for i = 1:length(report.phases)
        if strcmp(report.phases{i}.status, 'error')
            errorCount = errorCount + 1;
        elseif strcmp(report.phases{i}.status, 'warning')
            warningCount = warningCount + 1;
        end
    end
    
    fprintf('Phases with errors: %d\n', errorCount);
    fprintf('Phases with warnings: %d\n', warningCount);
    fprintf('========================================\n\n');
    
    % Generate recommendations
    if ~strcmp(report.overallStatus, 'success')
        fprintf('Recommendations:\n');
        fprintf('  1. Run initializeFlorent() to set up paths\n');
        fprintf('  2. Review and fix issues reported above\n');
        fprintf('  3. Re-run verification after fixes\n');
        fprintf('\n');
    end
    
    % Auto-generate dependencies documentation
    try
        if isfield(report, 'registry') && isfield(report, 'dependencies')
            matlabDir = fileparts(fileparts(mfilename('fullpath')));
            depsFile = fullfile(matlabDir, 'DEPENDENCIES.md');
            generateDependenciesDoc(report.registry, report.dependencies, depsFile);
            fprintf('Dependencies documentation updated: %s\n', depsFile);
        end
    catch ME
        warning('Failed to generate dependencies documentation: %s', ME.message);
    end
end

