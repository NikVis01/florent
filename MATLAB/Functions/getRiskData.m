function data = getRiskData(apiBaseUrl, projectId, firmId, budget, useOpenAPIFormat)
    % GETRISKDATA Fetches risk analysis data from Python API
    %
    % This function uses the API client wrapper (automatically uses manual HTTP calls)
    % endpoint, replacing the previous multiple GET calls approach.
    %
    % IMPORTANT: This function will ERROR if the API is not accessible or returns
    % empty data. There is NO fallback to mock data. The API must be running and
    % accessible for this function to succeed.
    %
    % Usage:
    %   data = getRiskData('http://localhost:8000', 'proj_001', 'firm_001')
    %   data = getRiskData('http://localhost:8000', 'proj_001', 'firm_001', 100)
    %   data = getRiskData('http://localhost:8000', 'proj_001', 'firm_001', 100, true)
    %
    % Arguments:
    %   apiBaseUrl - Base URL for API (default: 'http://localhost:8000')
    %   projectId - Project identifier (default: 'project')
    %   firmId - Firm identifier (default: 'firm')
    %   budget - Analysis budget (default: 100)
    %   useOpenAPIFormat - If true, return raw OpenAPI structure (default: true)
    %
    % Returns:
    %   data - Analysis data structure in OpenAPI format (default) or legacy format
    %
    % Throws:
    %   Error if API is not accessible or returns empty data
    
    if nargin < 1
        apiBaseUrl = 'http://localhost:8000';
    end
    if nargin < 2
        projectId = 'project';
    end
    if nargin < 3
        firmId = 'firm';
    end
    if nargin < 4
        budget = 100;
    end
    if nargin < 5
        useOpenAPIFormat = true; % Default to OpenAPI format
    end
    
    % Use API client wrapper (uses manual HTTP calls automatically)
    client = FlorentAPIClientWrapper(apiBaseUrl);
    
    % Call analyze endpoint (single POST call) - returns OpenAPI format by default
    % NO FALLBACK - must get real data from API
    data = client.analyzeProject(projectId, firmId, budget, [], [], useOpenAPIFormat);
    
    if isempty(data)
        error('API returned empty data for project %s, firm %s', projectId, firmId);
    end
    
    fprintf('Successfully loaded risk data for project %s, firm %s\n', projectId, firmId);
end

% Note: Helper functions (parseGraphData, parseRiskScores, etc.) have been
% moved to parseAnalysisResponse.m to avoid duplication. The API client wrapper
% handles all parsing automatically using manual HTTP calls.

function data = createMockDataStructure(useOpenAPIFormat)
    % CREATEMOCKDATASTRUCTURE Create mock data structure for testing
    %
    % DEPRECATED: This function is kept for testing purposes only.
    % Production code should NEVER use mock data - it must get real data from the API.
    % This function is NOT called as a fallback in production code.
    %
    % Args:
    %   useOpenAPIFormat - If true, return OpenAPI format (default: true)
    %
    % Returns:
    %   data - Mock analysis data structure
    %
    % Note: This function should only be used in unit tests or development.
    %       Production code will error if API data is not available.
    
    if nargin < 1
        useOpenAPIFormat = true;
    end
    
    if useOpenAPIFormat
        % Create OpenAPI format structure
        data = struct();
        data.projectId = 'proj_001';
        data.firmId = 'firm_001';
        
        % Mock node_assessments
        data.node_assessments = struct();
        data.node_assessments.node1 = struct(...
            'influence_score', 0.8, ...
            'risk_level', 0.3, ...
            'importance_score', 0.9, ...
            'is_on_critical_path', true, ...
            'node_name', 'Site Survey', ...
            'reasoning', 'Mock assessment');
        data.node_assessments.node2 = struct(...
            'influence_score', 0.6, ...
            'risk_level', 0.5, ...
            'importance_score', 0.7, ...
            'is_on_critical_path', true, ...
            'node_name', 'Design', ...
            'reasoning', 'Mock assessment');
        data.node_assessments.node3 = struct(...
            'influence_score', 0.4, ...
            'risk_level', 0.7, ...
            'importance_score', 0.8, ...
            'is_on_critical_path', false, ...
            'node_name', 'Procurement', ...
            'reasoning', 'Mock assessment');
        data.node_assessments.node4 = struct(...
            'influence_score', 0.7, ...
            'risk_level', 0.6, ...
            'importance_score', 0.85, ...
            'is_on_critical_path', true, ...
            'node_name', 'Construction', ...
            'reasoning', 'Mock assessment');
        data.node_assessments.node5 = struct(...
            'influence_score', 0.5, ...
            'risk_level', 0.2, ...
            'importance_score', 0.6, ...
            'is_on_critical_path', false, ...
            'node_name', 'Handover', ...
            'reasoning', 'Mock assessment');
        
        % Mock matrix_classifications
        data.matrix_classifications = struct();
        data.matrix_classifications.TYPE_A = {struct('node_id', 'node1', 'node_name', 'Site Survey')};
        data.matrix_classifications.TYPE_B = {struct('node_id', 'node2', 'node_name', 'Design')};
        data.matrix_classifications.TYPE_C = {struct('node_id', 'node3', 'node_name', 'Procurement')};
        data.matrix_classifications.TYPE_D = {struct('node_id', 'node4', 'node_name', 'Construction'), ...
                                              struct('node_id', 'node5', 'node_name', 'Handover')};
        
        % Mock all_chains
        data.all_chains = {struct(...
            'node_ids', {'node1', 'node2', 'node4', 'node5'}, ...
            'cumulative_risk', 0.65, ...
            'length', 4)};
        
        % Mock summary
        data.summary = struct();
        data.summary.aggregate_project_score = 0.625;
        data.summary.critical_failure_likelihood = 0.375;
        data.summary.nodes_evaluated = 5;
        data.summary.total_nodes = 5;
        data.summary.critical_dependency_count = 1;
        data.summary.average_risk = 0.46;
        data.summary.maximum_risk = 0.7;
    else
        % Legacy format (backward compatibility)
        data = struct();
        data.projectId = 'proj_001';
        data.firmId = 'firm_001';
        
        % Mock graph with 5 nodes
        data.graph = struct();
        data.graph.nodeIds = {'node1', 'node2', 'node3', 'node4', 'node5'};
        data.graph.nodeNames = {'Site Survey', 'Design', 'Procurement', 'Construction', 'Handover'};
        data.graph.adjacency = [
            0 1 0 0 0;
            0 0 1 1 0;
            0 0 0 1 0;
            0 0 0 0 1;
            0 0 0 0 0
        ];
        
        % Mock risk scores
        data.riskScores = struct();
        data.riskScores.nodeIds = data.graph.nodeIds;
        data.riskScores.influence = [0.8, 0.6, 0.4, 0.7, 0.5];
        data.riskScores.risk = [0.3, 0.5, 0.7, 0.6, 0.2];
        data.riskScores.importance = [0.9, 0.7, 0.8, 0.85, 0.6];
        data.riskScores.localFailureProb = [0.1, 0.2, 0.3, 0.25, 0.05];
        data.riskScores.cascadingRisk = [0.1, 0.2, 0.5, 0.4, 0.2];
        data.riskScores.isOnCriticalPath = [true, true, false, true, false];
        
        % Default parameters
        data.parameters = getDefaultParameters();
        
        % Classifications - simple classification based on thresholds
        nNodes = length(data.riskScores.nodeIds);
        data.classifications = cell(nNodes, 1);
        riskThreshold = median(data.riskScores.risk);
        influenceThreshold = median(data.riskScores.influence);
        for i = 1:nNodes
            risk = data.riskScores.risk(i);
            influence = data.riskScores.influence(i);
            if risk >= riskThreshold && influence >= influenceThreshold
                data.classifications{i} = 'Q1';
            elseif risk < riskThreshold && influence >= influenceThreshold
                data.classifications{i} = 'Q2';
            elseif risk >= riskThreshold && influence < influenceThreshold
                data.classifications{i} = 'Q3';
            else
                data.classifications{i} = 'Q4';
            end
        end
    end
end

function params = getDefaultParameters()
    % Default parameters from metrics.json
    % This is a local function accessible to createMockDataStructure
    params = struct();
    params.attenuation_factor = 1.2;
    params.risk_multiplier = 1.25;
    params.alignment_weights = struct(...
        'growth', 0.25, ...
        'innovation', 0.2, ...
        'sustainability', 0.2, ...
        'efficiency', 0.15, ...
        'expansion', 0.1, ...
        'public_private_partnership', 0.1 ...
    );
end

