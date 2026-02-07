function generateDependenciesDoc(registry, dependencies, outputFile)
    % GENERATEDEPENDENCIESDOC Auto-generate DEPENDENCIES.md documentation
    %
    % Usage:
    %   generateDependenciesDoc()
    %   generateDependenciesDoc(registry, dependencies, 'DEPENDENCIES.md')
    
    if nargin < 1
        registry = discoverFunctions();
    end
    if nargin < 2
        [dependencies, ~] = parseDependencies(registry);
    end
    if nargin < 3
        matlabDir = fileparts(fileparts(mfilename('fullpath')));
        outputFile = fullfile(matlabDir, 'DEPENDENCIES.md');
    end
    
    fprintf('Generating dependencies documentation...\n');
    
    fid = fopen(outputFile, 'w');
    if fid == -1
        error('Failed to create dependencies file: %s', outputFile);
    end
    
    try
        % Write header
        fprintf(fid, '# Florent MATLAB Dependencies\n\n');
        fprintf(fid, 'This document is auto-generated. Do not edit manually.\n\n');
        fprintf(fid, 'Generated: %s\n\n', datestr(now));
        fprintf(fid, '---\n\n');
        
        % Write dependency graph
        fprintf(fid, '## Dependency Graph\n\n');
        
        funcNames = keys(dependencies);
        for i = 1:length(funcNames)
            caller = funcNames{i};
            calledFuncs = dependencies(caller);
            
            if ~isempty(calledFuncs)
                fprintf(fid, '### %s\n\n', caller);
                fprintf(fid, 'Calls:\n');
                for j = 1:length(calledFuncs)
                    fprintf(fid, '- `%s`\n', calledFuncs{j});
                end
                fprintf(fid, '\n');
            end
        end
        
        % Write function locations
        fprintf(fid, '## Function Locations\n\n');
        
        mainFunctions = {};
        for i = 1:length(registry.functions)
            if strcmp(registry.types{i}, 'main')
                mainFunctions{end+1} = registry.functions{i};
            end
        end
        
        mainFunctions = sort(mainFunctions);
        
        for i = 1:length(mainFunctions)
            funcName = mainFunctions{i};
            % Find file
            for j = 1:length(registry.functions)
                if strcmp(registry.functions{j}, funcName)
                    filePath = registry.files{j};
                    relPath = extractRelativePath(filePath);
                    fprintf(fid, '- `%s` - %s\n', funcName, relPath);
                    break;
                end
            end
        end
        
        % Write statistics
        fprintf(fid, '\n## Statistics\n\n');
        fprintf(fid, '- Total functions: %d\n', length(mainFunctions));
        fprintf(fid, '- Functions with dependencies: %d\n', length(funcNames));
        
        % Count total dependencies
        totalDeps = 0;
        for i = 1:length(funcNames)
            totalDeps = totalDeps + length(dependencies(funcNames{i}));
        end
        fprintf(fid, '- Total dependencies: %d\n', totalDeps);
        
        fprintf('Dependencies documentation generated: %s\n', outputFile);
        
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    
    fclose(fid);
end

function relPath = extractRelativePath(fullPath)
    % Extract relative path from full path
    
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    
    if contains(fullPath, matlabDir)
        relPath = strrep(fullPath, [matlabDir, filesep], '');
    else
        relPath = fullPath;
    end
end

