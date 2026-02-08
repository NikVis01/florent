function request = buildAnalysisRequest(projectId, firmId, budget, firmData, projectData)
    % BUILDANALYSISREQUEST Build AnalysisRequest structure from IDs or inline data
    %
    % This function constructs an AnalysisRequest payload for the /analyze
    % endpoint. It supports both inline data (firm_data, project_data) and
    % file paths. When inline data is provided, it is used; otherwise, the
    % backend should handle data lookup by ID.
    %
    % Usage:
    %   request = buildAnalysisRequest('proj_001', 'firm_001', 100)
    %   request = buildAnalysisRequest('proj_001', 'firm_001')  % budget defaults to 100
    %   request = buildAnalysisRequest('proj_001', 'firm_001', 100, firmData, projectData)
    %
    % Arguments:
    %   projectId  - Project identifier (e.g., 'proj_001')
    %   firmId     - Firm identifier (e.g., 'firm_001')
    %   budget     - Analysis budget (optional, default: 100)
    %   firmData   - Optional firm data structure (if provided, used instead of file path)
    %   projectData - Optional project data structure (if provided, used instead of file path)
    %
    % Returns:
    %   request - AnalysisRequest structure matching OpenAPI schema
    
    if nargin < 3
        budget = 100;
    end
    
    % Build request structure
    request = struct();
    request.budget = budget;
    
    % If inline data is provided, use it (preferred approach)
    if nargin >= 4 && ~isempty(firmData)
        if ischar(firmData) || isstring(firmData)
            % JSON string - parse it
            firmData = jsondecode(firmData);
        end
        request.firm_data = firmData;
    end
    % Note: If firmData is not provided, we don't set firm_path to avoid
    % static file dependencies. The backend should handle lookup by firmId
    % or the caller should provide firmData.
    
    if nargin >= 5 && ~isempty(projectData)
        if ischar(projectData) || isstring(projectData)
            % JSON string - parse it
            projectData = jsondecode(projectData);
        end
        request.project_data = projectData;
    end
    % Note: If projectData is not provided, we don't set project_path to avoid
    % static file dependencies. The backend should handle lookup by projectId
    % or the caller should provide projectData.
end

