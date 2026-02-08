function schemas = load_enhanced_schemas()
    % LOAD_ENHANCED_SCHEMAS Load all enhanced output JSON schemas
    %
    % Returns:
    %   schemas - Struct containing all enhanced section schemas
    %
    % Example:
    %   schemas = load_enhanced_schemas();
    %   graph_schema = schemas.GraphTopology;

    % Get directory of this script
    script_dir = fileparts(mfilename('fullpath'));
    base_dir = fullfile(script_dir, '..', 'schemas_enhanced');


    try
        schemas.AnalysisOutput = jsondecode(fileread(fullfile(base_dir, 'AnalysisOutput.json')));
    catch
        warning('Failed to load schema: AnalysisOutput');
        schemas.AnalysisOutput = struct();
    end

    try
        schemas.GraphTopology = jsondecode(fileread(fullfile(base_dir, 'GraphTopology.json')));
    catch
        warning('Failed to load schema: GraphTopology');
        schemas.GraphTopology = struct();
    end

    try
        schemas.RiskDistributions = jsondecode(fileread(fullfile(base_dir, 'RiskDistributions.json')));
    catch
        warning('Failed to load schema: RiskDistributions');
        schemas.RiskDistributions = struct();
    end

    try
        schemas.PropagationTrace = jsondecode(fileread(fullfile(base_dir, 'PropagationTrace.json')));
    catch
        warning('Failed to load schema: PropagationTrace');
        schemas.PropagationTrace = struct();
    end

    try
        schemas.DiscoveryMetadata = jsondecode(fileread(fullfile(base_dir, 'DiscoveryMetadata.json')));
    catch
        warning('Failed to load schema: DiscoveryMetadata');
        schemas.DiscoveryMetadata = struct();
    end

    try
        schemas.EvaluationMetadata = jsondecode(fileread(fullfile(base_dir, 'EvaluationMetadata.json')));
    catch
        warning('Failed to load schema: EvaluationMetadata');
        schemas.EvaluationMetadata = struct();
    end

    try
        schemas.ConfigurationSnapshot = jsondecode(fileread(fullfile(base_dir, 'ConfigurationSnapshot.json')));
    catch
        warning('Failed to load schema: ConfigurationSnapshot');
        schemas.ConfigurationSnapshot = struct();
    end

    try
        schemas.MonteCarloParameters = jsondecode(fileread(fullfile(base_dir, 'MonteCarloParameters.json')));
    catch
        warning('Failed to load schema: MonteCarloParameters');
        schemas.MonteCarloParameters = struct();
    end

    try
        schemas.GraphStatistics = jsondecode(fileread(fullfile(base_dir, 'GraphStatistics.json')));
    catch
        warning('Failed to load schema: GraphStatistics');
        schemas.GraphStatistics = struct();
    end


    fprintf('[OK] Loaded %d enhanced schemas\n', length(fieldnames(schemas)));

end


function valid = validate_against_schema(data, schema)
    % VALIDATE_AGAINST_SCHEMA Validate data against JSON schema
    %
    % Args:
    %   data - Data structure to validate
    %   schema - JSON schema structure
    %
    % Returns:
    %   valid - Boolean indicating if data is valid

    % Basic validation (simplified)
    % For full validation, use external library like jsonschema

    valid = true;

    if ~isstruct(data) && ~isobject(data)
        valid = false;
        return;
    end

    % Check required fields
    if isfield(schema, 'required')
        required_fields = schema.required;
        for i = 1:length(required_fields)
            field = required_fields{i};
            if ~isfield(data, field)
                warning('Missing required field: %s', field);
                valid = false;
            end
        end
    end

end
