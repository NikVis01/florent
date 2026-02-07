function generateFlorentClient(openapiPath, outputPath, baseUrl)
    % GENERATEFLORENTCLIENT Generate MATLAB REST API client from OpenAPI spec
    %
    % This function provides a convenient way to generate the MATLAB client
    % from the OpenAPI specification. It checks prerequisites and guides
    % through the generation process.
    %
    % Usage:
    %   generateFlorentClient()
    %   generateFlorentClient(openapiPath, outputPath, baseUrl)
    %
    % Arguments:
    %   openapiPath - Path to openapi.json file (default: docs/openapi.json)
    %   outputPath  - Output directory for generated client (default: MATLAB/Classes/FlorentAPIClient)
    %   baseUrl     - Base URL for API (default: http://localhost:8000)
    
    % Default arguments
    if nargin < 1 || isempty(openapiPath)
        projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
        openapiPath = fullfile(projectRoot, 'docs', 'openapi.json');
    end
    
    if nargin < 2 || isempty(outputPath)
        matlabDir = fileparts(fileparts(mfilename('fullpath')));
        outputPath = fullfile(matlabDir, 'Classes', 'FlorentAPIClient');
    end
    
    if nargin < 3 || isempty(baseUrl)
        baseUrl = 'http://localhost:8000';
    end
    
    fprintf('\n=== Florent MATLAB Client Generator ===\n\n');
    
    % Verify prerequisites
    fprintf('1. Verifying prerequisites...\n');
    result = verifyRESTAPIClient();
    
    if ~result.available
        error('REST API Client Generator not available. Please install Communications Toolbox or MATLAB Web App Server.');
    end
    
    fprintf('  [OK] Prerequisites met\n\n');
    
    % Check OpenAPI file
    fprintf('2. Checking OpenAPI specification...\n');
    if ~exist(openapiPath, 'file')
        error('OpenAPI file not found: %s', openapiPath);
    end
    
    try
        jsonText = fileread(openapiPath);
        jsonData = jsondecode(jsonText);
        if ~isfield(jsonData, 'openapi') || ~isfield(jsonData, 'paths')
            error('Invalid OpenAPI specification structure');
        end
        fprintf('  [OK] OpenAPI spec is valid\n');
        fprintf('  [INFO] OpenAPI version: %s\n', jsonData.openapi);
        fprintf('  [INFO] Endpoints: %d\n', length(fieldnames(jsonData.paths)));
    catch ME
        error('Failed to parse OpenAPI spec: %s', ME.message);
    end
    
    % Create output directory
    fprintf('\n3. Preparing output directory...\n');
    if ~exist(outputPath, 'dir')
        mkdir(outputPath);
        fprintf('  [OK] Created directory: %s\n', outputPath);
    else
        fprintf('  [INFO] Output directory exists: %s\n', outputPath);
        response = input('  Overwrite existing client? (y/n): ', 's');
        if ~strcmpi(response, 'y')
            fprintf('  [CANCELLED] Generation cancelled\n');
            return;
        end
    end
    
    % Generate client
    fprintf('\n4. Generating MATLAB client...\n');
    fprintf('  OpenAPI Path: %s\n', openapiPath);
    fprintf('  Output Path: %s\n', outputPath);
    fprintf('  Base URL: %s\n', baseUrl);
    fprintf('\n');
    
    generationSuccess = false;
    
    % Try restApiClient function first (if available)
    if exist('restApiClient', 'file') == 2
        fprintf('  Trying restApiClient function...\n');
        try
            % Note: Actual syntax may vary by MATLAB version
            restApiClient(openapiPath, 'OutputFolder', outputPath, ...
                         'ClassName', 'FlorentAPIClient', ...
                         'BaseURL', baseUrl);
            fprintf('  [OK] Client generated successfully using restApiClient\n');
            generationSuccess = true;
        catch ME
            fprintf('  [WARN] restApiClient failed: %s\n', ME.message);
        end
    end
    
    % Try openapi function as alternative (if restApiClient failed or not available)
    if ~generationSuccess && exist('openapi', 'file') == 2
        fprintf('  Trying openapi function (alternative)...\n');
        try
            % Try different possible syntaxes for openapi function
            % Syntax 1: openapi(spec, 'OutputFolder', path, 'ClassName', name, 'BaseURL', url)
            try
                openapi(openapiPath, 'OutputFolder', outputPath, ...
                       'ClassName', 'FlorentAPIClient', ...
                       'BaseURL', baseUrl);
                fprintf('  [OK] Client generated successfully using openapi\n');
                generationSuccess = true;
            catch ME1
                % Syntax 2: openapi(spec, 'OutputFolder', path)
                try
                    openapi(openapiPath, 'OutputFolder', outputPath);
                    fprintf('  [OK] Client generated successfully using openapi (basic syntax)\n');
                    generationSuccess = true;
                catch ME2
                    % Syntax 3: openapi(spec, outputPath)
                    try
                        openapi(openapiPath, outputPath);
                        fprintf('  [OK] Client generated successfully using openapi (simple syntax)\n');
                        generationSuccess = true;
                    catch ME3
                        fprintf('  [WARN] openapi function syntax not recognized\n');
                        fprintf('  [INFO] Tried multiple syntaxes, all failed\n');
                        fprintf('  [INFO] Error details: %s\n', ME1.message);
                    end
                end
            end
        catch ME
            fprintf('  [WARN] openapi function failed: %s\n', ME.message);
        end
    end
    
    % If all programmatic methods failed, provide GUI instructions
    if ~generationSuccess
        fprintf('\n  [INFO] Programmatic generation methods not available or failed\n');
        fprintf('  [INFO] Please use the GUI method:\n');
        fprintf('    1. Open: Apps → REST API Client Generator\n');
        fprintf('    2. Select OpenAPI file: %s\n', openapiPath);
        fprintf('    3. Set output folder: %s\n', outputPath);
        fprintf('    4. Set base URL: %s\n', baseUrl);
        fprintf('    5. Click Generate\n');
        fprintf('\n  [INFO] Or install the REST API Client Generator add-on\n');
        fprintf('         from MATLAB Add-On Explorer\n');
        return;
    end
    
    % Verify generation
    fprintf('\n5. Verifying generated client...\n');
    clientFile = fullfile(outputPath, 'FlorentAPIClient.m');
    if exist(clientFile, 'file')
        fprintf('  [OK] Client file generated: %s\n', clientFile);
        
        % Add to path
        addpath(outputPath);
        fprintf('  [OK] Added to MATLAB path\n');
        
        % Test instantiation
        try
            testClient = FlorentAPIClient(baseUrl);
            fprintf('  [OK] Client can be instantiated\n');
            clear testClient;
        catch ME
            fprintf('  [WARN] Client instantiation test failed: %s\n', ME.message);
        end
    else
        fprintf('  [WARN] Client file not found at expected location\n');
        fprintf('  [INFO] Check output directory: %s\n', outputPath);
    end
    
    fprintf('\n=== Generation Complete ===\n');
    fprintf('\nNext steps:\n');
    fprintf('  1. Test the client: testFlorentAPIClient()\n');
    fprintf('  2. Use the wrapper: client = FlorentAPIClientWrapper()\n');
    fprintf('  3. See documentation: MATLAB/docs/OPENAPI_CLIENT_SETUP.md\n');
    fprintf('\n');
end

