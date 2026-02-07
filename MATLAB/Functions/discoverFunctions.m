function registry = discoverFunctions()
    % DISCOVERFUNCTIONS Automatically discover all functions in codebase
    %
    % Usage:
    %   registry = discoverFunctions()
    %
    % Output:
    %   registry - Structure with function information:
    %     .functions - Cell array of function names
    %     .files - Cell array of file paths
    %     .types - Cell array of types ('main' or 'local')
    %     .locations - Structure mapping function names to file info
    
    fprintf('\n=== Discovering Functions ===\n\n');
    
    % Get MATLAB directory
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    
    % Directories to scan
    scanDirs = {
        fullfile(matlabDir, 'Functions');
        fullfile(matlabDir, 'Scripts');
        fullfile(matlabDir, 'Config');
    };
    
    registry = struct();
    registry.functions = {};
    registry.files = {};
    registry.types = {};
    registry.locations = containers.Map();
    registry.localFunctions = containers.Map();
    
    totalFiles = 0;
    totalFunctions = 0;
    
    % Scan each directory
    for dirIdx = 1:length(scanDirs)
        scanDir = scanDirs{dirIdx};
        
        if ~exist(scanDir, 'dir')
            continue;
        end
        
        fprintf('Scanning: %s\n', scanDir);
        
        % Find all .m files
        mFiles = dir(fullfile(scanDir, '**', '*.m'));
        
        for fileIdx = 1:length(mFiles)
            filePath = fullfile(mFiles(fileIdx).folder, mFiles(fileIdx).name);
            totalFiles = totalFiles + 1;
            
            % Skip if it's a backup file
            if endsWith(mFiles(fileIdx).name, '.asv')
                continue;
            end
            
            % Parse file for functions
            [funcNames, funcTypes] = parseFileForFunctions(filePath);
            
            for funcIdx = 1:length(funcNames)
                funcName = funcNames{funcIdx};
                funcType = funcTypes{funcIdx};
                
                totalFunctions = totalFunctions + 1;
                
                % Add to registry
                registry.functions{end+1} = funcName;
                registry.files{end+1} = filePath;
                registry.types{end+1} = funcType;
                
                % Store in map
                if ~isKey(registry.locations, funcName)
                    registry.locations(funcName) = struct('files', {}, 'types', {});
                end
                
                fileInfo = registry.locations(funcName);
                fileInfo.files{end+1} = filePath;
                fileInfo.types{end+1} = funcType;
                registry.locations(funcName) = fileInfo;
                
                % Track local functions
                if strcmp(funcType, 'local')
                    if ~isKey(registry.localFunctions, filePath)
                        registry.localFunctions(filePath) = {};
                    end
                    localList = registry.localFunctions(filePath);
                    localList{end+1} = funcName;
                    registry.localFunctions(filePath) = localList;
                end
                
                fprintf('  [%s] %s in %s\n', funcType, funcName, mFiles(fileIdx).name);
            end
        end
    end
    
    % Summary
    fprintf('\n=== Function Discovery Summary ===\n');
    fprintf('Files scanned: %d\n', totalFiles);
    fprintf('Total functions found: %d\n', totalFunctions);
    
    mainCount = sum(strcmp(registry.types, 'main'));
    localCount = sum(strcmp(registry.types, 'local'));
    
    fprintf('Main functions: %d\n', mainCount);
    fprintf('Local functions: %d\n', localCount);
    
    % Check for duplicates
    uniqueFuncs = unique(registry.functions);
    if length(uniqueFuncs) < length(registry.functions)
        duplicates = registry.functions;
        [~, idx] = unique(duplicates);
        duplicates(idx) = [];
        duplicates = unique(duplicates);
        
        fprintf('\n[WARNING] Duplicate function names found:\n');
        for i = 1:length(duplicates)
            funcName = duplicates{i};
            fileInfo = registry.locations(funcName);
            fprintf('  %s appears in:\n', funcName);
            for j = 1:length(fileInfo.files)
                fprintf('    - %s (%s)\n', fileInfo.files{j}, fileInfo.types{j});
            end
        end
    end
    
    fprintf('\n');
end

function [funcNames, funcTypes] = parseFileForFunctions(filePath)
    % Parse a .m file to extract function names and types
    
    funcNames = {};
    funcTypes = {};
    
    try
        % Read file
        fid = fopen(filePath, 'r');
        if fid == -1
            return;
        end
        
        fileContent = fread(fid, '*char')';
        fclose(fid);
        
        % Split into lines
        lines = strsplit(fileContent, '\n');
        
        % Pattern to match function declarations
        % Matches: function [outputs] = functionName(inputs)
        funcPattern = '^\s*function\s+(?:\[[^\]]+\]\s*=\s*)?(\w+)\s*\([^)]*\)';
        
        for lineIdx = 1:length(lines)
            line = lines{lineIdx};
            
            % Skip comments
            if startsWith(strtrim(line), '%')
                continue;
            end
            
            % Try to match function declaration
            tokens = regexp(line, funcPattern, 'tokens', 'once');
            
            if ~isempty(tokens)
                funcName = tokens{1};
                
                % Determine if main or local function
                % First function in file is main, others are local
                if isempty(funcNames)
                    funcType = 'main';
                else
                    funcType = 'local';
                end
                
                funcNames{end+1} = funcName;
                funcTypes{end+1} = funcType;
            end
        end
        
    catch ME
        warning('Error parsing file %s: %s', filePath, ME.message);
    end
end

