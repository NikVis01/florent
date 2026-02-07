function signatures = extractSignatures(registry)
    % EXTRACTSIGNATURES Extract function signatures from source
    %
    % Usage:
    %   signatures = extractSignatures()
    %   signatures = extractSignatures(registry)
    %
    % Output:
    %   signatures - Structure mapping function names to signature info:
    %     .inputs - Cell array of input argument names
    %     .outputs - Cell array of output argument names
    %     .nargin - Number of required inputs
    %     .nargout - Number of outputs
    %     .hasVarargin - Boolean for variable inputs
    %     .hasVarargout - Boolean for variable outputs
    %     .defaults - Structure with default values
    
    if nargin < 1
        registry = discoverFunctions();
    end
    
    fprintf('\n=== Extracting Function Signatures ===\n\n');
    
    signatures = containers.Map();
    
    % Process each main function
    extractedCount = 0;
    for i = 1:length(registry.functions)
        if ~strcmp(registry.types{i}, 'main')
            continue;
        end
        
        funcName = registry.functions{i};
        filePath = registry.files{i};
        
        fprintf('Extracting: %s\n', funcName);
        
        sig = parseFunctionSignature(filePath, funcName);
        if ~isempty(sig)
            signatures(funcName) = sig;
            extractedCount = extractedCount + 1;
            fprintf('  Inputs: %d, Outputs: %d\n', length(sig.inputs), length(sig.outputs));
        end
    end
    
    fprintf('\n=== Signature Extraction Summary ===\n');
    fprintf('Signatures extracted: %d\n', extractedCount);
    fprintf('\n');
end

function sig = parseFunctionSignature(filePath, funcName)
    % Parse function signature from file
    
    sig = struct();
    sig.inputs = {};
    sig.outputs = {};
    sig.nargin = 0;
    sig.nargout = 0;
    sig.hasVarargin = false;
    sig.hasVarargout = false;
    sig.defaults = struct();
    sig.narginChecks = [];
    sig.nargoutChecks = [];
    
    try
        fid = fopen(filePath, 'r');
        if fid == -1
            return;
        end
        
        fileContent = fread(fid, '*char')';
        fclose(fid);
        
        lines = strsplit(fileContent, '\n');
        
        % Find function declaration
        funcPattern = sprintf('^\\s*function\\s+(?:\\[([^\\]]+)\\]\\s*=\\s*)?%s\\s*\\(([^)]*)\\)', funcName);
        
        for lineIdx = 1:length(lines)
            line = lines{lineIdx};
            
            % Skip comments
            if startsWith(strtrim(line), '%')
                continue;
            end
            
            % Match function declaration
            tokens = regexp(line, funcPattern, 'tokens', 'once');
            
            if ~isempty(tokens)
                % Parse outputs
                if ~isempty(tokens{1})
                    outputStr = tokens{1};
                    sig.outputs = parseArgumentList(outputStr);
                end
                
                % Parse inputs
                if length(tokens) >= 2 && ~isempty(tokens{end})
                    inputStr = tokens{end};
                    sig.inputs = parseArgumentList(inputStr);
                end
                
                % Check for varargin/varargout
                sig.hasVarargin = ismember('varargin', sig.inputs);
                sig.hasVarargout = ismember('varargout', sig.outputs);
                
                % Count required inputs (before varargin)
                if sig.hasVarargin
                    vararginIdx = find(strcmp(sig.inputs, 'varargin'));
                    sig.nargin = vararginIdx - 1;
                else
                    sig.nargin = length(sig.inputs);
                end
                
                sig.nargout = length(sig.outputs);
                
                % Look for nargin/nargout checks and defaults in function body
                [defaults, narginChecks, nargoutChecks] = parseFunctionBody(lines(lineIdx+1:end));
                sig.defaults = defaults;
                sig.narginChecks = narginChecks;
                sig.nargoutChecks = nargoutChecks;
                
                break;
            end
        end
        
    catch ME
        warning('Error parsing signature for %s: %s', funcName, ME.message);
    end
end

function args = parseArgumentList(argStr)
    % Parse comma-separated argument list
    
    args = {};
    if isempty(argStr)
        return;
    end
    
    % Split by comma, handling nested parentheses
    parts = {};
    current = '';
    depth = 0;
    
    for i = 1:length(argStr)
        char = argStr(i);
        if char == '('
            depth = depth + 1;
            current = [current, char];
        elseif char == ')'
            depth = depth - 1;
            current = [current, char];
        elseif char == ',' && depth == 0
            parts{end+1} = strtrim(current);
            current = '';
        else
            current = [current, char];
        end
    end
    
    if ~isempty(current)
        parts{end+1} = strtrim(current);
    end
    
    args = parts;
end

function [defaults, narginChecks, nargoutChecks] = parseFunctionBody(bodyLines)
    % Parse function body for default values and nargin/nargout checks
    
    defaults = struct();
    narginChecks = [];
    nargoutChecks = [];
    
    for i = 1:min(50, length(bodyLines)) % Check first 50 lines
        line = bodyLines{i};
        
        % Skip comments
        if startsWith(strtrim(line), '%')
            continue;
        end
        
        % Look for nargin checks
        narginMatch = regexp(line, 'nargin\s*[<>=]+\s*(\d+)', 'tokens', 'once');
        if ~isempty(narginMatch)
            narginChecks(end+1) = str2double(narginMatch{1});
        end
        
        % Look for nargout checks
        nargoutMatch = regexp(line, 'nargout\s*[<>=]+\s*(\d+)', 'tokens', 'once');
        if ~isempty(nargoutMatch)
            nargoutChecks(end+1) = str2double(nargoutMatch{1});
        end
        
        % Look for default assignments: if nargin < N, var = default
        defaultMatch = regexp(line, 'if\s+nargin\s*<\s*(\d+).*?(\w+)\s*=\s*([^;]+)', 'tokens', 'once');
        if ~isempty(defaultMatch) && length(defaultMatch) >= 3
            argNum = str2double(defaultMatch{1});
            argName = defaultMatch{2};
            defaultVal = strtrim(defaultMatch{3});
            defaults.(argName) = defaultVal;
        end
    end
end

