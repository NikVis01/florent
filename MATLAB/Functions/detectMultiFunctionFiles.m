function report = detectMultiFunctionFiles(registry, dependencies)
    % DETECTMULTIFUNCTIONFILES Identify files with multiple function declarations
    %
    % Usage:
    %   report = detectMultiFunctionFiles()
    %   report = detectMultiFunctionFiles(registry, dependencies)
    %
    % Output:
    %   report - Structure with detection results
    
    if nargin < 1
        registry = discoverFunctions();
    end
    if nargin < 2
        [dependencies, ~] = parseDependencies(registry);
    end
    
    fprintf('\n=== Detecting Multi-Function Files ===\n\n');
    
    report = struct();
    report.multiFunctionFiles = {};
    report.localFunctionsCalledExternally = {};
    report.recommendations = {};
    report.status = 'success';
    
    % Group functions by file
    fileMap = containers.Map();
    for i = 1:length(registry.files)
        filePath = registry.files{i};
        funcName = registry.functions{i};
        funcType = registry.types{i};
        
        if ~isKey(fileMap, filePath)
            fileMap(filePath) = struct('functions', {}, 'types', {});
        end
        
        fileInfo = fileMap(filePath);
        fileInfo.functions{end+1} = funcName;
        fileInfo.types{end+1} = funcType;
        fileMap(filePath) = fileInfo;
    end
    
    % Check each file
    filePaths = keys(fileMap);
    multiFunctionCount = 0;
    externalCallCount = 0;
    
    for i = 1:length(filePaths)
        filePath = filePaths{i};
        fileInfo = fileMap(filePath);
        
        if length(fileInfo.functions) > 1
            multiFunctionCount = multiFunctionCount + 1;
            
            fprintf('Multi-function file: %s\n', filePath);
            fprintf('  Functions: %s\n', strjoin(fileInfo.functions, ', '));
            
            % Identify main vs local functions
            mainFuncs = {};
            localFuncs = {};
            for j = 1:length(fileInfo.functions)
                if strcmp(fileInfo.types{j}, 'main')
                    mainFuncs{end+1} = fileInfo.functions{j};
                else
                    localFuncs{end+1} = fileInfo.functions{j};
                end
            end
            
            fprintf('  Main: %s\n', strjoin(mainFuncs, ', '));
            if ~isempty(localFuncs)
                fprintf('  Local: %s\n', strjoin(localFuncs, ', '));
            end
            
            % Check if local functions are called from other files
            for j = 1:length(localFuncs)
                localFunc = localFuncs{j};
                
                % Check if this local function is called from other files
                callers = findCallersOfFunction(localFunc, dependencies, registry, filePath);
                
                if ~isempty(callers)
                    externalCallCount = externalCallCount + 1;
                    issue = struct();
                    issue.file = filePath;
                    issue.function = localFunc;
                    issue.callers = callers;
                    report.localFunctionsCalledExternally{end+1} = issue;
                    
                    fprintf('  [ERROR] Local function %s called from:\n', localFunc);
                    for k = 1:length(callers)
                        fprintf('    - %s\n', callers{k});
                    end
                    report.status = 'error';
                end
            end
            
            % Generate recommendation
            if ~isempty(localFuncs) && externalCallCount > 0
                rec = sprintf('Move local function(s) %s from %s to separate file(s)', ...
                    strjoin(localFuncs, ', '), fileparts(filePath));
                report.recommendations{end+1} = rec;
                fprintf('  [RECOMMENDATION] %s\n', rec);
            end
            
            report.multiFunctionFiles{end+1} = struct('file', filePath, ...
                'functions', fileInfo.functions, 'types', fileInfo.types);
        end
    end
    
    fprintf('\n=== Multi-Function File Detection Summary ===\n');
    fprintf('Multi-function files: %d\n', multiFunctionCount);
    fprintf('Local functions called externally: %d\n', externalCallCount);
    fprintf('Recommendations: %d\n', length(report.recommendations));
    
    if strcmp(report.status, 'success')
        fprintf('\n[SUCCESS] No issues with multi-function files!\n');
    else
        fprintf('\n[ERROR] Some local functions are called from other files.\n');
    end
    
    fprintf('\n');
end

function callers = findCallersOfFunction(funcName, dependencies, registry, excludeFile)
    % Find all functions that call the given function
    
    callers = {};
    
    funcNames = keys(dependencies);
    for i = 1:length(funcNames)
        caller = funcNames{i};
        
        % Get caller's file
        callerFile = '';
        for j = 1:length(registry.functions)
            if strcmp(registry.functions{j}, caller)
                callerFile = registry.files{j};
                break;
            end
        end
        
        % Skip if same file
        if strcmp(callerFile, excludeFile)
            continue;
        end
        
        % Check if caller calls the function
        if isKey(dependencies, caller)
            calledFuncs = dependencies(caller);
            if ismember(funcName, calledFuncs)
                callers{end+1} = caller;
            end
        end
    end
end

