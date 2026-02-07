function report = analyzeCallSites(registry, dependencies, signatures)
    % ANALYZECALLSITES Analyze how functions are called
    %
    % Usage:
    %   report = analyzeCallSites()
    %   report = analyzeCallSites(registry, dependencies, signatures)
    %
    % Output:
    %   report - Structure with call site analysis results
    
    if nargin < 1
        registry = discoverFunctions();
    end
    if nargin < 2
        [dependencies, ~] = parseDependencies(registry);
    end
    if nargin < 3
        signatures = extractSignatures(registry);
    end
    
    fprintf('\n=== Analyzing Call Sites ===\n\n');
    
    report = struct();
    report.mismatches = {};
    report.missingRequiredArgs = {};
    report.excessiveArgs = {};
    report.status = 'success';
    
    % Analyze each function call
    funcNames = keys(dependencies);
    totalCalls = 0;
    mismatchCount = 0;
    
    for i = 1:length(funcNames)
        caller = funcNames{i};
        calledFuncs = dependencies(caller);
        
        % Get caller's file to analyze call sites
        callerFile = '';
        for j = 1:length(registry.functions)
            if strcmp(registry.functions{j}, caller)
                callerFile = registry.files{j};
                break;
            end
        end
        
        if isempty(callerFile)
            continue;
        end
        
        % Analyze each function call in caller's file
        for j = 1:length(calledFuncs)
            callee = calledFuncs{j};
            totalCalls = totalCalls + 1;
            
            % Skip if callee is not in signatures (might be built-in or local)
            if ~isKey(signatures, callee)
                continue;
            end
            
            calleeSig = signatures(callee);
            
            % Find call sites in caller's file
            callSites = findCallSites(callerFile, callee);
            
            for k = 1:length(callSites)
                callSite = callSites{k};
                argCount = callSite.argCount;
                
                % Compare with signature
                requiredArgs = calleeSig.nargin;
                maxArgs = requiredArgs;
                if calleeSig.hasVarargin
                    maxArgs = inf;
                end
                
                if argCount < requiredArgs
                    mismatchCount = mismatchCount + 1;
                    issue = struct();
                    issue.caller = caller;
                    issue.callee = callee;
                    issue.callSite = callSite.line;
                    issue.expected = requiredArgs;
                    issue.actual = argCount;
                    issue.type = 'missing_args';
                    report.mismatches{end+1} = issue;
                    report.missingRequiredArgs{end+1} = issue;
                    fprintf('  [ERROR] %s -> %s: Expected %d args, got %d (line %d)\n', ...
                        caller, callee, requiredArgs, argCount, callSite.line);
                    report.status = 'error';
                elseif argCount > maxArgs && ~isinf(maxArgs)
                    mismatchCount = mismatchCount + 1;
                    issue = struct();
                    issue.caller = caller;
                    issue.callee = callee;
                    issue.callSite = callSite.line;
                    issue.expected = maxArgs;
                    issue.actual = argCount;
                    issue.type = 'excessive_args';
                    report.mismatches{end+1} = issue;
                    report.excessiveArgs{end+1} = issue;
                    fprintf('  [WARNING] %s -> %s: Expected max %d args, got %d (line %d)\n', ...
                        caller, callee, maxArgs, argCount, callSite.line);
                else
                    fprintf('  [OK] %s -> %s: %d args\n', caller, callee, argCount);
                end
            end
        end
    end
    
    fprintf('\n=== Call Site Analysis Summary ===\n');
    fprintf('Total calls analyzed: %d\n', totalCalls);
    fprintf('Mismatches found: %d\n', mismatchCount);
    fprintf('Missing required args: %d\n', length(report.missingRequiredArgs));
    fprintf('Excessive args: %d\n', length(report.excessiveArgs));
    
    if strcmp(report.status, 'success')
        fprintf('\n[SUCCESS] All call sites match function signatures!\n');
    else
        fprintf('\n[ERROR] Some call sites have argument mismatches.\n');
    end
    
    fprintf('\n');
end

function callSites = findCallSites(filePath, funcName)
    % Find all call sites of a function in a file
    
    callSites = {};
    
    try
        fid = fopen(filePath, 'r');
        if fid == -1
            return;
        end
        
        fileContent = fread(fid, '*char')';
        fclose(fid);
        
        lines = strsplit(fileContent, '\n');
        
        % Pattern to match function calls: funcName(args)
        pattern = sprintf('\\b%s\\s*\\(', funcName);
        
        for lineIdx = 1:length(lines)
            line = lines{lineIdx};
            
            % Skip comments
            if startsWith(strtrim(line), '%')
                continue;
            end
            
            % Check if line contains function call
            if ~isempty(regexp(line, pattern, 'once'))
                % Count arguments
                argCount = countArguments(line, funcName);
                
                callSite = struct();
                callSite.line = lineIdx;
                callSite.argCount = argCount;
                callSite.code = strtrim(line);
                callSites{end+1} = callSite;
            end
        end
        
    catch ME
        warning('Error finding call sites in %s: %s', filePath, ME.message);
    end
end

function count = countArguments(line, funcName)
    % Count arguments in a function call
    
    count = 0;
    
    % Find the opening parenthesis after function name
    funcIdx = regexp(line, ['\b', funcName, '\s*\('], 'once');
    if isempty(funcIdx)
        return;
    end
    
    % Find the matching closing parenthesis
    parenStart = funcIdx + length(funcName);
    while parenStart <= length(line) && line(parenStart) ~= '('
        parenStart = parenStart + 1;
    end
    
    if parenStart > length(line) || line(parenStart) ~= '('
        return;
    end
    
    % Count commas at the top level (not nested)
    depth = 0;
    argStart = parenStart + 1;
    
    for i = argStart:length(line)
        char = line(i);
        if char == '('
            depth = depth + 1;
        elseif char == ')'
            if depth == 0
                break;
            end
            depth = depth - 1;
        elseif char == ',' && depth == 0
            count = count + 1;
        end
    end
    
    % If there's any content between parentheses, add 1 (for first arg)
    content = strtrim(line(argStart:i-1));
    if ~isempty(content)
        count = count + 1;
    end
end

