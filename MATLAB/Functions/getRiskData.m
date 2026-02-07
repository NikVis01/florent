function data = getRiskData(apiBaseUrl, projectId, firmId)
    % GETRISKDATA Fetches risk analysis data from Python API
    %
    % Usage:
    %   data = getRiskData('http://localhost:8000', 'proj_001', 'firm_001')
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
        projectId = 'proj_001';
    end
    if nargin < 3
        firmId = 'firm_001';
    end
    
    % Initialize data structure
    data = struct();
    data.projectId = projectId;
    data.firmId = firmId;
    
    try
        % Fetch graph structure
        graphEndpoint = sprintf('%s/api/graph/%s/%s', apiBaseUrl, projectId, firmId);
        graphData = callPythonAPI(graphEndpoint, 'GET');
        
        if isempty(graphData)
            % Fallback: try alternative endpoint or use mock data
            warning('API call failed, using mock data structure');
            data = createMockDataStructure();
            return;
        end
        
        % Parse graph data
        data.graph = parseGraphData(graphData);
        
        % Fetch risk scores
        riskEndpoint = sprintf('%s/api/risk-scores/%s/%s', apiBaseUrl, projectId, firmId);
        riskData = callPythonAPI(riskEndpoint, 'GET');
        if ~isempty(riskData)
            data.riskScores = parseRiskScores(riskData);
        end
        
        % Fetch parameters
        paramsEndpoint = sprintf('%s/api/parameters', apiBaseUrl);
        paramsData = callPythonAPI(paramsEndpoint, 'GET');
        if ~isempty(paramsData)
            data.parameters = parseParameters(paramsData);
        else
            % Use default parameters from metrics.json
            data.parameters = getDefaultParameters();
        end
        
        % Calculate classifications if risk scores available
        if isfield(data, 'riskScores') && ~isempty(data.riskScores)
            data.classifications = classifyAllNodes(data.riskScores);
        end
        
        fprintf('Successfully loaded risk data for project %s, firm %s\n', projectId, firmId);
        
    catch ME
        warning('Error fetching data from API: %s\nUsing mock data structure', ME.message);
        data = createMockDataStructure();
    end
end

function graph = parseGraphData(graphData)
    % Parse graph structure from API response
    graph = struct();
    
    if isfield(graphData, 'nodes')
        graph.nodes = graphData.nodes;
        graph.nodeIds = cellfun(@(n) n.id, graph.nodes, 'UniformOutput', false);
        graph.nodeNames = cellfun(@(n) n.name, graph.nodes, 'UniformOutput', false);
    end
    
    if isfield(graphData, 'edges')
        graph.edges = graphData.edges;
    end
    
    % Build adjacency matrix
    if isfield(graph, 'nodes') && isfield(graph, 'edges')
        graph.adjacency = buildAdjacencyMatrix(graph.nodes, graph.edges);
    end
end

function adj = buildAdjacencyMatrix(nodes, edges)
    % Build adjacency matrix from nodes and edges
    nNodes = length(nodes);
    adj = zeros(nNodes, nNodes);
    
    nodeIdMap = containers.Map();
    for i = 1:nNodes
        nodeIdMap(nodes{i}.id) = i;
    end
    
    for i = 1:length(edges)
        edge = edges{i};
        if isKey(nodeIdMap, edge.source) && isKey(nodeIdMap, edge.target)
            srcIdx = nodeIdMap(edge.source);
            tgtIdx = nodeIdMap(edge.target);
            adj(srcIdx, tgtIdx) = edge.weight;
        end
    end
end

function riskScores = parseRiskScores(riskData)
    % Parse risk scores from API response
    riskScores = struct();
    
    if isfield(riskData, 'nodes')
        nNodes = length(riskData.nodes);
        riskScores.nodeIds = cell(nNodes, 1);
        riskScores.influence = zeros(nNodes, 1);
        riskScores.risk = zeros(nNodes, 1);
        riskScores.localFailureProb = zeros(nNodes, 1);
        riskScores.cascadingRisk = zeros(nNodes, 1);
        
        for i = 1:nNodes
            node = riskData.nodes{i};
            riskScores.nodeIds{i} = node.id;
            if isfield(node, 'influence')
                riskScores.influence(i) = node.influence;
            end
            if isfield(node, 'risk')
                riskScores.risk(i) = node.risk;
            end
            if isfield(node, 'localFailureProb')
                riskScores.localFailureProb(i) = node.localFailureProb;
            end
            if isfield(node, 'cascadingRisk')
                riskScores.cascadingRisk(i) = node.cascadingRisk;
            end
        end
    end
end

function params = parseParameters(paramsData)
    % Parse parameters from API response
    params = struct();
    
    if isfield(paramsData, 'influence')
        params.attenuation_factor = paramsData.influence.attenuation_factor;
    end
    
    if isfield(paramsData, 'propagation')
        params.risk_multiplier = paramsData.propagation.risk_multiplier_critical_path;
    end
    
    if isfield(paramsData, 'alignment')
        params.alignment_weights = paramsData.alignment.weights;
    end
end

function params = getDefaultParameters()
    % Default parameters from metrics.json
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

function classifications = classifyAllNodes(riskScores)
    % Classify all nodes into 2x2 matrix quadrants
    nNodes = length(riskScores.nodeIds);
    classifications = cell(nNodes, 1);
    
    % Calculate thresholds (median split)
    riskThreshold = median(riskScores.risk);
    influenceThreshold = median(riskScores.influence);
    
    for i = 1:nNodes
        risk = riskScores.risk(i);
        influence = riskScores.influence(i);
        
        if risk >= riskThreshold && influence >= influenceThreshold
            classifications{i} = 'Q1'; % High Risk, High Influence - Mitigate
        elseif risk < riskThreshold && influence >= influenceThreshold
            classifications{i} = 'Q2'; % Low Risk, High Influence - Automate
        elseif risk >= riskThreshold && influence < influenceThreshold
            classifications{i} = 'Q3'; % High Risk, Low Influence - Contingency
        else
            classifications{i} = 'Q4'; % Low Risk, Low Influence - Delegate
        end
    end
end

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

