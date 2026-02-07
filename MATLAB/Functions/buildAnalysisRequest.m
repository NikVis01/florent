function request = buildAnalysisRequest(projectId, firmId, budget)
    % BUILDANALYSISREQUEST Build AnalysisRequest structure from IDs
    %
    % This function constructs an AnalysisRequest payload for the /analyze
    % endpoint by loading firm and project JSON files.
    %
    % Usage:
    %   request = buildAnalysisRequest('proj_001', 'firm_001', 100)
    %   request = buildAnalysisRequest('proj_001', 'firm_001')  % budget defaults to 100
    %
    % Arguments:
    %   projectId - Project identifier (e.g., 'proj_001')
    %   firmId    - Firm identifier (e.g., 'firm_001')
    %   budget    - Analysis budget (optional, default: 100)
    %
    % Returns:
    %   request - AnalysisRequest structure matching OpenAPI schema
    
    if nargin < 3
        budget = 100;
    end
    
    % Get project root
    matlabDir = fileparts(fileparts(mfilename('fullpath')));
    projectRoot = fileparts(matlabDir);
    
    % Construct file paths
    firmPath = fullfile(projectRoot, 'src', 'data', 'poc', [firmId, '.json']);
    projectPath = fullfile(projectRoot, 'src', 'data', 'poc', [projectId, '.json']);
    
    % Check if files exist
    if ~exist(firmPath, 'file')
        error('Firm file not found: %s', firmPath);
    end
    if ~exist(projectPath, 'file')
        error('Project file not found: %s', projectPath);
    end
    
    % Build request structure
    % Use file paths (recommended approach per API docs)
    request = struct();
    request.firm_path = firmPath;
    request.project_path = projectPath;
    request.budget = budget;
    
    % Note: We could also load and include inline data with firm_data and project_data
    % but using paths is more efficient and matches the API's recommended approach
end

