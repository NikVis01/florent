function [isValid, errors, warnings] = validateData(data)
    % VALIDATEDATA Validates data structure for Florent analysis
    %
    % Usage:
    %   [isValid, errors] = validateData(data)
    %   [isValid, errors, warnings] = validateData(data)
    %
    % Input:
    %   data - Data structure to validate
    %
    % Output:
    %   isValid - True if data is valid
    %   errors - Cell array of error messages
    %   warnings - Cell array of warning messages
    
    errors = {};
    warnings = {};
    isValid = true;
    
    % Check required top-level fields
    requiredFields = {'graph', 'riskScores', 'parameters'};
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
    
    % Validate parameters
    if isfield(data, 'parameters')
        [paramsValid, paramErrors, paramWarnings] = validateParameters(data.parameters);
        errors = [errors, paramErrors];
        warnings = [warnings, paramWarnings];
        isValid = isValid && paramsValid;
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

