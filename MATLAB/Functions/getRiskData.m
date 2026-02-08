function data = getRiskData(apiBaseUrl, projectId, firmId, budget)
    % GETRISKDATA Fetches risk analysis data from Python API
    %
    % This function uses the API client wrapper (automatically uses manual HTTP calls)
    % endpoint, replacing the previous multiple GET calls approach.
    %
    % Usage:
    %   data = getRiskData('http://localhost:8000', 'proj_001', 'firm_001')
    %   data = getRiskData('http://localhost:8000', 'proj_001', 'firm_001', 100)
    %
    % Returns structure with:
    %   - graph: nodes, edges, adjacency matrix
    %   - riskScores: risk and influence scores per node
    %   - parameters: attenuation_factor, risk_multiplier, alignment_weights
    %   - classifications: 2x2 matrix quadrant per node
    
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
    
    % Initialize data structure
    data = struct();
    data.projectId = projectId;
    data.firmId = firmId;
    
    try
        % Use API client wrapper (uses manual HTTP calls automatically)
        client = FlorentAPIClientWrapper(apiBaseUrl);
        
        % Call analyze endpoint (single POST call)
        data = client.analyzeProject(projectId, firmId, budget);
        
        fprintf('Successfully loaded risk data for project %s, firm %s\n', projectId, firmId);
        
    catch ME
        % Fallback to mock data on error
        warning('Error fetching data from API: %s\nUsing mock data structure', ME.message);
        data = createMockDataStructure();
        data.projectId = projectId;
        data.firmId = firmId;
    end
end

% Note: Helper functions (parseGraphData, parseRiskScores, etc.) have been
% moved to parseAnalysisResponse.m to avoid duplication. The API client wrapper
% handles all parsing automatically using manual HTTP calls.

function data = createMockDataStructure()
    % Create mock data structure for testing when API is unavailable
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
    data.riskScores.localFailureProb = [0.1, 0.2, 0.3, 0.25, 0.05];
    data.riskScores.cascadingRisk = [0.1, 0.2, 0.5, 0.4, 0.2];
    
    % Default parameters
    data.parameters = getDefaultParameters();
    
    % Classifications
    data.classifications = classifyAllNodes(data.riskScores);
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

