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
        data.riskScores.importance = zeros(nNodes, 1); % New field for importance_score
        data.riskScores.localFailureProb = zeros(nNodes, 1);
        data.riskScores.cascadingRisk = zeros(nNodes, 1);
        data.riskScores.isOnCriticalPath = false(nNodes, 1); % New field for is_on_critical_path
        
        for i = 1:nNodes
            nodeId = nodeIds{i};
            assessment = nodeAssessments.(nodeId);
            
            data.riskScores.nodeIds{i} = nodeId;
            % Map API field names to MATLAB expected names
            % API returns influence_score, risk_level, importance_score
            if isfield(assessment, 'influence_score')
                data.riskScores.influence(i) = assessment.influence_score;
            elseif isfield(assessment, 'influence')
                % Fallback for backward compatibility
                data.riskScores.influence(i) = assessment.influence;
            end
            
            if isfield(assessment, 'risk_level')
                data.riskScores.risk(i) = assessment.risk_level;
                % Use risk_level as local failure probability estimate
                data.riskScores.localFailureProb(i) = assessment.risk_level;
            elseif isfield(assessment, 'risk')
                % Fallback for backward compatibility
                data.riskScores.risk(i) = assessment.risk;
                data.riskScores.localFailureProb(i) = assessment.risk;
            end
            
            % Extract importance_score (new API field)
            if isfield(assessment, 'importance_score')
                data.riskScores.importance(i) = assessment.importance_score;
            end
            
            % Extract is_on_critical_path (new API field)
            if isfield(assessment, 'is_on_critical_path')
                data.riskScores.isOnCriticalPath(i) = assessment.is_on_critical_path;
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
    
    % Parse matrix_classifications from API (preferred) or calculate from risk scores
    if isfield(analysis, 'matrix_classifications') && ~isempty(analysis.matrix_classifications)
        % API provides matrix_classifications - use it
        data.classifications = parseMatrixClassifications(analysis.matrix_classifications, data.riskScores);
    elseif isfield(analysis, 'action_matrix') && ~isempty(analysis.action_matrix)
        % Fallback to old action_matrix format
        data.classifications = parseActionMatrix(analysis.action_matrix, data.riskScores);
    elseif ~isempty(data.riskScores.nodeIds)
        % Calculate classifications from risk scores as last resort
        data.classifications = classifyAllNodes(data.riskScores);
    else
        data.classifications = {};
    end
    
    % Extract summary metrics with field name mapping
    if isfield(analysis, 'summary')
        data.summary = parseSummaryMetrics(analysis.summary);
    else
        data.summary = struct();
    end
    
    % Extract recommendation if available
    if isfield(analysis, 'recommendation')
        data.recommendation = analysis.recommendation;
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
            
            % Extract node name from assessment if available
            nodeName = nodeId;
            if isfield(analysis, 'node_assessments') && isfield(analysis.node_assessments, nodeId)
                assessment = analysis.node_assessments.(nodeId);
                if isfield(assessment, 'node_name') && ~isempty(assessment.node_name)
                    nodeName = assessment.node_name;
                end
            end
            
            % If no name found in assessment, try to extract from node ID
            if strcmp(nodeName, nodeId)
                if startsWith(nodeId, 'node_')
                    nodeName = strrep(nodeId(6:end), '_', ' ');
                end
            end
            
            graph.nodes{i} = struct('id', nodeId, 'name', nodeName);
            graph.nodeNames{i} = nodeName;
        end
        
        % Build edges from critical chains
        % API returns all_chains (not critical_chains) with node_ids (not nodes)
        edges = {};
        chains = [];
        if isfield(analysis, 'all_chains') && ~isempty(analysis.all_chains)
            chains = analysis.all_chains;
        elseif isfield(analysis, 'critical_chains') && ~isempty(analysis.critical_chains)
            % Fallback for backward compatibility
            chains = analysis.critical_chains;
        end
        
        if ~isempty(chains)
            % Handle both cell array and struct array formats
            if iscell(chains)
                % Cell array of chain structs
                for chainIdx = 1:length(chains)
                    chain = chains{chainIdx};
                    if isstruct(chain)
                        edges = processChain(chain, edges);
                    end
                end
            elseif isstruct(chains)
                % Struct array - check if it's a scalar struct or array
                if length(chains) == 1 && isscalar(chains)
                    % Single struct
                    edges = processChain(chains, edges);
                else
                    % Struct array
                    for chainIdx = 1:length(chains)
                        chain = chains(chainIdx);
                        edges = processChain(chain, edges);
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

function edges = processChain(chain, edges)
    % PROCESSCHAIN Process a single chain and add edges to edges array
    
    % Handle both node_ids (new API) and nodes (old format)
    chainNodes = [];
    if isfield(chain, 'node_ids') && ~isempty(chain.node_ids)
        chainNodes = chain.node_ids;
    elseif isfield(chain, 'nodes') && ~isempty(chain.nodes)
        chainNodes = chain.nodes;
    end
    
    if ~isempty(chainNodes) && length(chainNodes) > 1
        % Get weight from chain
        chainWeight = 1.0; % Default weight
        if isfield(chain, 'cumulative_risk')
            chainWeight = chain.cumulative_risk;
        elseif isfield(chain, 'aggregate_risk')
            % Fallback for backward compatibility
            chainWeight = chain.aggregate_risk;
        end
        
        % Create edges between consecutive nodes in chain
        for i = 1:(length(chainNodes) - 1)
            edge = struct();
            % Handle both cell array and array formats for node IDs
            if iscell(chainNodes)
                edge.source = chainNodes{i};
                edge.target = chainNodes{i+1};
            else
                % Array format - convert to string if needed
                edge.source = chainNodes(i);
                edge.target = chainNodes(i+1);
                if isnumeric(edge.source)
                    edge.source = num2str(edge.source);
                end
                if isnumeric(edge.target)
                    edge.target = num2str(edge.target);
                end
            end
            edge.weight = chainWeight;
            edges{end+1} = edge;
        end
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

function classifications = parseMatrixClassifications(matrixClassifications, riskScores)
    % PARSEMATRIXCLASSIFICATIONS Parse matrix_classifications from API response
    %
    % The API returns matrix_classifications as a dict where:
    % - Keys are RiskQuadrant enum values (e.g., "TYPE_A", "TYPE_B", "TYPE_C", "TYPE_D")
    % - Values are lists of NodeClassification objects with node_id, node_name, etc.
    %
    % We transform this into a cell array of quadrant strings, one per node.
    
    nNodes = length(riskScores.nodeIds);
    classifications = cell(nNodes, 1);
    
    if nNodes == 0
        return;
    end
    
    % Create a map from node_id to quadrant
    nodeToQuadrant = containers.Map();
    
    % Iterate through each quadrant in matrix_classifications
    quadrantKeys = fieldnames(matrixClassifications);
    for q = 1:length(quadrantKeys)
        quadrantKey = quadrantKeys{q};
        nodeList = matrixClassifications.(quadrantKey);
        
        % Handle both cell array and struct array formats
        if iscell(nodeList)
            for n = 1:length(nodeList)
                nodeClass = nodeList{n};
                if isstruct(nodeClass) && isfield(nodeClass, 'node_id')
                    nodeId = nodeClass.node_id;
                    % Convert to char if it's a string
                    if isstring(nodeId)
                        nodeId = char(nodeId);
                    end
                    % Map quadrant enum to MATLAB format
                    if contains(quadrantKey, 'TYPE_A') || contains(quadrantKey, 'Type A')
                        nodeToQuadrant(nodeId) = 'Q1'; % High Risk, High Influence - Mitigate
                    elseif contains(quadrantKey, 'TYPE_B') || contains(quadrantKey, 'Type B')
                        nodeToQuadrant(nodeId) = 'Q2'; % Low Risk, High Influence - Automate
                    elseif contains(quadrantKey, 'TYPE_C') || contains(quadrantKey, 'Type C')
                        nodeToQuadrant(nodeId) = 'Q3'; % High Risk, Low Influence - Contingency
                    elseif contains(quadrantKey, 'TYPE_D') || contains(quadrantKey, 'Type D')
                        nodeToQuadrant(nodeId) = 'Q4'; % Low Risk, Low Influence - Delegate
                    end
                end
            end
        elseif isstruct(nodeList) && length(nodeList) > 0
            % Handle struct array
            for n = 1:length(nodeList)
                nodeClass = nodeList(n);
                if isfield(nodeClass, 'node_id')
                    nodeId = nodeClass.node_id;
                    % Convert to char if it's a string
                    if isstring(nodeId)
                        nodeId = char(nodeId);
                    end
                    % Map quadrant enum to MATLAB format
                    if contains(quadrantKey, 'TYPE_A') || contains(quadrantKey, 'Type A')
                        nodeToQuadrant(nodeId) = 'Q1';
                    elseif contains(quadrantKey, 'TYPE_B') || contains(quadrantKey, 'Type B')
                        nodeToQuadrant(nodeId) = 'Q2';
                    elseif contains(quadrantKey, 'TYPE_C') || contains(quadrantKey, 'Type C')
                        nodeToQuadrant(nodeId) = 'Q3';
                    elseif contains(quadrantKey, 'TYPE_D') || contains(quadrantKey, 'Type D')
                        nodeToQuadrant(nodeId) = 'Q4';
                    end
                end
            end
        end
    end
    
    % Assign classifications to each node
    for i = 1:nNodes
        nodeId = riskScores.nodeIds{i};
        if isKey(nodeToQuadrant, nodeId)
            classifications{i} = nodeToQuadrant(nodeId);
        else
            % Fallback: calculate from risk scores
            risk = riskScores.risk(i);
            influence = riskScores.influence(i);
            riskThreshold = median(riskScores.risk);
            influenceThreshold = median(riskScores.influence);
            
            if risk >= riskThreshold && influence >= influenceThreshold
                classifications{i} = 'Q1';
            elseif risk < riskThreshold && influence >= influenceThreshold
                classifications{i} = 'Q2';
            elseif risk >= riskThreshold && influence < influenceThreshold
                classifications{i} = 'Q3';
            else
                classifications{i} = 'Q4';
            end
        end
    end
end

function classifications = parseActionMatrix(actionMatrix, riskScores)
    % PARSEACTIONMATRIX Parse old action_matrix format (backward compatibility)
    
    nNodes = length(riskScores.nodeIds);
    classifications = cell(nNodes, 1);
    
    if nNodes == 0
        return;
    end
    
    % Create a map from node_id to quadrant
    nodeToQuadrant = containers.Map();
    
    % Map action_matrix quadrants to classifications
    if isfield(actionMatrix, 'mitigate')
        nodes = actionMatrix.mitigate;
        if iscell(nodes)
            for n = 1:length(nodes)
                nodeToQuadrant(nodes{n}) = 'Q1';
            end
        end
    end
    if isfield(actionMatrix, 'automate')
        nodes = actionMatrix.automate;
        if iscell(nodes)
            for n = 1:length(nodes)
                nodeToQuadrant(nodes{n}) = 'Q2';
            end
        end
    end
    if isfield(actionMatrix, 'contingency')
        nodes = actionMatrix.contingency;
        if iscell(nodes)
            for n = 1:length(nodes)
                nodeToQuadrant(nodes{n}) = 'Q3';
            end
        end
    end
    if isfield(actionMatrix, 'delegate')
        nodes = actionMatrix.delegate;
        if iscell(nodes)
            for n = 1:length(nodes)
                nodeToQuadrant(nodes{n}) = 'Q4';
            end
        end
    end
    
    % Assign classifications
    for i = 1:nNodes
        nodeId = riskScores.nodeIds{i};
        if isKey(nodeToQuadrant, nodeId)
            classifications{i} = nodeToQuadrant(nodeId);
        else
            % Default to Q4 if not found
            classifications{i} = 'Q4';
        end
    end
end

function summary = parseSummaryMetrics(apiSummary)
    % PARSESUMMARYMETRICS Parse summary metrics with field name mapping
    
    summary = struct();
    
    % Map aggregate_project_score to overall_bankability for backward compatibility
    if isfield(apiSummary, 'aggregate_project_score')
        summary.overall_bankability = apiSummary.aggregate_project_score;
        summary.aggregate_project_score = apiSummary.aggregate_project_score;
    elseif isfield(apiSummary, 'overall_bankability')
        % Fallback for old API format
        summary.overall_bankability = apiSummary.overall_bankability;
    end
    
    % Extract critical_failure_likelihood
    if isfield(apiSummary, 'critical_failure_likelihood')
        summary.critical_failure_likelihood = apiSummary.critical_failure_likelihood;
    end
    
    % Extract nodes_evaluated and total_nodes
    if isfield(apiSummary, 'nodes_evaluated')
        summary.nodes_evaluated = apiSummary.nodes_evaluated;
    end
    if isfield(apiSummary, 'nodes_analyzed')
        summary.nodes_analyzed = apiSummary.nodes_analyzed;
    end
    if isfield(apiSummary, 'total_nodes')
        summary.total_nodes = apiSummary.total_nodes;
    end
    
    % Extract critical_dependency_count
    if isfield(apiSummary, 'critical_dependency_count')
        summary.critical_dependency_count = apiSummary.critical_dependency_count;
    end
    
    % Extract average_risk and maximum_risk (old API format)
    if isfield(apiSummary, 'average_risk')
        summary.average_risk = apiSummary.average_risk;
    end
    if isfield(apiSummary, 'maximum_risk')
        summary.maximum_risk = apiSummary.maximum_risk;
    end
    
    % Extract total_token_cost
    if isfield(apiSummary, 'total_token_cost')
        summary.total_token_cost = apiSummary.total_token_cost;
    end
    if isfield(apiSummary, 'budget_used')
        summary.budget_used = apiSummary.budget_used;
    end
    
    % Extract recommendations if available
    if isfield(apiSummary, 'recommendations')
        summary.recommendations = apiSummary.recommendations;
    end
    
    % Extract firm_id and project_id if available
    if isfield(apiSummary, 'firm_id')
        summary.firm_id = apiSummary.firm_id;
    end
    if isfield(apiSummary, 'project_id')
        summary.project_id = apiSummary.project_id;
    end
end


