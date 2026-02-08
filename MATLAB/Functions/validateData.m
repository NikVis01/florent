function [isValid, errors, warnings] = validateData(data)
    % VALIDATEDATA Validates data structure for Florent analysis
    %
    % Supports both OpenAPI format and legacy format.
    %
    % Usage:
    %   [isValid, errors] = validateData(data)
    %   [isValid, errors, warnings] = validateData(data)
    %
    % Input:
    %   data - Data structure to validate (OpenAPI or legacy format)
    %
    % Output:
    %   isValid - True if data is valid
    %   errors - Cell array of error messages
    %   warnings - Cell array of warning messages
    
    errors = {};
    warnings = {};
    isValid = true;
    
    % Check if data is OpenAPI format or legacy format
    isOpenAPI = isstruct(data) && isfield(data, 'node_assessments');
    isLegacy = isstruct(data) && isfield(data, 'riskScores') && isfield(data, 'graph');
    
    if ~isOpenAPI && ~isLegacy
        errors{end+1} = 'Data structure is neither OpenAPI nor legacy format';
        isValid = false;
        return;
    end
    
    if isOpenAPI
        % Validate enhanced API format
        [openAPIValid, openAPIErrors, openAPIWarnings] = validateOpenAPIFormat(data);
        errors = [errors, openAPIErrors];
        warnings = [warnings, openAPIWarnings];
        isValid = isValid && openAPIValid;
        
        % Validate enhanced sections
        [enhancedValid, enhancedErrors, enhancedWarnings] = validateEnhancedSections(data);
        errors = [errors, enhancedErrors];
        warnings = [warnings, enhancedWarnings];
        isValid = isValid && enhancedValid;
    else
        % Validate legacy format
        requiredFields = {'graph', 'riskScores'};
        for i = 1:length(requiredFields)
            if ~isfield(data, requiredFields{i})
                errors{end+1} = sprintf('Missing required field: %s', requiredFields{i});
                isValid = false;
            end
        end
        
        if ~isValid
            return; % Can't continue validation without required fields
        end
        
        % Validate graph structure
        if isfield(data, 'graph')
            [graphValid, graphErrors, graphWarnings] = validateGraph(data.graph);
            errors = [errors, graphErrors];
            warnings = [warnings, graphWarnings];
            isValid = isValid && graphValid;
        end
        
        % Validate risk scores
        if isfield(data, 'riskScores')
            [scoresValid, scoreErrors, scoreWarnings] = validateRiskScores(data.riskScores);
            errors = [errors, scoreErrors];
            warnings = [warnings, scoreWarnings];
            isValid = isValid && scoresValid;
        end
        
        % Validate parameters (optional in legacy format)
        if isfield(data, 'parameters')
            [paramsValid, paramErrors, paramWarnings] = validateParameters(data.parameters);
            errors = [errors, paramErrors];
            warnings = [warnings, paramWarnings];
            isValid = isValid && paramsValid;
        end
    end
end

function [isValid, errors, warnings] = validateOpenAPIFormat(analysis)
    % VALIDATEOPENAPIFORMAT Validate OpenAPI format analysis structure
    
    errors = {};
    warnings = {};
    isValid = true;
    
    % Check required fields
    if ~isfield(analysis, 'node_assessments')
        errors{end+1} = 'Missing required field: node_assessments';
        isValid = false;
        return;
    end
    
    nodeAssessments = analysis.node_assessments;
    nodeIds = fieldnames(nodeAssessments);
    nNodes = length(nodeIds);
    
    if nNodes == 0
        errors{end+1} = 'node_assessments is empty';
        isValid = false;
        return;
    end
    
    % Validate each node assessment
    for i = 1:nNodes
        nodeId = nodeIds{i};
        assessment = nodeAssessments.(nodeId);
        
        % Check required fields in assessment
        if ~isfield(assessment, 'influence_score') && ~isfield(assessment, 'influence')
            warnings{end+1} = sprintf('Node %s missing influence_score', nodeId);
        end
        
        if ~isfield(assessment, 'risk_level') && ~isfield(assessment, 'risk')
            warnings{end+1} = sprintf('Node %s missing risk_level', nodeId);
        end
        
        % Validate score ranges if present
        if isfield(assessment, 'influence_score')
            score = assessment.influence_score;
            if score < 0 || score > 1
                warnings{end+1} = sprintf('Node %s influence_score outside [0, 1]: %.3f', nodeId, score);
            end
            if isnan(score) || isinf(score)
                errors{end+1} = sprintf('Node %s influence_score is NaN or Inf', nodeId);
                isValid = false;
            end
        end
        
        if isfield(assessment, 'risk_level')
            score = assessment.risk_level;
            if score < 0 || score > 1
                warnings{end+1} = sprintf('Node %s risk_level outside [0, 1]: %.3f', nodeId, score);
            end
            if isnan(score) || isinf(score)
                errors{end+1} = sprintf('Node %s risk_level is NaN or Inf', nodeId);
                isValid = false;
            end
        end
        
        if isfield(assessment, 'importance_score')
            score = assessment.importance_score;
            if score < 0 || score > 1
                warnings{end+1} = sprintf('Node %s importance_score outside [0, 1]: %.3f', nodeId, score);
            end
            if isnan(score) || isinf(score)
                errors{end+1} = sprintf('Node %s importance_score is NaN or Inf', nodeId);
                isValid = false;
            end
        end
    end
    
    % Validate matrix_classifications if present
    if isfield(analysis, 'matrix_classifications')
        matrix = analysis.matrix_classifications;
        if ~isstruct(matrix)
            warnings{end+1} = 'matrix_classifications should be a struct';
        end
    end
    
    % Validate all_chains if present
    if isfield(analysis, 'all_chains')
        chains = analysis.all_chains;
        if ~iscell(chains) && ~isstruct(chains)
            warnings{end+1} = 'all_chains should be a cell array or struct array';
        end
    end
    
    % Validate summary if present
    if isfield(analysis, 'summary')
        summary = analysis.summary;
        if ~isstruct(summary)
            warnings{end+1} = 'summary should be a struct';
        end
    end
end

function [isValid, errors, warnings] = validateEnhancedSections(analysis)
    % VALIDATEENHANCEDSECTIONS Validate enhanced schema sections
    %
    % Validates graph_topology, risk_distributions, monte_carlo_parameters,
    % propagation_trace, graph_statistics, etc.
    
    errors = {};
    warnings = {};
    isValid = true;
    
    % Validate graph_topology
    if isfield(analysis, 'graph_topology') && ~isempty(analysis.graph_topology)
        topo = analysis.graph_topology;
        
        % Check required fields
        requiredFields = {'adjacency_matrix', 'node_index', 'edges', 'nodes', 'statistics'};
        for i = 1:length(requiredFields)
            if ~isfield(topo, requiredFields{i})
                errors{end+1} = sprintf('graph_topology missing required field: %s', requiredFields{i});
                isValid = false;
            end
        end
        
        if isValid && isfield(topo, 'adjacency_matrix') && isfield(topo, 'node_index')
            adjMatrix = topo.adjacency_matrix;
            nodeIndex = topo.node_index;
            
            % Convert cell to matrix if needed
            if iscell(adjMatrix)
                adjMatrix = cell2mat(adjMatrix);
            end
            
            % Check matrix dimensions match node_index
            if size(adjMatrix, 1) ~= length(nodeIndex) || size(adjMatrix, 2) ~= length(nodeIndex)
                errors{end+1} = sprintf('graph_topology: adjacency_matrix size (%dx%d) does not match node_index length (%d)', ...
                    size(adjMatrix, 1), size(adjMatrix, 2), length(nodeIndex));
                isValid = false;
            end
        end
    else
        warnings{end+1} = 'graph_topology section not found (recommended for full functionality)';
    end
    
    % Validate risk_distributions
    if isfield(analysis, 'risk_distributions') && ~isempty(analysis.risk_distributions)
        riskDist = analysis.risk_distributions;
        
        if ~isfield(riskDist, 'nodes')
            errors{end+1} = 'risk_distributions missing required field: nodes';
            isValid = false;
        else
            % Validate node distributions
            nodeIds = fieldnames(riskDist.nodes);
            for i = 1:length(nodeIds)
                nodeId = nodeIds{i};
                nodeDist = riskDist.nodes.(nodeId);
                
                % Check required fields
                if ~isfield(nodeDist, 'importance') || ~isfield(nodeDist, 'influence') || ~isfield(nodeDist, 'risk')
                    warnings{end+1} = sprintf('risk_distributions.nodes.%s missing some required fields', nodeId);
                end
            end
        end
    else
        warnings{end+1} = 'risk_distributions section not found (recommended for Monte Carlo simulations)';
    end
    
    % Validate monte_carlo_parameters
    if isfield(analysis, 'monte_carlo_parameters') && ~isempty(analysis.monte_carlo_parameters)
        mcParams = analysis.monte_carlo_parameters;
        
        requiredFields = {'sampling_distributions', 'simulation_config', 'covariance_matrix'};
        for i = 1:length(requiredFields)
            if ~isfield(mcParams, requiredFields{i})
                errors{end+1} = sprintf('monte_carlo_parameters missing required field: %s', requiredFields{i});
                isValid = false;
            end
        end
        
        if isValid && isfield(mcParams, 'covariance_matrix')
            covMatrix = mcParams.covariance_matrix;
            if iscell(covMatrix)
                covMatrix = cell2mat(covMatrix);
            end
            
            % Check covariance matrix is square
            if size(covMatrix, 1) ~= size(covMatrix, 2)
                errors{end+1} = 'monte_carlo_parameters: covariance_matrix must be square';
                isValid = false;
            end
        end
    else
        warnings{end+1} = 'monte_carlo_parameters section not found (recommended for Monte Carlo simulations)';
    end
    
    % Validate propagation_trace (optional)
    if isfield(analysis, 'propagation_trace') && ~isempty(analysis.propagation_trace)
        propTrace = analysis.propagation_trace;
        
        if ~isfield(propTrace, 'nodes') || ~isfield(propTrace, 'config')
            warnings{end+1} = 'propagation_trace missing some recommended fields';
        end
    end
    
    % Validate graph_statistics (optional)
    if isfield(analysis, 'graph_statistics') && ~isempty(analysis.graph_statistics)
        graphStats = analysis.graph_statistics;
        
        if ~isfield(graphStats, 'centrality') || ~isfield(graphStats, 'paths') || ~isfield(graphStats, 'clustering')
            warnings{end+1} = 'graph_statistics missing some recommended fields';
        end
    end
end

function [isValid, errors, warnings] = validateGraph(graph)
    % Validate graph structure
    
    errors = {};
    warnings = {};
    isValid = true;
    
    % Check required fields
    if ~isfield(graph, 'adjacency')
        errors{end+1} = 'Graph missing adjacency matrix';
        isValid = false;
        return;
    end
    
    adj = graph.adjacency;
    
    % Check adjacency matrix is square
    if size(adj, 1) ~= size(adj, 2)
        errors{end+1} = 'Adjacency matrix must be square';
        isValid = false;
    end
    
    % Check for cycles (DAG validation)
    if isValid
        try
            % Try topological sort - will fail if cycles exist
            sorted = topologicalSort(adj);
            if length(sorted) ~= size(adj, 1)
                warnings{end+1} = 'Graph may contain cycles or disconnected components';
            end
        catch ME
            errors{end+1} = sprintf('Graph validation failed: %s', ME.message);
            isValid = false;
        end
    end
    
    % Check node consistency
    if isfield(graph, 'nodeIds')
        nNodes = length(graph.nodeIds);
        if size(adj, 1) ~= nNodes
            errors{end+1} = sprintf('Adjacency matrix size (%d) does not match number of nodes (%d)', ...
                size(adj, 1), nNodes);
            isValid = false;
        end
    end
end

function [isValid, errors, warnings] = validateRiskScores(riskScores)
    % Validate risk scores structure
    
    errors = {};
    warnings = {};
    isValid = true;
    
    % Check required fields
    if ~isfield(riskScores, 'nodeIds')
        errors{end+1} = 'Risk scores missing nodeIds';
        isValid = false;
    end
    
    if ~isfield(riskScores, 'risk') || ~isfield(riskScores, 'influence')
        errors{end+1} = 'Risk scores missing risk or influence fields';
        isValid = false;
    end
    
    if ~isValid
        return;
    end
    
    nNodes = length(riskScores.nodeIds);
    
    % Check score arrays have correct length
    if length(riskScores.risk) ~= nNodes
        errors{end+1} = sprintf('Risk array length (%d) does not match number of nodes (%d)', ...
            length(riskScores.risk), nNodes);
        isValid = false;
    end
    
    if length(riskScores.influence) ~= nNodes
        errors{end+1} = sprintf('Influence array length (%d) does not match number of nodes (%d)', ...
            length(riskScores.influence), nNodes);
        isValid = false;
    end
    
    % Check score ranges
    if any(riskScores.risk < 0) || any(riskScores.risk > 1)
        warnings{end+1} = 'Some risk scores outside [0, 1] range';
    end
    
    if any(riskScores.influence < 0) || any(riskScores.influence > 1)
        warnings{end+1} = 'Some influence scores outside [0, 1] range';
    end
    
    % Check for NaN or Inf
    if any(isnan(riskScores.risk)) || any(isinf(riskScores.risk))
        errors{end+1} = 'Risk scores contain NaN or Inf';
        isValid = false;
    end
    
    if any(isnan(riskScores.influence)) || any(isinf(riskScores.influence))
        errors{end+1} = 'Influence scores contain NaN or Inf';
        isValid = false;
    end
end

function [isValid, errors, warnings] = validateParameters(parameters)
    % Validate parameters structure
    
    errors = {};
    warnings = {};
    isValid = true;
    
    % Check required parameters
    if ~isfield(parameters, 'attenuation_factor')
        warnings{end+1} = 'Missing attenuation_factor, using default';
    elseif parameters.attenuation_factor <= 0
        errors{end+1} = 'attenuation_factor must be > 0';
        isValid = false;
    end
    
    if ~isfield(parameters, 'risk_multiplier')
        warnings{end+1} = 'Missing risk_multiplier, using default';
    elseif parameters.risk_multiplier <= 0
        errors{end+1} = 'risk_multiplier must be > 0';
        isValid = false;
    end
    
    if ~isfield(parameters, 'alignment_weights')
        warnings{end+1} = 'Missing alignment_weights, using default';
    end
end

