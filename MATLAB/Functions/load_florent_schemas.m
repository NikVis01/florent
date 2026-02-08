function schemas = load_florent_schemas()
    % LOAD_FLORENT_SCHEMAS Load all Florent API schemas
    %
    % Loads all OpenAPI schemas and endpoint definitions from JSON files
    % into MATLAB structs. Handles path resolution, validates structures,
    % and provides detailed error reporting.
    %
    % Returns:
    %   schemas - Struct containing all API schemas and endpoints:
    %     - schemas.schemas.<SchemaName> - Schema definitions with fields:
    %         * name: Schema name
    %         * schema: JSON schema definition (may contain oneOf/anyOf as cell arrays)
    %         * example: Example data structure
    %     - schemas.endpoints.<OperationId> - Endpoint definitions with fields:
    %         * path: API path
    %         * method: HTTP method
    %         * operationId: Operation identifier
    %         * summary: Endpoint summary
    %         * request: Request structure (if applicable)
    %         * responses: Response structures by status code
    %
    % Examples:
    %   % Load all schemas
    %   schemas = load_florent_schemas();
    %
    %   % Access schema definition
    %   request_schema = schemas.schemas.AnalysisRequest.schema;
    %   request_example = schemas.schemas.AnalysisRequest.example;
    %
    %   % Access endpoint information
    %   analyze_endpoint = schemas.endpoints.AnalyzeAnalyzeProject;
    %   fprintf('Endpoint: %s %s\n', analyze_endpoint.method, analyze_endpoint.path);
    %
    %   % Handle oneOf arrays (note: JSON arrays become cell arrays in MATLAB)
    %   budget_prop = request_schema.properties.budget;
    %   if iscell(budget_prop.oneOf)
    %       % oneOf is a cell array - access elements with {}
    %       first_option = budget_prop.oneOf{1};
    %   end
    %
    % Notes:
    %   - JSON arrays of objects with same fields become structure arrays
    %   - JSON arrays of mixed types (like oneOf/anyOf) become cell arrays
    %   - Use {} to access cell array elements, () for structure arrays
    %   - Paths are resolved relative to project root

    % Get project root directory (robust path resolution)
    % From MATLAB/Functions/load_florent_schemas.m:
    %   mfilename('fullpath') = .../MATLAB/Functions/load_florent_schemas.m
    %   fileparts(...) = .../MATLAB/Functions
    %   fileparts(fileparts(...)) = .../MATLAB
    %   fileparts(fileparts(fileparts(...))) = .../ (project root)
    script_path = mfilename('fullpath');
    matlab_dir = fileparts(fileparts(script_path));  % MATLAB directory
    project_root = fileparts(matlab_dir);            % Project root
    
    % Navigate to openapi_export base directory
    base_dir = fullfile(project_root, 'docs', 'openapi_export');
    
    % Validate base directory exists
    if ~isfolder(base_dir)
        error('OpenAPI export directory not found: %s\nProject root: %s\nScript location: %s', ...
            base_dir, project_root, script_path);
    end

    % Initialize output structure
    schemas = struct();
    schemas.schemas = struct();
    schemas.endpoints = struct();

    % Define expected schema files (can be extended)
    schema_files = {'AnalysisRequest'};
    endpoint_files = {'HealthCheck', 'AnalyzeAnalyzeProject'};

    % Load component schemas
    for i = 1:length(schema_files)
        schema_name = schema_files{i};
        schema_path = fullfile(base_dir, 'schemas', [schema_name, '.json']);
        
        try
            % Validate file exists
            if ~isfile(schema_path)
                warning('Schema file not found: %s', schema_path);
                continue;
            end
            
            % Read and decode JSON
            json_text = fileread(schema_path);
            schema_data = jsondecode(json_text);
            
            % Validate schema structure
            if ~validate_schema_structure(schema_data, schema_name)
                warning('Schema validation failed for: %s', schema_name);
                continue;
            end
            
            schemas.schemas.(schema_name) = schema_data;
            
        catch ME
            warning('Failed to load schema %s from %s:\n  %s', ...
                schema_name, schema_path, ME.message);
        end
    end

    % Load endpoint structures
    for i = 1:length(endpoint_files)
        endpoint_name = endpoint_files{i};
        endpoint_path = fullfile(base_dir, 'endpoints', [endpoint_name, '.json']);
        
        try
            % Validate file exists
            if ~isfile(endpoint_path)
                warning('Endpoint file not found: %s', endpoint_path);
                continue;
            end
            
            % Read and decode JSON
            json_text = fileread(endpoint_path);
            endpoint_data = jsondecode(json_text);
            
            % Validate endpoint structure
            if ~validate_endpoint_structure(endpoint_data, endpoint_name)
                warning('Endpoint validation failed for: %s', endpoint_name);
                continue;
            end
            
            schemas.endpoints.(endpoint_name) = endpoint_data;
            
        catch ME
            warning('Failed to load endpoint %s from %s:\n  %s', ...
                endpoint_name, endpoint_path, ME.message);
        end
    end

    % Report results
    num_schemas = length(fieldnames(schemas.schemas));
    num_endpoints = length(fieldnames(schemas.endpoints));
    
    if num_schemas > 0 || num_endpoints > 0
        fprintf('✓ Loaded %d schemas and %d endpoints\n', num_schemas, num_endpoints);
    else
        warning('No schemas or endpoints were successfully loaded');
    end

end


function valid = validate_schema_structure(schema_data, schema_name)
    % VALIDATE_SCHEMA_STRUCTURE Validate that schema has expected fields
    %
    % Args:
    %   schema_data - Decoded schema structure
    %   schema_name - Name of schema (for error messages)
    %
    % Returns:
    %   valid - True if structure is valid
    
    valid = false;
    
    if ~isstruct(schema_data)
        warning('Schema %s is not a struct', schema_name);
        return;
    end
    
    % Check for required fields
    required_fields = {'name', 'schema'};
    for i = 1:length(required_fields)
        if ~isfield(schema_data, required_fields{i})
            warning('Schema %s missing required field: %s', schema_name, required_fields{i});
            return;
        end
    end
    
    % Validate schema field is a struct
    if ~isstruct(schema_data.schema)
        warning('Schema %s.schema is not a struct', schema_name);
        return;
    end
    
    valid = true;
end


function valid = validate_endpoint_structure(endpoint_data, endpoint_name)
    % VALIDATE_ENDPOINT_STRUCTURE Validate that endpoint has expected fields
    %
    % Args:
    %   endpoint_data - Decoded endpoint structure
    %   endpoint_name - Name of endpoint (for error messages)
    %
    % Returns:
    %   valid - True if structure is valid
    
    valid = false;
    
    if ~isstruct(endpoint_data)
        warning('Endpoint %s is not a struct', endpoint_name);
        return;
    end
    
    % Check for required fields
    required_fields = {'path', 'method', 'operationId'};
    for i = 1:length(required_fields)
        if ~isfield(endpoint_data, required_fields{i})
            warning('Endpoint %s missing required field: %s', endpoint_name, required_fields{i});
            return;
        end
    end
    
    valid = true;
end


function prop_value = get_schema_property(schema, property_name)
    % GET_SCHEMA_PROPERTY Extract a property definition from a schema
    %
    % Safely extracts a property from schema.properties, handling nested
    % structures and oneOf/anyOf arrays.
    %
    % Args:
    %   schema - Schema structure (e.g., schemas.schemas.AnalysisRequest.schema)
    %   property_name - Name of property to extract
    %
    % Returns:
    %   prop_value - Property definition struct, or empty if not found
    %
    % Example:
    %   schemas = load_florent_schemas();
    %   budget_prop = get_schema_property(schemas.schemas.AnalysisRequest.schema, 'budget');
    
    prop_value = [];
    
    if ~isstruct(schema)
        warning('Schema must be a struct');
        return;
    end
    
    if ~isfield(schema, 'properties')
        warning('Schema does not have properties field');
        return;
    end
    
    if ~isfield(schema.properties, property_name)
        warning('Property "%s" not found in schema', property_name);
        return;
    end
    
    prop_value = schema.properties.(property_name);
end


function option = get_oneof_option(property_def, option_index)
    % GET_ONEOF_OPTION Extract a specific option from a oneOf/anyOf property
    %
    % Handles the fact that oneOf/anyOf arrays in JSON become cell arrays
    % in MATLAB when they contain mixed types.
    %
    % Args:
    %   property_def - Property definition that may contain oneOf/anyOf
    %   option_index - Index of option to extract (1-based)
    %
    % Returns:
    %   option - The option struct, or empty if not found
    %
    % Example:
    %   schemas = load_florent_schemas();
    %   budget_prop = get_schema_property(schemas.schemas.AnalysisRequest.schema, 'budget');
    %   first_option = get_oneof_option(budget_prop, 1);
    
    option = [];
    
    if ~isstruct(property_def)
        warning('Property definition must be a struct');
        return;
    end
    
    % Check for oneOf
    if isfield(property_def, 'oneOf')
        oneof_data = property_def.oneOf;
        if iscell(oneof_data) && option_index <= length(oneof_data)
            option = oneof_data{option_index};
        elseif isstruct(oneof_data) && option_index == 1
            % If oneOf is a struct array, use () indexing
            option = oneof_data(option_index);
        end
        return;
    end
    
    % Check for anyOf
    if isfield(property_def, 'anyOf')
        anyof_data = property_def.anyOf;
        if iscell(anyof_data) && option_index <= length(anyof_data)
            option = anyof_data{option_index};
        elseif isstruct(anyof_data) && option_index == 1
            option = anyof_data(option_index);
        end
        return;
    end
    
    warning('Property definition does not contain oneOf or anyOf');
end


function example_data = get_schema_example(schemas, schema_name)
    % GET_SCHEMA_EXAMPLE Get example data for a schema
    %
    % Args:
    %   schemas - Full schemas structure from load_florent_schemas()
    %   schema_name - Name of schema (e.g., 'AnalysisRequest')
    %
    % Returns:
    %   example_data - Example data structure, or empty if not found
    %
    % Example:
    %   schemas = load_florent_schemas();
    %   example = get_schema_example(schemas, 'AnalysisRequest');
    
    example_data = [];
    
    if ~isstruct(schemas) || ~isfield(schemas, 'schemas')
        warning('Invalid schemas structure');
        return;
    end
    
    if ~isfield(schemas.schemas, schema_name)
        warning('Schema "%s" not found', schema_name);
        return;
    end
    
    schema = schemas.schemas.(schema_name);
    
    if isfield(schema, 'example')
        example_data = schema.example;
    else
        warning('Schema "%s" does not have example data', schema_name);
    end
end


function example_json = create_analysis_request(firm_path, project_path, budget)
    % CREATE_ANALYSIS_REQUEST Create analysis request JSON
    %
    % Creates a properly formatted AnalysisRequest JSON string for the API.
    %
    % Args:
    %   firm_path - Path to firm.json (optional, can be empty)
    %   project_path - Path to project.json (optional, can be empty)
    %   budget - Evaluation budget (default: 100)
    %
    % Returns:
    %   example_json - JSON string ready to send to API
    %
    % Example:
    %   json_str = create_analysis_request('data/firm.json', 'data/project.json', 100);
    %   options = weboptions('RequestMethod', 'post', 'MediaType', 'application/json');
    %   response = webwrite('http://localhost:8000/analyze', json_str, options);

    if nargin < 3
        budget = 100;
    end

    request = struct();
    
    % Only set paths if provided
    if nargin >= 1 && ~isempty(firm_path)
        request.firm_path = firm_path;
    end
    
    if nargin >= 2 && ~isempty(project_path)
        request.project_path = project_path;
    end
    
    request.budget = budget;

    example_json = jsonencode(request);
end


