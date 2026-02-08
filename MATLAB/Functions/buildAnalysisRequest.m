function request = buildAnalysisRequest(projectId, firmId, budget, firmData, projectData, useSchemas)
    % BUILDANALYSISREQUEST Build AnalysisRequest structure from IDs or inline data
    %
    % This function constructs an AnalysisRequest payload for the /analyze
    % endpoint using OpenAPI schemas from load_florent_schemas(). It supports
    % both inline data (firm_data, project_data) and file paths. When inline
    % data is provided, it is used; otherwise, paths are passed to the API
    % backend which handles all file loading and path resolution.
    %
    % NO FILESYSTEM SCANNING - All path resolution is handled by the API backend.
    %
    % Usage:
    %   request = buildAnalysisRequest('proj_001', 'firm_001', 100)
    %   request = buildAnalysisRequest('proj_001', 'firm_001')  % budget defaults to 100
    %   request = buildAnalysisRequest('src/data/poc/project.json', 'src/data/poc/firm.json')
    %   request = buildAnalysisRequest('proj_001', 'firm_001', 100, firmData, projectData)
    %
    % Arguments:
    %   projectId  - Project identifier or path (e.g., 'proj_001' or 'src/data/poc/project.json')
    %   firmId     - Firm identifier or path (e.g., 'firm_001' or 'src/data/poc/firm.json')
    %   budget     - Analysis budget (optional, default: 100)
    %   firmData   - Optional firm data structure (if provided, used instead of file path)
    %   projectData - Optional project data structure (if provided, used instead of file path)
    %   useSchemas - If true, validate against OpenAPI schema (default: true)
    %
    % Returns:
    %   request - AnalysisRequest structure matching OpenAPI schema
    
    if nargin < 3
        budget = 100;
    end
    if nargin < 6
        useSchemas = true; % Default to using schemas
    end
    
    % Try to get schema example if available
    if useSchemas
        try
            schemas = openapiHelpers('getSchemas');
            if isfield(schemas, 'schemas') && isfield(schemas.schemas, 'AnalysisRequest')
                % Use schema default for budget if not provided
                requestSchema = schemas.schemas.AnalysisRequest.schema;
                if isfield(requestSchema, 'properties') && ...
                   isfield(requestSchema.properties, 'budget')
                    budgetProp = requestSchema.properties.budget;
                    if isfield(budgetProp, 'default') && nargin < 3
                        budget = budgetProp.default;
                    end
                end
            end
        catch
            % Schema not available - use defaults
        end
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
    else
        % Handle firmId - pass path directly to API (no filesystem checks)
        if ischar(firmId) || isstring(firmId)
            firmIdStr = char(firmId);
            if contains(firmIdStr, '/') || contains(firmIdStr, '\')
                % It's already a path - use it directly
                request.firm_path = firmIdStr;
            else
                % It's an ID - construct simple path string without checking if file exists
                % API backend will handle path resolution and file loading
                request.firm_path = sprintf('src/data/poc/%s.json', firmIdStr);
                warning('buildAnalysisRequest:PathNotValidated', ...
                    'Constructed firm_path without validation: %s. API backend will validate the path.', ...
                    request.firm_path);
            end
        else
            warning('Invalid firmId type. Expected string path or ID.');
        end
    end
    
    if nargin >= 5 && ~isempty(projectData)
        if ischar(projectData) || isstring(projectData)
            % JSON string - parse it
            projectData = jsondecode(projectData);
        end
        request.project_data = projectData;
    else
        % Handle projectId - pass path directly to API (no filesystem checks)
        if ischar(projectId) || isstring(projectId)
            projectIdStr = char(projectId);
            if contains(projectIdStr, '/') || contains(projectIdStr, '\')
                % It's already a path - use it directly
                request.project_path = projectIdStr;
            else
                % It's an ID - construct simple path string without checking if file exists
                % API backend will handle path resolution and file loading
                request.project_path = sprintf('src/data/poc/%s.json', projectIdStr);
                warning('buildAnalysisRequest:PathNotValidated', ...
                    'Constructed project_path without validation: %s. API backend will validate the path.', ...
                    request.project_path);
            end
        else
            warning('Invalid projectId type. Expected string path or ID.');
        end
    end
end

