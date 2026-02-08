function quadrant = classifyQuadrant(risk, influence, riskThreshold, influenceThreshold)
    % CLASSIFYQUADRANT Classifies a node into 2x2 Risk-Influence Matrix quadrant
    %
    % Quadrants:
    %   Q1: High Risk, High Influence -> "Mitigate"
    %   Q2: Low Risk, High Influence -> "Automate"
    %   Q3: High Risk, Low Influence -> "Contingency"
    %   Q4: Low Risk, Low Influence -> "Delegate"
    %
    % Inputs:
    %   risk - Risk score (scalar or vector) OR analysis structure (OpenAPI format)
    %   influence - Influence score (scalar or vector, same size as risk) OR nodeId if risk is analysis
    %   riskThreshold - Threshold for high/low risk (default: median if not provided)
    %   influenceThreshold - Threshold for high/low influence (default: median if not provided)
    %
    % Output:
    %   quadrant - Cell array of quadrant labels ('Q1', 'Q2', 'Q3', 'Q4')
    %              or single string if scalar inputs
    %
    % Usage:
    %   % Traditional usage with scores
    %   quadrant = classifyQuadrant(0.7, 0.8);
    %
    %   % OpenAPI format usage
    %   quadrant = classifyQuadrant(analysis, 'node1');
    %
    %   % Or extract values first using openapiHelpers
    %   risk = openapiHelpers('getRiskLevel', analysis, 'node1');
    %   influence = openapiHelpers('getInfluenceScore', analysis, 'node1');
    %   quadrant = classifyQuadrant(risk, influence);
    
    % Check if first argument is an analysis structure (OpenAPI format)
    if isstruct(risk) && isfield(risk, 'node_assessments') && ischar(influence)
        % OpenAPI format: risk is analysis, influence is nodeId
        nodeId = influence;
        analysis = risk;
        risk = openapiHelpers('getRiskLevel', analysis, nodeId);
        influence = openapiHelpers('getInfluenceScore', analysis, nodeId);
    end
    
    % Handle scalar vs vector inputs
    isScalar = isscalar(risk) && isscalar(influence);
    
    if ~isscalar(risk)
        risk = risk(:); % Ensure column vector
    end
    if ~isscalar(influence)
        influence = influence(:); % Ensure column vector
    end
    
    if length(risk) ~= length(influence)
        error('Risk and influence must have the same length');
    end
    
    % Calculate thresholds if not provided
    if nargin < 3 || isempty(riskThreshold)
        riskThreshold = median(risk);
    end
    if nargin < 4 || isempty(influenceThreshold)
        influenceThreshold = median(influence);
    end
    
    % Initialize quadrant array
    n = length(risk);
    quadrant = cell(n, 1);
    
    % Classify each node
    for i = 1:n
        if risk(i) >= riskThreshold && influence(i) >= influenceThreshold
            quadrant{i} = 'Q1'; % High Risk, High Influence - Mitigate
        elseif risk(i) < riskThreshold && influence(i) >= influenceThreshold
            quadrant{i} = 'Q2'; % Low Risk, High Influence - Automate
        elseif risk(i) >= riskThreshold && influence(i) < influenceThreshold
            quadrant{i} = 'Q3'; % High Risk, Low Influence - Contingency
        else
            quadrant{i} = 'Q4'; % Low Risk, Low Influence - Delegate
        end
    end
    
    % Return scalar string if inputs were scalar
    if isScalar
        quadrant = quadrant{1};
    end
end

function action = getActionFromQuadrant(quadrant)
    % GETACTIONFROMQUADRANT Returns strategic action for a quadrant
    %
    % Input:
    %   quadrant - Quadrant label ('Q1', 'Q2', 'Q3', 'Q4')
    %
    % Output:
    %   action - Strategic action string
    
    switch quadrant
        case 'Q1'
            action = 'Mitigate';
        case 'Q2'
            action = 'Automate';
        case 'Q3'
            action = 'Contingency';
        case 'Q4'
            action = 'Delegate';
        otherwise
            action = 'Unknown';
    end
end

