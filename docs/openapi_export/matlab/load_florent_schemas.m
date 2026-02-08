function schemas = load_florent_schemas()
    % LOAD_FLORENT_SCHEMAS Load all Florent API schemas
    %
    % Returns:
    %   schemas - Struct containing all API schemas and endpoints
    %
    % Example:
    %   schemas = load_florent_schemas();
    %   request_schema = schemas.schemas.AnalysisRequest.schema;
    %   analyze_endpoint = schemas.endpoints.AnalyzeAnalyzeProject;

    % Get directory of this script
    script_dir = fileparts(mfilename('fullpath'));
    base_dir = fullfile(script_dir, '..');

    % Load component schemas
    schemas.schemas = struct();

    try
        schemas.schemas.AnalysisRequest = jsondecode(fileread(fullfile(base_dir, 'schemas', 'AnalysisRequest.json')));
    catch
        warning('Failed to load schema: AnalysisRequest');
    end


    % Load endpoint structures
    schemas.endpoints = struct();

    try
        schemas.endpoints.HealthCheck = jsondecode(fileread(fullfile(base_dir, 'endpoints', 'HealthCheck.json')));
    catch
        warning('Failed to load endpoint: HealthCheck');
    end

    try
        schemas.endpoints.AnalyzeAnalyzeProject = jsondecode(fileread(fullfile(base_dir, 'endpoints', 'AnalyzeAnalyzeProject.json')));
    catch
        warning('Failed to load endpoint: AnalyzeAnalyzeProject');
    end


    fprintf('✓ Loaded %d schemas and %d endpoints\n', ...
        length(fieldnames(schemas.schemas)), ...
        length(fieldnames(schemas.endpoints)));

end


function example_json = create_analysis_request(firm_path, project_path, budget)
    % CREATE_ANALYSIS_REQUEST Create analysis request JSON
    %
    % Args:
    %   firm_path - Path to firm.json
    %   project_path - Path to project.json
    %   budget - Evaluation budget (default: 100)
    %
    % Returns:
    %   example_json - JSON string ready to send to API

    if nargin < 3
        budget = 100;
    end

    request = struct();
    request.firm_path = firm_path;
    request.project_path = project_path;
    request.budget = budget;

    example_json = jsonencode(request);
end
