function report = verifyDependencies(registry, dependencies)
    % VERIFYDEPENDENCIES Verify all dependencies exist and are accessible
    %
    % Usage:
    %   report = verifyDependencies()
    %   report = verifyDependencies(registry, dependencies)
    %
    % Output:
    %   report - Structure with verification results
    
    if nargin < 1
        registry = discoverFunctions();
    end
    if nargin < 2
        [dependencies, ~] = parseDependencies(registry);
    end
    
    fprintf('\n=== Verifying Dependencies ===\n\n');
    
    report = struct();
    report.missingFunctions = {};
    report.unresolvedCalls = {};
    report.circularDependencies = {};
    report.shadowingIssues = {};
    report.warnings = {};
    report.status = 'success';
    
    % Get all known functions
    knownFunctions = registry.functions;
    mainFunctions = {};
    for i = 1:length(registry.functions)
        if strcmp(registry.types{i}, 'main')
            mainFunctions{end+1} = registry.functions{i};
        end
    end
    
    % Check each function's dependencies
    fprintf('Checking dependencies...\n');
    totalChecks = 0;
    failedChecks = 0;
    
    funcNames = keys(dependencies);
    for i = 1:length(funcNames)
        caller = funcNames{i};
        calledFuncs = dependencies(caller);
        
        fprintf('  %s:\n', caller);
        
        for j = 1:length(calledFuncs)
            callee = calledFuncs{j};
            totalChecks = totalChecks + 1;
            
            % Check if function exists
            funcPath = which(callee);
            
            if isempty(funcPath)
                % Check if it's a local function in the same file
                callerFile = '';
                for k = 1:length(registry.functions)
                    if strcmp(registry.functions{k}, caller)
                        callerFile = registry.files{k};
                        break;
                    end
                end
                
                % Check if callee is a local function in caller's file
                isLocal = false;
                if ~isempty(callerFile) && isKey(registry.localFunctions, callerFile)
                    localFuncs = registry.localFunctions(callerFile);
                    if ismember(callee, localFuncs)
                        isLocal = true;
                        fprintf('    [OK] %s (local function)\n', callee);
                    end
                end
                
                if ~isLocal
                    % Function not found
                    failedChecks = failedChecks + 1;
                    report.missingFunctions{end+1} = struct('caller', caller, 'callee', callee);
                    report.unresolvedCalls{end+1} = sprintf('%s -> %s', caller, callee);
                    fprintf('    [ERROR] Cannot find: %s\n', callee);
                    report.status = 'error';
                end
            else
                % Function found - check if it's accessible
                fprintf('    [OK] %s\n', callee);
                
                % Check for shadowing (custom function shadowing built-in)
                if contains(funcPath, fileparts(mfilename('fullpath')))
                    % It's our function - check if it shadows a built-in
                    builtInPath = which(callee, '-all');
                    if length(builtInPath) > 1
                        report.shadowingIssues{end+1} = struct('function', callee, 'paths', builtInPath);
                        fprintf('    [WARNING] %s may shadow built-in\n', callee);
                    end
                end
            end
        end
    end
    
    % Check for circular dependencies
    fprintf('\nChecking for circular dependencies...\n');
    callGraph = buildCallGraph(dependencies, mainFunctions);
    cycles = findCycles(callGraph, mainFunctions);
    
    if ~isempty(cycles)
        report.circularDependencies = cycles;
        report.status = 'warning';
        fprintf('  [WARNING] Circular dependencies found:\n');
        for i = 1:length(cycles)
            cycle = cycles{i};
            fprintf('    %s\n', strjoin(cycle, ' -> '));
        end
    else
        fprintf('  [OK] No circular dependencies\n');
    end
    
    % Summary
    fprintf('\n=== Dependency Verification Summary ===\n');
    fprintf('Total dependency checks: %d\n', totalChecks);
    fprintf('Failed checks: %d\n', failedChecks);
    fprintf('Missing functions: %d\n', length(report.missingFunctions));
    fprintf('Circular dependencies: %d\n', length(report.circularDependencies));
    fprintf('Shadowing issues: %d\n', length(report.shadowingIssues));
    
    if strcmp(report.status, 'success')
        fprintf('\n[SUCCESS] All dependencies are resolved!\n');
    else
        fprintf('\n[ERROR] Some dependencies are missing or problematic.\n');
    end
    
    fprintf('\n');
end

function callGraph = buildCallGraph(dependencies, mainFunctions)
    % Build adjacency list for call graph
    
    callGraph = containers.Map();
    
    for i = 1:length(mainFunctions)
        funcName = mainFunctions{i};
        callGraph(funcName) = {};
        
        if isKey(dependencies, funcName)
            calledFuncs = dependencies(funcName);
            % Only include main functions in graph
            for j = 1:length(calledFuncs)
                if ismember(calledFuncs{j}, mainFunctions)
                    callGraph(funcName){end+1} = calledFuncs{j};
                end
            end
        end
    end
end

function cycles = findCycles(callGraph, mainFunctions)
    % Find cycles in call graph using DFS
    
    cycles = {};
    visited = containers.Map();
    recStack = containers.Map();
    
    for i = 1:length(mainFunctions)
        visited(mainFunctions{i}) = false;
        recStack(mainFunctions{i}) = false;
    end
    
    for i = 1:length(mainFunctions)
        funcName = mainFunctions{i};
        if ~visited(funcName)
            cycle = dfsFindCycle(callGraph, funcName, visited, recStack, []);
            if ~isempty(cycle)
                cycles{end+1} = cycle;
            end
        end
    end
end

function cycle = dfsFindCycle(callGraph, node, visited, recStack, path)
    % DFS helper to find cycles
    
    cycle = [];
    visited(node) = true;
    recStack(node) = true;
    path{end+1} = node;
    
    if isKey(callGraph, node)
        neighbors = callGraph(node);
        for i = 1:length(neighbors)
            neighbor = neighbors{i};
            
            if recStack(neighbor)
                % Found cycle
                cycleStart = find(strcmp(path, neighbor), 1);
                cycle = path(cycleStart:end);
                cycle{end+1} = neighbor; % Close the cycle
                return;
            end
            
            if ~visited(neighbor)
                cycle = dfsFindCycle(callGraph, neighbor, visited, recStack, path);
                if ~isempty(cycle)
                    return;
                end
            end
        end
    end
    
    recStack(node) = false;
    path(end) = [];
end

