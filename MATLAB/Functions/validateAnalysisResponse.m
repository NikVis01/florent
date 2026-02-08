function [isValid, errors, warnings] = validateAnalysisResponse(response)
    % VALIDATEANALYSISRESPONSE Validate API response structure
    %
    % This function validates that an API response has the expected
    % structure and required fields.
    %
    % Usage:
    %   [isValid, errors, warnings] = validateAnalysisResponse(response)
    %
    % Arguments:
    %   response - API response structure to validate
    %
    % Returns:
    %   isValid  - Boolean indicating if response is valid
    %   errors   - Cell array of error messages
    %   warnings - Cell array of warning messages
    
    isValid = true;
    errors = {};
    warnings = {};
    
    % Check top-level structure
    if ~isstruct(response)
        errors{end+1} = 'Response is not a structure';
        isValid = false;
        return;
    end
    
    % Check status field
    if ~isfield(response, 'status')
        errors{end+1} = 'Response missing status field';
        isValid = false;
    else
        if ~ismember(response.status, {'success', 'error'})
            errors{end+1} = sprintf('Invalid status value: %s', response.status);
            isValid = false;
        end
    end
    
    % Check message field
    if ~isfield(response, 'message')
        warnings{end+1} = 'Response missing message field';
    end
    
    % If status is error, that's valid but we should note it
    if isfield(response, 'status') && strcmp(response.status, 'error')
        if ~isfield(response, 'message')
            errors{end+1} = 'Error response missing message field';
            isValid = false;
        end
        return; % Don't validate analysis field for error responses
    end
    
    % Validate analysis field for success responses
    if ~isfield(response, 'analysis')
        errors{end+1} = 'Success response missing analysis field';
        isValid = false;
        return;
    end
    
    analysis = response.analysis;
    
    % Check node_assessments
    if ~isfield(analysis, 'node_assessments')
        warnings{end+1} = 'Analysis missing node_assessments field';
    else
        nodeAssessments = analysis.node_assessments;
        if isstruct(nodeAssessments)
            nodeIds = fieldnames(nodeAssessments);
            for i = 1:length(nodeIds)
                nodeId = nodeIds{i};
                assessment = nodeAssessments.(nodeId);
                
                if ~isfield(assessment, 'influence')
                    warnings{end+1} = sprintf('Node %s missing influence field', nodeId);
                end
                if ~isfield(assessment, 'risk')
                    warnings{end+1} = sprintf('Node %s missing risk field', nodeId);
                end
                if ~isfield(assessment, 'reasoning')
                    warnings{end+1} = sprintf('Node %s missing reasoning field', nodeId);
                end
            end
        end
    end
    
    % Check action_matrix
    if ~isfield(analysis, 'action_matrix')
        warnings{end+1} = 'Analysis missing action_matrix field';
    else
        matrix = analysis.action_matrix;
        requiredQuadrants = {'mitigate', 'automate', 'contingency', 'delegate'};
        for i = 1:length(requiredQuadrants)
            if ~isfield(matrix, requiredQuadrants{i})
                warnings{end+1} = sprintf('Action matrix missing %s quadrant', requiredQuadrants{i});
            end
        end
    end
    
    % Check critical_chains
    if ~isfield(analysis, 'critical_chains')
        warnings{end+1} = 'Analysis missing critical_chains field';
    else
        chains = analysis.critical_chains;
        if ~iscell(chains) && ~isempty(chains)
            warnings{end+1} = 'critical_chains should be a cell array';
        end
    end
    
    % Check summary
    if ~isfield(analysis, 'summary')
        warnings{end+1} = 'Analysis missing summary field';
    else
        summary = analysis.summary;
        requiredFields = {'overall_bankability', 'average_risk', 'maximum_risk'};
        for i = 1:length(requiredFields)
            if ~isfield(summary, requiredFields{i})
                warnings{end+1} = sprintf('Summary missing %s field', requiredFields{i});
            end
        end
    end
end


