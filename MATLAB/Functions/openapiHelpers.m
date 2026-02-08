function varargout = openapiHelpers(operation, varargin)
    % OPENAPIHELPERS Helper functions for accessing OpenAPI data structure
    %
    % This function provides convenient access to OpenAPI-formatted analysis
    % data from the Florent API. It handles field name mapping and provides
    % safe access with fallbacks. Uses enhanced schemas from load_enhanced_schemas()
    % for validation and type checking of response data.
    %
    % Usage:
    %   influence = openapiHelpers('getInfluenceScore', analysis, nodeId);
    %   risk = openapiHelpers('getRiskLevel', analysis, nodeId);
    %   importance = openapiHelpers('getImportanceScore', analysis, nodeId);
    %   isCritical = openapiHelpers('getIsOnCriticalPath', analysis, nodeId);
    %   matrixType = openapiHelpers('getMatrixType', analysis, nodeId);
    %   chains = openapiHelpers('getAllChains', analysis);
    %   metric = openapiHelpers('getSummaryMetric', analysis, metricName);
    %   nodeIds = openapiHelpers('getNodeIds', analysis);
    %   assessment = openapiHelpers('getNodeAssessment', analysis, nodeId);
    %   schemas = openapiHelpers('getSchemas'); % Load OpenAPI schemas
    %   isValid = openapiHelpers('validateRequest', request); % Validate request
    %
    % Operations:
    %   'getInfluenceScore' - Get influence_score for a node
    %   'getRiskLevel' - Get risk_level for a node
    %   'getImportanceScore' - Get importance_score for a node
    %   'getIsOnCriticalPath' - Get is_on_critical_path flag for a node
    %   'getMatrixType' - Get TYPE_A/B/C/D classification for a node
    %   'getAllChains' - Get all_chains array
    %   'getSummaryMetric' - Get a metric from summary
    %   'getNodeIds' - Get all node IDs from node_assessments
    %   'getNodeAssessment' - Get full assessment structure for a node
    %   'getSchemas' - Load and return OpenAPI schemas
    %   'validateRequest' - Validate request against AnalysisRequest schema
    %   'getAllRiskLevels' - Get risk_level for all nodes as array
    %   'getAllInfluenceScores' - Get influence_score for all nodes as array
    %   'getAllImportanceScores' - Get importance_score for all nodes as array
    %   'getAllIsOnCriticalPath' - Get is_on_critical_path for all nodes as array
    %   'getGraphTopology' - Extract graph_topology section
    %   'getRiskDistributions' - Extract risk_distributions section
    %   'getMonteCarloParameters' - Extract monte_carlo_parameters section
    %   'getPropagationTrace' - Extract propagation_trace section
    %   'getGraphStatistics' - Extract graph_statistics section
    %   'getAdjacencyMatrix' - Get adjacency from graph_topology.adjacency_matrix
    %   'getNodeIndex' - Get node index mapping from graph_topology.node_index
    %   'getCentrality' - Get centrality from graph_statistics.centrality
    %   'getSamplingDistribution' - Get MC sampling distribution
    %   'getNodePropagation' - Get propagation details for a node
    %   'getEnhancedSchemas' - Load enhanced schemas from load_enhanced_schemas
    
    switch operation
        case 'getInfluenceScore'
            varargout{1} = getInfluenceScore(varargin{:});
        case 'getRiskLevel'
            varargout{1} = getRiskLevel(varargin{:});
        case 'getImportanceScore'
            varargout{1} = getImportanceScore(varargin{:});
        case 'getIsOnCriticalPath'
            varargout{1} = getIsOnCriticalPath(varargin{:});
        case 'getMatrixType'
            varargout{1} = getMatrixType(varargin{:});
        case 'getAllChains'
            varargout{1} = getAllChains(varargin{:});
        case 'getSummaryMetric'
            varargout{1} = getSummaryMetric(varargin{:});
        case 'getNodeIds'
            varargout{1} = getNodeIds(varargin{:});
        case 'getNodeAssessment'
            varargout{1} = getNodeAssessment(varargin{:});
        case 'getAllRiskLevels'
            varargout{1} = getAllRiskLevels(varargin{:});
        case 'getAllInfluenceScores'
            varargout{1} = getAllInfluenceScores(varargin{:});
        case 'getAllImportanceScores'
            varargout{1} = getAllImportanceScores(varargin{:});
        case 'getAllIsOnCriticalPath'
            varargout{1} = getAllIsOnCriticalPath(varargin{:});
        case 'getSchemas'
            varargout{1} = getSchemas();
        case 'validateRequest'
            varargout{1} = validateRequest(varargin{:});
        case 'getGraphTopology'
            varargout{1} = getGraphTopology(varargin{:});
        case 'getRiskDistributions'
            varargout{1} = getRiskDistributions(varargin{:});
        case 'getMonteCarloParameters'
            varargout{1} = getMonteCarloParameters(varargin{:});
        case 'getPropagationTrace'
            varargout{1} = getPropagationTrace(varargin{:});
        case 'getGraphStatistics'
            varargout{1} = getGraphStatistics(varargin{:});
        case 'getAdjacencyMatrix'
            varargout{1} = getAdjacencyMatrix(varargin{:});
        case 'getNodeIndex'
            varargout{1} = getNodeIndex(varargin{:});
        case 'getCentrality'
            varargout{1} = getCentrality(varargin{:});
        case 'getSamplingDistribution'
            varargout{1} = getSamplingDistribution(varargin{:});
        case 'getNodePropagation'
            varargout{1} = getNodePropagation(varargin{:});
        case 'getEnhancedSchemas'
            varargout{1} = getEnhancedSchemas();
        otherwise
            error('Unknown operation: %s', operation);
    end
end

function influence = getInfluenceScore(analysis, nodeId)
    % GETINFLUENCESCORE Get influence_score from node_assessments
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   influence - Influence score (0.0-1.0), or 0.5 if not found
    
    if nargin < 2
        error('getInfluenceScore requires analysis and nodeId');
    end
    
    if isfield(analysis, 'node_assessments') && ...
       isfield(analysis.node_assessments, nodeId)
        assessment = analysis.node_assessments.(nodeId);
        if isfield(assessment, 'influence_score')
            influence = assessment.influence_score;
        else
            influence = NaN; % Missing data indicator
        end
    else
        influence = NaN; % Missing data indicator
    end
end

function risk = getRiskLevel(analysis, nodeId)
    % GETRISKLEVEL Get risk_level from node_assessments
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   risk - Risk level (0.0-1.0), or 0.5 if not found
    
    if nargin < 2
        error('getRiskLevel requires analysis and nodeId');
    end
    
    if isfield(analysis, 'node_assessments') && ...
       isfield(analysis.node_assessments, nodeId)
        assessment = analysis.node_assessments.(nodeId);
        if isfield(assessment, 'risk_level')
            risk = assessment.risk_level;
        else
            risk = NaN; % Missing data indicator
        end
    else
        risk = NaN; % Missing data indicator
    end
end

function importance = getImportanceScore(analysis, nodeId)
    % GETIMPORTANCESCORE Get importance_score from node_assessments
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   importance - Importance score (0.0-1.0), or 0.5 if not found
    
    if nargin < 2
        error('getImportanceScore requires analysis and nodeId');
    end
    
    if isfield(analysis, 'node_assessments') && ...
       isfield(analysis.node_assessments, nodeId)
        assessment = analysis.node_assessments.(nodeId);
        if isfield(assessment, 'importance_score')
            importance = assessment.importance_score;
        else
            importance = NaN; % Missing data indicator
        end
    else
        importance = NaN; % Missing data indicator
    end
end

function isCritical = getIsOnCriticalPath(analysis, nodeId)
    % GETISONCRITICALPATH Get is_on_critical_path flag from node_assessments
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   isCritical - Boolean flag, or false if not found
    
    if nargin < 2
        error('getIsOnCriticalPath requires analysis and nodeId');
    end
    
    if isfield(analysis, 'node_assessments') && ...
       isfield(analysis.node_assessments, nodeId)
        assessment = analysis.node_assessments.(nodeId);
        if isfield(assessment, 'is_on_critical_path')
            isCritical = assessment.is_on_critical_path;
        else
            isCritical = false; % Default for boolean
        end
    else
        isCritical = false;
    end
end

function matrixType = getMatrixType(analysis, nodeId)
    % GETMATRIXTYPE Get TYPE_A/B/C/D classification from matrix_classifications
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   matrixType - String quadrant key, or empty if not found
    %
    % Performance: Builds reverse lookup map once per call for O(1) lookup
    
    if nargin < 2
        error('getMatrixType requires analysis and nodeId');
    end
    
    matrixType = '';
    
    if ~isfield(analysis, 'matrix_classifications')
        return;
    end
    
    % Build reverse lookup map (node_id -> quadrant) once for efficient lookup
    % This replaces the O(n*m) nested loop search with O(n) map building + O(1) lookup
    nodeToQuadrantMap = containers.Map();
    matrix = analysis.matrix_classifications;
    quadrantKeys = fieldnames(matrix);
    
    % Build reverse map: node_id -> quadrant key
    for q = 1:length(quadrantKeys)
        quadrantKey = quadrantKeys{q};
        nodeList = matrix.(quadrantKey);
        
        % Handle both cell array and struct array formats
        if iscell(nodeList)
            for n = 1:length(nodeList)
                nodeClass = nodeList{n};
                if isstruct(nodeClass) && isfield(nodeClass, 'node_id')
                    nodeToQuadrantMap(nodeClass.node_id) = quadrantKey;
                end
            end
        elseif isstruct(nodeList) && length(nodeList) > 0
            % Handle struct array
            for n = 1:length(nodeList)
                nodeClass = nodeList(n);
                if isfield(nodeClass, 'node_id')
                    nodeToQuadrantMap(nodeClass.node_id) = quadrantKey;
                end
            end
        end
    end
    
    % Lookup node in map (O(1) operation)
    if isKey(nodeToQuadrantMap, nodeId)
        matrixType = nodeToQuadrantMap(nodeId);
    end
end

function chains = getAllChains(analysis)
    % GETALLCHAINS Get all_chains array from analysis
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   chains - Cell array or struct array of chains, or empty if not found
    
    chains = [];
    
    if isfield(analysis, 'all_chains')
        chains = analysis.all_chains;
    end
end

function metric = getSummaryMetric(analysis, metricName)
    % GETSUMMARYMETRIC Get a metric from summary
    %
    % Args:
    %   analysis - Analysis structure from API
    %   metricName - Name of metric to retrieve
    %
    % Returns:
    %   metric - Metric value, or empty if not found
    
    if nargin < 2
        error('getSummaryMetric requires analysis and metricName');
    end
    
    metric = [];
    
    if ~isfield(analysis, 'summary')
        return;
    end
    
    summary = analysis.summary;
    
    % Handle field name mapping
    fieldMapping = struct();
    fieldMapping.overall_bankability = {'aggregate_project_score', 'overall_bankability'};
    fieldMapping.aggregate_project_score = {'aggregate_project_score', 'overall_bankability'};
    
    if isfield(fieldMapping, metricName)
        % Try mapped field names
        mappedNames = fieldMapping.(metricName);
        for i = 1:length(mappedNames)
            if isfield(summary, mappedNames{i})
                metric = summary.(mappedNames{i});
                return;
            end
        end
    elseif isfield(summary, metricName)
        metric = summary.(metricName);
    end
end

function nodeIds = getNodeIds(analysis)
    % GETNODEIDS Get all node IDs from node_assessments
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   nodeIds - Cell array of node ID strings
    
    nodeIds = {};
    
    if isfield(analysis, 'node_assessments')
        nodeIds = fieldnames(analysis.node_assessments);
    end
end

function assessment = getNodeAssessment(analysis, nodeId)
    % GETNODEASSESSMENT Get full assessment structure for a node
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   assessment - Full assessment structure, or empty if not found
    
    if nargin < 2
        error('getNodeAssessment requires analysis and nodeId');
    end
    
    assessment = [];
    
    if isfield(analysis, 'node_assessments') && ...
       isfield(analysis.node_assessments, nodeId)
        assessment = analysis.node_assessments.(nodeId);
    end
end

function riskLevels = getAllRiskLevels(analysis)
    % GETALLRISKLEVELS Get risk_level for all nodes as array
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   riskLevels - Array of risk levels, ordered by nodeIds
    
    nodeIds = getNodeIds(analysis);
    nNodes = length(nodeIds);
    riskLevels = zeros(nNodes, 1);
    
    for i = 1:nNodes
        riskLevels(i) = getRiskLevel(analysis, nodeIds{i});
    end
end

function influenceScores = getAllInfluenceScores(analysis)
    % GETALLINFLUENCESCORES Get influence_score for all nodes as array
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   influenceScores - Array of influence scores, ordered by nodeIds
    
    nodeIds = getNodeIds(analysis);
    nNodes = length(nodeIds);
    influenceScores = zeros(nNodes, 1);
    
    for i = 1:nNodes
        influenceScores(i) = getInfluenceScore(analysis, nodeIds{i});
    end
end

function importanceScores = getAllImportanceScores(analysis)
    % GETALLIMPORTANCESCORES Get importance_score for all nodes as array
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   importanceScores - Array of importance scores, ordered by nodeIds
    
    nodeIds = getNodeIds(analysis);
    nNodes = length(nodeIds);
    importanceScores = zeros(nNodes, 1);
    
    for i = 1:nNodes
        importanceScores(i) = getImportanceScore(analysis, nodeIds{i});
    end
end

function isCritical = getAllIsOnCriticalPath(analysis)
    % GETALLISONCRITICALPATH Get is_on_critical_path for all nodes as array
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   isCritical - Boolean array, ordered by nodeIds
    
    nodeIds = getNodeIds(analysis);
    nNodes = length(nodeIds);
    isCritical = false(nNodes, 1);
    
    for i = 1:nNodes
        isCritical(i) = getIsOnCriticalPath(analysis, nodeIds{i});
    end
end

function schemas = getSchemas()
    % GETSCHEMAS Load and return OpenAPI schemas from load_florent_schemas
    %
    % Returns:
    %   schemas - Schema structure from load_florent_schemas()
    %
    % This function provides access to the OpenAPI schema definitions
    % for validation, type checking, and field discovery.
    
    persistent cachedSchemas;
    
    if isempty(cachedSchemas)
        try
            cachedSchemas = load_florent_schemas();
        catch ME
            warning('Failed to load OpenAPI schemas: %s\nContinuing without schema validation.', ME.message);
            cachedSchemas = struct();
            cachedSchemas.schemas = struct();
            cachedSchemas.endpoints = struct();
        end
    end
    
    schemas = cachedSchemas;
end

function isValid = validateRequest(request)
    % VALIDATEREQUEST Validate request against AnalysisRequest schema
    %
    % Args:
    %   request - Request structure to validate
    %
    % Returns:
    %   isValid - True if request matches AnalysisRequest schema
    
    isValid = true;
    
    try
        schemas = getSchemas();
        
        if ~isfield(schemas.schemas, 'AnalysisRequest')
            % Schema not available - skip validation
            return;
        end
        
        requestSchema = schemas.schemas.AnalysisRequest.schema;
        
        % Check that request is a struct
        if ~isstruct(request)
            isValid = false;
            return;
        end
        
        % Validate required fields (none are required per schema)
        % Validate field types if present
        if isfield(request, 'budget')
            budget = request.budget;
            if ~isnumeric(budget) || ~isscalar(budget) || budget < 0
                isValid = false;
                return;
            end
        end
        
        if isfield(request, 'firm_path')
            if ~ischar(request.firm_path) && ~isstring(request.firm_path)
                isValid = false;
                return;
            end
        end
        
        if isfield(request, 'project_path')
            if ~ischar(request.project_path) && ~isstring(request.project_path)
                isValid = false;
                return;
            end
        end
        
        % firm_data and project_data are objects or null - just check they're structs if present
        if isfield(request, 'firm_data')
            if ~isstruct(request.firm_data) && ~isempty(request.firm_data)
                isValid = false;
                return;
            end
        end
        
        if isfield(request, 'project_data')
            if ~isstruct(request.project_data) && ~isempty(request.project_data)
                isValid = false;
                return;
            end
        end
        
    catch ME
        % If validation fails due to error, assume valid (don't block requests)
        warning('Request validation error: %s', ME.message);
        isValid = true; % Fail open
    end
end

function topology = getGraphTopology(analysis)
    % GETGRAPHTOPOLOGY Extract graph_topology section from analysis
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   topology - GraphTopology structure, or empty if not found
    %
    % Note: Validates against GraphTopology schema from enhanced schemas if available
    
    topology = [];
    
    if isfield(analysis, 'graph_topology') && ~isempty(analysis.graph_topology)
        topology = analysis.graph_topology;
        
        % Optional: Validate against enhanced schema
        try
            enhancedSchemas = getEnhancedSchemas();
            if ~isempty(enhancedSchemas) && isfield(enhancedSchemas, 'GraphTopology')
                [isValid, errors] = validateAgainstSchema(topology, enhancedSchemas.GraphTopology);
                if ~isValid && ~isempty(errors)
                    warning('GraphTopology validation warnings: %s', strjoin(errors, '; '));
                end
            end
        catch
            % Schema validation failed - continue anyway
        end
    end
end

function distributions = getRiskDistributions(analysis)
    % GETRISKDISTRIBUTIONS Extract risk_distributions section from analysis
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   distributions - RiskDistributions structure, or empty if not found
    %
    % Note: Validates against RiskDistributions schema from enhanced schemas if available
    
    distributions = [];
    
    if isfield(analysis, 'risk_distributions') && ~isempty(analysis.risk_distributions)
        distributions = analysis.risk_distributions;
        
        % Optional: Validate against enhanced schema
        try
            enhancedSchemas = getEnhancedSchemas();
            if ~isempty(enhancedSchemas) && isfield(enhancedSchemas, 'RiskDistributions')
                [isValid, errors] = validateAgainstSchema(distributions, enhancedSchemas.RiskDistributions);
                if ~isValid && ~isempty(errors)
                    warning('RiskDistributions validation warnings: %s', strjoin(errors, '; '));
                end
            end
        catch
            % Schema validation failed - continue anyway
        end
    end
end

function mcParams = getMonteCarloParameters(analysis)
    % GETMONTECARLOPARAMETERS Extract monte_carlo_parameters section from analysis
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   mcParams - MonteCarloParameters structure, or empty if not found
    %
    % Note: Validates against MonteCarloParameters schema from enhanced schemas if available
    
    mcParams = [];
    
    if isfield(analysis, 'monte_carlo_parameters') && ~isempty(analysis.monte_carlo_parameters)
        mcParams = analysis.monte_carlo_parameters;
        
        % Optional: Validate against enhanced schema
        try
            enhancedSchemas = getEnhancedSchemas();
            if ~isempty(enhancedSchemas) && isfield(enhancedSchemas, 'MonteCarloParameters')
                [isValid, errors] = validateAgainstSchema(mcParams, enhancedSchemas.MonteCarloParameters);
                if ~isValid && ~isempty(errors)
                    warning('MonteCarloParameters validation warnings: %s', strjoin(errors, '; '));
                end
            end
        catch
            % Schema validation failed - continue anyway
        end
    end
end

function trace = getPropagationTrace(analysis)
    % GETPROPAGATIONTRACE Extract propagation_trace section from analysis
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   trace - PropagationTrace structure, or empty if not found
    
    trace = [];
    
    if isfield(analysis, 'propagation_trace') && ~isempty(analysis.propagation_trace)
        trace = analysis.propagation_trace;
    end
end

function stats = getGraphStatistics(analysis)
    % GETGRAPHSTATISTICS Extract graph_statistics section from analysis
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   stats - GraphStatistics structure, or empty if not found
    %
    % Note: Validates against GraphStatistics schema from enhanced schemas if available
    
    stats = [];
    
    if isfield(analysis, 'graph_statistics') && ~isempty(analysis.graph_statistics)
        stats = analysis.graph_statistics;
        
        % Optional: Validate against enhanced schema
        try
            enhancedSchemas = getEnhancedSchemas();
            if ~isempty(enhancedSchemas) && isfield(enhancedSchemas, 'GraphStatistics')
                [isValid, errors] = validateAgainstSchema(stats, enhancedSchemas.GraphStatistics);
                if ~isValid && ~isempty(errors)
                    warning('GraphStatistics validation warnings: %s', strjoin(errors, '; '));
                end
            end
        catch
            % Schema validation failed - continue anyway
        end
    end
end

function adjMatrix = getAdjacencyMatrix(analysis)
    % GETADJACENCYMATRIX Get adjacency matrix from graph_topology
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   adjMatrix - NxN adjacency matrix, or empty if not found
    
    adjMatrix = [];
    
    topology = getGraphTopology(analysis);
    if ~isempty(topology) && isfield(topology, 'adjacency_matrix')
        adjMatrix = topology.adjacency_matrix;
        % Python always sends numeric array (List[List[float]]), no conversion needed
    end
end

function nodeIndex = getNodeIndex(analysis)
    % GETNODEINDEX Get node index mapping from graph_topology
    %
    % Args:
    %   analysis - Analysis structure from API
    %
    % Returns:
    %   nodeIndex - Cell array of node IDs in matrix order, or empty if not found
    
    nodeIndex = {};
    
    topology = getGraphTopology(analysis);
    if ~isempty(topology) && isfield(topology, 'node_index')
        nodeIndex = topology.node_index;
        % Ensure it's a cell array
        if ~iscell(nodeIndex)
            nodeIndex = cellstr(nodeIndex);
        end
    end
end

function centrality = getCentrality(analysis, nodeId)
    % GETCENTRALITY Get centrality measures for a node from graph_statistics
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   centrality - NodeCentrality structure, or empty if not found
    
    centrality = [];
    
    if nargin < 2
        error('getCentrality requires analysis and nodeId');
    end
    
    stats = getGraphStatistics(analysis);
    if ~isempty(stats) && isfield(stats, 'centrality')
        centralityData = stats.centrality;
        if isfield(centralityData, nodeId)
            centrality = centralityData.(nodeId);
        end
    end
end

function dist = getSamplingDistribution(analysis, nodeId, param)
    % GETSAMPLINGDISTRIBUTION Get MC sampling distribution for a node parameter
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %   param - Parameter name: 'importance' or 'influence'
    %
    % Returns:
    %   dist - SamplingDistribution structure, or empty if not found
    
    dist = [];
    
    if nargin < 3
        error('getSamplingDistribution requires analysis, nodeId, and param');
    end
    
    if ~strcmp(param, 'importance') && ~strcmp(param, 'influence')
        error('param must be ''importance'' or ''influence''');
    end
    
    mcParams = getMonteCarloParameters(analysis);
    if ~isempty(mcParams) && isfield(mcParams, 'sampling_distributions')
        samplingDists = mcParams.sampling_distributions;
        if isfield(samplingDists, nodeId)
            nodeDist = samplingDists.(nodeId);
            if isfield(nodeDist, param)
                dist = nodeDist.(param);
            end
        end
    end
end

function propagation = getNodePropagation(analysis, nodeId)
    % GETNODEPROPAGATION Get propagation details for a node
    %
    % Args:
    %   analysis - Analysis structure from API
    %   nodeId - Node identifier (string)
    %
    % Returns:
    %   propagation - NodePropagation structure, or empty if not found
    
    propagation = [];
    
    if nargin < 2
        error('getNodePropagation requires analysis and nodeId');
    end
    
    trace = getPropagationTrace(analysis);
    if ~isempty(trace) && isfield(trace, 'nodes')
        nodes = trace.nodes;
        if isfield(nodes, nodeId)
            propagation = nodes.(nodeId);
        end
    end
end

function schemas = getEnhancedSchemas()
    % GETENHANCEDSCHEMAS Load and return enhanced schemas from load_enhanced_schemas
    %
    % Returns:
    %   schemas - Schema structure from load_enhanced_schemas()
    %
    % This function provides access to the enhanced schema definitions
    % for validation, type checking, and field discovery.
    
    persistent cachedEnhancedSchemas;
    
    if isempty(cachedEnhancedSchemas)
        try
            % Get path to load_enhanced_schemas.m
            scriptPath = which('load_enhanced_schemas');
            if isempty(scriptPath)
                % Try relative path
                basePath = fileparts(mfilename('fullpath'));
                scriptPath = fullfile(basePath, '..', '..', 'docs', 'openapi_export', 'matlab', 'load_enhanced_schemas.m');
            end
            
            if exist(scriptPath, 'file')
                cachedEnhancedSchemas = load_enhanced_schemas();
            else
                warning('load_enhanced_schemas.m not found. Continuing without enhanced schema validation.');
                cachedEnhancedSchemas = struct();
            end
        catch ME
            warning('Failed to load enhanced schemas: %s\nContinuing without schema validation.', ME.message);
            cachedEnhancedSchemas = struct();
        end
    end
    
    schemas = cachedEnhancedSchemas;
end

function [isValid, errors] = validateAgainstSchema(data, schema)
    % VALIDATEAGAINSTSCHEMA Validate data structure against JSON schema
    %
    % Args:
    %   data - Data structure to validate
    %   schema - JSON schema structure
    %
    % Returns:
    %   isValid - Boolean indicating if structure is valid
    %   errors - Cell array of error/warning messages
    
    isValid = true;
    errors = {};
    
    if isempty(schema) || ~isstruct(schema)
        return; % Can't validate without schema
    end
    
    % Basic structure validation
    if ~isstruct(data)
        errors{end+1} = 'Data should be a struct';
        isValid = false;
        return;
    end
    
    % Check required fields if schema has them
    if isfield(schema, 'required') && iscell(schema.required)
        requiredFields = schema.required;
        for i = 1:length(requiredFields)
            fieldName = requiredFields{i};
            if ~isfield(data, fieldName)
                errors{end+1} = sprintf('Missing required field: %s', fieldName);
                isValid = false;
            end
        end
    end
    
    % Check properties if schema has them
    if isfield(schema, 'properties') && isstruct(schema.properties)
        props = schema.properties;
        propNames = fieldnames(props);
        dataFields = fieldnames(data);
        
        % Warn about unexpected fields (but don't fail validation)
        for i = 1:length(dataFields)
            fieldName = dataFields{i};
            if ~any(strcmp(fieldName, propNames))
                errors{end+1} = sprintf('Unexpected field: %s', fieldName);
            end
        end
    end
end

