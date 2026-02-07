function data = parseAnalysisResponse(response, projectId, firmId)
    % PARSEANALYSISRESPONSE Transform API response to MATLAB data structure
    %
    % This function transforms the /analyze endpoint response into the data
    % structure expected by existing MATLAB code, maintaining backward
    % compatibility.
    %
    % Usage:
    %   data = parseAnalysisResponse(response, 'proj_001', 'firm_001')
    %
    % Arguments:
    %   response  - API response structure from /analyze endpoint
    %   projectId - Project identifier
    %   firmId    - Firm identifier
    %
    % Returns:
    %   data - Data structure compatible with existing MATLAB code:
    %     - graph: nodes, edges, adjacency matrix
    %     - riskScores: risk and influence scores per node
    %     - parameters: default parameters
    %     - classifications: 2x2 matrix quadrant per node
    
    % Validate response
    if ~isfield(response, 'status')
        error('Invalid response: missing status field');
    end
    
    if strcmp(response.status, 'error')
        error('API returned error: %s', response.message);
    end
    
    if ~isfield(response, 'analysis')
        error('Invalid response: missing analysis field');
    end
    
    analysis = response.analysis;
    
    % Initialize data structure
    data = struct();
    data.projectId = projectId;
    data.firmId = firmId;
    
    % Parse node assessments into riskScores structure
    if isfield(analysis, 'node_assessments')
        nodeAssessments = analysis.node_assessments;
        nodeIds = fieldnames(nodeAssessments);
        nNodes = length(nodeIds);
        
        data.riskScores = struct();
        data.riskScores.nodeIds = cell(nNodes, 1);
        data.riskScores.influence = zeros(nNodes, 1);
        data.riskScores.risk = zeros(nNodes, 1);
        data.riskScores.localFailureProb = zeros(nNodes, 1);
        data.riskScores.cascadingRisk = zeros(nNodes, 1);
        
        for i = 1:nNodes
            nodeId = nodeIds{i};
            assessment = nodeAssessments.(nodeId);
            
            data.riskScores.nodeIds{i} = nodeId;
            if isfield(assessment, 'influence')
                data.riskScores.influence(i) = assessment.influence;
            end
            if isfield(assessment, 'risk')
                data.riskScores.risk(i) = assessment.risk;
                % Use risk as local failure probability estimate
                data.riskScores.localFailureProb(i) = assessment.risk;
            end
            % Cascading risk will be calculated from critical chains
        end
    else
        % Empty structure if no assessments
        data.riskScores = struct();
        data.riskScores.nodeIds = {};
        data.riskScores.influence = [];
        data.riskScores.risk = [];
        data.riskScores.localFailureProb = [];
        data.riskScores.cascadingRisk = [];
    end
    
    % Build graph structure from critical chains and node assessments
    data.graph = buildGraphFromAnalysis(analysis, data.riskScores);
    
    % Extract parameters (use defaults, API doesn't return these)
    data.parameters = getDefaultParameters();
    
    % Calculate classifications from risk scores
    if ~isempty(data.riskScores.nodeIds)
        data.classifications = classifyAllNodes(data.riskScores);
    else
        data.classifications = {};
    end
    
    % Store raw analysis for reference
    data.rawAnalysis = analysis;
end

function graph = buildGraphFromAnalysis(analysis, riskScores)
    % Build graph structure from analysis response
    
    graph = struct();
    
    % Extract node IDs from assessments
    if isfield(analysis, 'node_assessments') && ~isempty(riskScores.nodeIds)
        nodeIds = riskScores.nodeIds;
        nNodes = length(nodeIds);
        
        % Create node structures
        graph.nodes = cell(nNodes, 1);
        graph.nodeIds = nodeIds;
        graph.nodeNames = cell(nNodes, 1);
        
        for i = 1:nNodes
            nodeId = nodeIds{i};
            graph.nodes{i} = struct('id', nodeId, 'name', nodeId);
            % Try to extract name from node ID (remove 'node_' prefix if present)
            if startsWith(nodeId, 'node_')
                graph.nodeNames{i} = strrep(nodeId(6:end), '_', ' ');
            else
                graph.nodeNames{i} = nodeId;
            end
        end
        
        % Build edges from critical chains
        edges = {};
        if isfield(analysis, 'critical_chains') && ~isempty(analysis.critical_chains)
            for chainIdx = 1:length(analysis.critical_chains)
                chain = analysis.critical_chains{chainIdx};
                if isfield(chain, 'nodes') && length(chain.nodes) > 1
                    chainNodes = chain.nodes;
                    for i = 1:(length(chainNodes) - 1)
                        edge = struct();
                        edge.source = chainNodes{i};
                        edge.target = chainNodes{i+1};
                        edge.weight = 1.0; % Default weight
                        edges{end+1} = edge;
                    end
                end
            end
        end
        
        graph.edges = edges;
        
        % Build adjacency matrix
        if ~isempty(nodeIds) && ~isempty(edges)
            graph.adjacency = buildAdjacencyMatrix(nodeIds, edges);
        else
            % Empty adjacency matrix
            graph.adjacency = zeros(nNodes, nNodes);
        end
    else
        % Empty graph structure
        graph.nodes = {};
        graph.nodeIds = {};
        graph.nodeNames = {};
        graph.edges = {};
        graph.adjacency = [];
    end
end

function adj = buildAdjacencyMatrix(nodeIds, edges)
    % Build adjacency matrix from nodes and edges
    
    nNodes = length(nodeIds);
    adj = zeros(nNodes, nNodes);
    
    % Create node ID to index map
    nodeIdMap = containers.Map();
    for i = 1:nNodes
        nodeIdMap(nodeIds{i}) = i;
    end
    
    % Fill adjacency matrix
    for i = 1:length(edges)
        edge = edges{i};
        if isKey(nodeIdMap, edge.source) && isKey(nodeIdMap, edge.target)
            srcIdx = nodeIdMap(edge.source);
            tgtIdx = nodeIdMap(edge.target);
            adj(srcIdx, tgtIdx) = edge.weight;
        end
    end
end

function classifications = classifyAllNodes(riskScores)
    % Classify all nodes into 2x2 matrix quadrants
    
    nNodes = length(riskScores.nodeIds);
    classifications = cell(nNodes, 1);
    
    if nNodes == 0
        return;
    end
    
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

