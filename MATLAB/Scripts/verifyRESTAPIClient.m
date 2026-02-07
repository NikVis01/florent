function result = verifyRESTAPIClient()
    % VERIFYRESTAPICLIENT Verify MATLAB REST API Client Generator availability
    %
    % This function checks if the MATLAB REST API Client Generator is available
    % and can be used to generate clients from OpenAPI specifications.
    %
    % Returns:
    %   result - Structure with verification results
    %
    % Usage:
    %   result = verifyRESTAPIClient()
    
    result = struct();
    result.available = false;
    result.version = '';
    result.toolbox = '';
    result.errors = {};
    result.warnings = {};
    
    fprintf('\n=== MATLAB REST API Client Generator Verification ===\n\n');
    
    % Check MATLAB version (R2020b+ required)
    fprintf('1. Checking MATLAB version...\n');
    matlabVersion = version('-release');
    year = str2double(matlabVersion(1:4));
    release = matlabVersion(5);
    
    if year < 2020 || (year == 2020 && release < 'b')
        result.errors{end+1} = sprintf('MATLAB R2020b or newer required. Current: %s', matlabVersion);
        fprintf('  [FAIL] MATLAB version too old: %s\n', matlabVersion);
    else
        fprintf('  [OK] MATLAB version: %s\n', matlabVersion);
        result.version = matlabVersion;
    end
    
    % Check for Communications Toolbox
    fprintf('\n2. Checking for Communications Toolbox...\n');
    hasCommToolbox = license('test', 'Communication_Toolbox');
    if hasCommToolbox
        fprintf('  [OK] Communications Toolbox available\n');
        result.toolbox = 'Communications Toolbox';
        result.available = true;
    else
        fprintf('  [WARN] Communications Toolbox not found\n');
        result.warnings{end+1} = 'Communications Toolbox not available';
    end
    
    % Check for MATLAB Web App Server (alternative)
    fprintf('\n3. Checking for MATLAB Web App Server...\n');
    hasWebAppServer = license('test', 'MATLAB_Web_App_Server');
    if hasWebAppServer
        fprintf('  [OK] MATLAB Web App Server available\n');
        if ~result.available
            result.toolbox = 'MATLAB Web App Server';
            result.available = true;
        end
    else
        fprintf('  [WARN] MATLAB Web App Server not found\n');
        if ~result.available
            result.warnings{end+1} = 'MATLAB Web App Server not available';
        end
    end
    
    % Check if REST API Client Generator function exists
    fprintf('\n4. Checking for REST API Client Generator function...\n');
    if exist('restApiClient', 'file') == 2
        fprintf('  [OK] restApiClient function found\n');
    elseif exist('openapi', 'file') == 2
        fprintf('  [OK] openapi function found (alternative)\n');
    else
        fprintf('  [WARN] REST API Client Generator functions not found\n');
        result.warnings{end+1} = 'REST API Client Generator functions not found in path';
        fprintf('  [INFO] You may need to install the REST API Client Generator add-on\n');
        fprintf('         from MATLAB Add-On Explorer\n');
    end
    
    % Test with simple OpenAPI spec if available
    fprintf('\n5. Testing with OpenAPI spec...\n');
    % Try multiple possible locations for the OpenAPI spec
    scriptPath = mfilename('fullpath');
    rootPath = fileparts(fileparts(fileparts(scriptPath))); % Go up to project root
    openapiPath = fullfile(rootPath, 'docs', 'openapi.json');
    
    % If not found at root, try MATLAB/docs as fallback
    if ~exist(openapiPath, 'file')
        openapiPath = fullfile(fileparts(fileparts(scriptPath)), 'docs', 'openapi.json');
    end
    
    if exist(openapiPath, 'file')
        fprintf('  [OK] OpenAPI spec found: %s\n', openapiPath);
        try
            % Try to read and parse the JSON
            fid = fopen(openapiPath, 'r');
            if fid ~= -1
                jsonText = fread(fid, '*char')';
                fclose(fid);
                jsonData = jsondecode(jsonText);
                if isfield(jsonData, 'openapi') && isfield(jsonData, 'paths')
                    fprintf('  [OK] OpenAPI spec is valid JSON\n');
                    fprintf('  [INFO] OpenAPI version: %s\n', jsonData.openapi);
                    fprintf('  [INFO] Endpoints found: %d\n', length(fieldnames(jsonData.paths)));
                else
                    result.warnings{end+1} = 'OpenAPI spec structure may be incomplete';
                    fprintf('  [WARN] OpenAPI spec may be incomplete\n');
                end
            end
        catch ME
            result.warnings{end+1} = sprintf('Could not parse OpenAPI spec: %s', ME.message);
            fprintf('  [WARN] Could not parse OpenAPI spec: %s\n', ME.message);
        end
    else
        result.warnings{end+1} = 'OpenAPI spec file not found';
        fprintf('  [WARN] OpenAPI spec not found at: %s\n', openapiPath);
    end
    
    % Summary
    fprintf('\n=== Verification Summary ===\n');
    if result.available
        fprintf('[SUCCESS] REST API Client Generator is available\n');
        fprintf('  Toolbox: %s\n', result.toolbox);
        fprintf('  MATLAB Version: %s\n', result.version);
    else
        fprintf('[FAIL] REST API Client Generator is NOT available\n');
        fprintf('  You need either:\n');
        fprintf('    - Communications Toolbox, OR\n');
        fprintf('    - MATLAB Web App Server\n');
    end
    
    if ~isempty(result.warnings)
        fprintf('\nWarnings:\n');
        for i = 1:length(result.warnings)
            fprintf('  - %s\n', result.warnings{i});
        end
    end
    
    if ~isempty(result.errors)
        fprintf('\nErrors:\n');
        for i = 1:length(result.errors)
            fprintf('  - %s\n', result.errors{i});
        end
    end
    
    fprintf('\n');
end

