function [dependencies, callGraph] = parseDependencies(registry)
    % PARSEDEPENDENCIES Parse function calls from source code
    %
    % Usage:
    %   [dependencies, callGraph] = parseDependencies(registry)
    %
    % Input:
    %   registry - Function registry from discoverFunctions()
    %
    % Output:
    %   dependencies - Structure mapping function names to called functions
    %   callGraph - Adjacency structure showing function call relationships
    
    if nargin < 1
        registry = discoverFunctions();
    end
    
    fprintf('\n=== Parsing Dependencies ===\n\n');
    
    dependencies = containers.Map();
    callGraph = struct();
    callGraph.nodes = {};
    callGraph.edges = [];
    callGraph.adjacency = containers.Map();
    
    % Get all main functions (not local)
    mainFunctions = {};
    for i = 1:length(registry.functions)
        if strcmp(registry.types{i}, 'main')
            mainFunctions{end+1} = registry.functions{i};
        end
    end
    
    callGraph.nodes = mainFunctions;
    
    % Initialize adjacency
    for i = 1:length(mainFunctions)
        callGraph.adjacency(mainFunctions{i}) = {};
    end
    
    % Parse each file
    parsedCount = 0;
    for i = 1:length(registry.files)
        filePath = registry.files{i};
        funcName = registry.functions{i};
        
        % Only parse main functions (local functions are in same file)
        if ~strcmp(registry.types{i}, 'main')
            continue;
        end
        
        parsedCount = parsedCount + 1;
        fprintf('Parsing: %s\n', funcName);
        
        % Extract function calls from file
        calledFuncs = extractFunctionCalls(filePath);
        
        % Store dependencies
        dependencies(funcName) = calledFuncs;
        
        % Update call graph
        if isKey(callGraph.adjacency, funcName)
            callGraph.adjacency(funcName) = calledFuncs;
        end
        
        fprintf('  Calls %d functions\n', length(calledFuncs));
    end
    
    % Build edge list
    edgeCount = 0;
    for i = 1:length(mainFunctions)
        caller = mainFunctions{i};
        if isKey(dependencies, caller)
            callees = dependencies(caller);
            for j = 1:length(callees)
                callee = callees{j};
                % Only add edge if callee is also a main function
                if ismember(callee, mainFunctions)
                    edgeCount = edgeCount + 1;
                    callGraph.edges(edgeCount, :) = [find(strcmp(mainFunctions, caller)), ...
                        find(strcmp(mainFunctions, callee))];
                end
            end
        end
    end
    
    fprintf('\n=== Dependency Parsing Summary ===\n');
    fprintf('Functions parsed: %d\n', parsedCount);
    fprintf('Total dependencies found: %d\n', edgeCount);
    fprintf('\n');
end

function calledFuncs = extractFunctionCalls(filePath)
    % Extract function calls from a MATLAB file
    
    calledFuncs = {};
    
    try
        % Read file
        fid = fopen(filePath, 'r');
        if fid == -1
            return;
        end
        
        fileContent = fread(fid, '*char')';
        fclose(fid);
        
        % Remove comments and strings to avoid false matches
        fileContent = removeCommentsAndStrings(fileContent);
        
        % Patterns to match function calls:
        % 1. Direct calls: functionName(args)
        % 2. Function handles: @functionName
        % 3. String calls: feval('functionName', ...)
        % 4. Method calls: obj.functionName()
        
        % Pattern 1: Direct function calls
        % Matches: identifier( or identifier (with whitespace)
        pattern1 = '(\w+)\s*\(';
        matches1 = regexp(fileContent, pattern1, 'tokens');
        for i = 1:length(matches1)
            funcName = matches1{i}{1};
            % Filter out built-ins and common keywords
            if ~isBuiltInOrKeyword(funcName)
                calledFuncs{end+1} = funcName;
            end
        end
        
        % Pattern 2: Function handles
        pattern2 = '@(\w+)';
        matches2 = regexp(fileContent, pattern2, 'tokens');
        for i = 1:length(matches2)
            funcName = matches2{i}{1};
            if ~isBuiltInOrKeyword(funcName)
                calledFuncs{end+1} = funcName;
            end
        end
        
        % Pattern 3: String-based calls (feval, etc.)
        pattern3 = '(?:feval|eval)\s*\(\s*[''"](\w+)[''"]';
        matches3 = regexp(fileContent, pattern3, 'tokens');
        for i = 1:length(matches3)
            funcName = matches3{i}{1};
            if ~isBuiltInOrKeyword(funcName)
                calledFuncs{end+1} = funcName;
            end
        end
        
        % Remove duplicates
        calledFuncs = unique(calledFuncs);
        
    catch ME
        warning('Error parsing file %s: %s', filePath, ME.message);
    end
end

function cleaned = removeCommentsAndStrings(content)
    % Remove comments and string literals from code
    
    % Remove block comments %{ ... %}
    content = regexprep(content, '%\{[\s\S]*?%\}', '');
    
    % Remove line comments (but keep function declarations)
    lines = strsplit(content, '\n');
    cleanedLines = {};
    for i = 1:length(lines)
        line = lines{i};
        % Find comment start (but not in strings)
        commentIdx = regexp(line, '(?<!''[^'']*)%', 'once');
        if ~isempty(commentIdx)
            % Check if it's part of a string
            beforeComment = line(1:commentIdx-1);
            quoteCount = length(regexp(beforeComment, ''''));
            if mod(quoteCount, 2) == 0
                line = line(1:commentIdx-1);
            end
        end
        cleanedLines{end+1} = line;
    end
    cleaned = strjoin(cleanedLines, '\n');
    
    % Remove string literals (simplified - handles single quotes)
    % This is a simplified approach - full string removal is complex
    % For now, we'll keep strings as they might contain function names in feval calls
end

function isBuiltIn = isBuiltInOrKeyword(funcName)
    % Check if function name is a MATLAB built-in or keyword
    
    keywords = {'if', 'else', 'elseif', 'end', 'for', 'while', 'switch', ...
        'case', 'otherwise', 'try', 'catch', 'function', 'return', ...
        'break', 'continue', 'classdef', 'properties', 'methods', 'events'};
    
    isBuiltIn = ismember(funcName, keywords);
    
    % Check if it's a built-in by trying which
    if ~isBuiltIn
        funcPath = which(funcName);
        if ~isempty(funcPath) && contains(funcPath, matlabroot)
            isBuiltIn = true;
        end
    end
end

