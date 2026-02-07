function report = validateFunctionPlacement(registry, dependencies)
    % VALIDATEFUNCTIONPLACEMENT Verify functions are in correct locations
    %
    % Usage:
    %   report = validateFunctionPlacement()
    %   report = validateFunctionPlacement(registry, dependencies)
    %
    % Output:
    %   report - Structure with validation results
    
    if nargin < 1
        registry = discoverFunctions();
    end
    if nargin < 2
        [dependencies, ~] = parseDependencies(registry);
    end
    
    fprintf('\n=== Validating Function Placement ===\n\n');
    
    report = struct();
    report.duplicates = {};
    report.misplacedFunctions = {};
    report.recommendations = {};
    report.status = 'success';
    
    % Check for duplicate function names
    fprintf('Checking for duplicate function names...\n');
    funcCounts = containers.Map();
    for i = 1:length(registry.functions)
        funcName = registry.functions{i};
        if isKey(funcCounts, funcName)
            funcCounts(funcName) = funcCounts(funcName) + 1;
        else
            funcCounts(funcName) = 1;
        end
    end
    
    duplicateNames = {};
    funcNames = keys(funcCounts);
    for i = 1:length(funcNames)
        if funcCounts(funcNames{i}) > 1
            duplicateNames{end+1} = funcNames{i};
        end
    end
    
    if ~isempty(duplicateNames)
        report.status = 'error';
        for i = 1:length(duplicateNames)
            funcName = duplicateNames{i};
            locations = {};
            for j = 1:length(registry.functions)
                if strcmp(registry.functions{j}, funcName)
                    locations{end+1} = registry.files{j};
                end
            end
            
            issue = struct();
            issue.function = funcName;
            issue.locations = locations;
            report.duplicates{end+1} = issue;
            
            fprintf('  [ERROR] Duplicate function: %s\n', funcName);
            for j = 1:length(locations)
                fprintf('    - %s\n', locations{j});
            end
        end
    else
        fprintf('  [OK] No duplicate function names\n');
    end
    
    % Check function placement (called from multiple files should be in Functions/)
    fprintf('\nChecking function placement...\n');
    funcNames = keys(dependencies);
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    functionsDir = fullfile(matlabDir, 'Functions');
    scriptsDir = fullfile(matlabDir, 'Scripts');
    
    misplacedCount = 0;
    for i = 1:length(registry.functions)
        funcName = registry.functions{i};
        funcFile = registry.files{i};
        
        if ~strcmp(registry.types{i}, 'main')
            continue;
        end
        
        % Count how many files call this function
        callCount = 0;
        funcNames = keys(dependencies);
        for j = 1:length(funcNames)
            if isKey(dependencies, funcNames{j})
                if ismember(funcName, dependencies(funcNames{j}))
                    callCount = callCount + 1;
                end
            end
        end
        
        % If called from multiple files, should be in Functions/
        if callCount > 1
            if ~contains(funcFile, functionsDir)
                misplacedCount = misplacedCount + 1;
                issue = struct();
                issue.function = funcName;
                issue.currentLocation = funcFile;
                issue.recommendedLocation = fullfile(functionsDir, [funcName, '.m']);
                issue.callCount = callCount;
                report.misplacedFunctions{end+1} = issue;
                
                fprintf('  [WARNING] %s called from %d files but in Scripts/\n', ...
                    funcName, callCount);
                fprintf('    Current: %s\n', funcFile);
                fprintf('    Recommended: %s\n', issue.recommendedLocation);
                
                rec = sprintf('Move %s from %s to %s', funcName, ...
                    fileparts(funcFile), functionsDir);
                report.recommendations{end+1} = rec;
            end
        end
    end
    
    if misplacedCount == 0
        fprintf('  [OK] All functions are properly placed\n');
    end
    
    fprintf('\n=== Function Placement Validation Summary ===\n');
    fprintf('Duplicate functions: %d\n', length(report.duplicates));
    fprintf('Misplaced functions: %d\n', length(report.misplacedFunctions));
    fprintf('Recommendations: %d\n', length(report.recommendations));
    
    if strcmp(report.status, 'success') && misplacedCount == 0
        fprintf('\n[SUCCESS] All functions are properly placed!\n');
    else
        fprintf('\n[WARNING] Some function placement issues found.\n');
        if ~strcmp(report.status, 'success')
            report.status = 'warning';
        end
    end
    
    fprintf('\n');
end

