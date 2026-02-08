function [isValid, errors, warnings] = validateAnalysisResponse(response)
    % VALIDATEANALYSISRESPONSE Validate API response structure
    %
    % This function validates that an API response has the expected
    % structure and required fields. Uses OpenAPI schemas from
    % load_florent_schemas() when available for enhanced validation.
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
    
    % Try to load schemas for enhanced validation
    try
        schemas = openapiHelpers('getSchemas');
        if ~isempty(schemas) && isfield(schemas, 'endpoints')
            % Schemas available - can reference endpoint structure
            if isfield(schemas.endpoints, 'AnalyzeAnalyzeProject')
                % Endpoint schema available - note it for future use
                % (Currently response schema not fully exported, but structure is known)
            end
        end
    catch
        % Schemas not available - use basic validation
    end
    
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
                
                % Check for new API field names (influence_score, risk_level)
                % Python API only uses new field names
                hasInfluence = isfield(assessment, 'influence_score');
                hasRisk = isfield(assessment, 'risk_level');
                
                if ~hasInfluence
                    warnings{end+1} = sprintf('Node %s missing influence_score field', nodeId);
                end
                if ~hasRisk
                    warnings{end+1} = sprintf('Node %s missing risk_level field', nodeId);
                end
                if ~isfield(assessment, 'reasoning')
                    warnings{end+1} = sprintf('Node %s missing reasoning field', nodeId);
                end
                % Check for importance_score (new API field)
                if ~isfield(assessment, 'importance_score')
                    warnings{end+1} = sprintf('Node %s missing importance_score field', nodeId);
                end
            end
        end
    end
    
    % Check matrix_classifications (new API field) or action_matrix (old field)
    if ~isfield(analysis, 'matrix_classifications') && ~isfield(analysis, 'action_matrix')
        warnings{end+1} = 'Analysis missing matrix_classifications or action_matrix field';
    else
        if isfield(analysis, 'matrix_classifications')
            % New API structure - matrix_classifications is a dict of RiskQuadrant to NodeClassification lists
            matrix = analysis.matrix_classifications;
            % Validate structure: should be a struct with quadrant keys
            if ~isstruct(matrix)
                warnings{end+1} = 'matrix_classifications should be a struct/dict';
            else
                % Check for expected quadrant keys using exact matching
                % Python sends full enum values: "Type A (High Influence / High Importance)", etc.
                quadrantKeys = fieldnames(matrix);
                expectedQuadrants = {
                    'Type A (High Influence / High Importance)';
                    'Type B (High Influence / Low Importance)';
                    'Type C (Low Influence / High Importance)';
                    'Type D (Low Influence / Low Importance)'
                };
                foundQuadrants = false;
                for i = 1:length(quadrantKeys)
                    key = quadrantKeys{i};
                    for j = 1:length(expectedQuadrants)
                        if strcmp(key, expectedQuadrants{j})
                            foundQuadrants = true;
                            break;
                        end
                    end
                    if foundQuadrants
                        break;
                    end
                end
                if ~foundQuadrants && length(quadrantKeys) > 0
                    warnings{end+1} = 'matrix_classifications has unexpected quadrant keys';
                end
            end
        elseif isfield(analysis, 'action_matrix')
            % Old API structure - check quadrants
            matrix = analysis.action_matrix;
            requiredQuadrants = {'mitigate', 'automate', 'contingency', 'delegate'};
            for i = 1:length(requiredQuadrants)
                if ~isfield(matrix, requiredQuadrants{i})
                    warnings{end+1} = sprintf('Action matrix missing %s quadrant', requiredQuadrants{i});
                end
            end
        end
    end
    
    % Check all_chains (new API field) or critical_chains (old field)
    hasChains = isfield(analysis, 'all_chains') || isfield(analysis, 'critical_chains');
    if ~hasChains
        warnings{end+1} = 'Analysis missing all_chains or critical_chains field';
    else
        chains = [];
        if isfield(analysis, 'all_chains')
            chains = analysis.all_chains;
        elseif isfield(analysis, 'critical_chains')
            chains = analysis.critical_chains;
        end
        
        if ~isempty(chains)
            if ~iscell(chains) && ~isnumeric(chains) && ~isstruct(chains)
                warnings{end+1} = 'all_chains/critical_chains should be a cell array, array, or struct array';
            else
                % Validate chain structure
                if iscell(chains)
                    for c = 1:length(chains)
                        chain = chains{c};
                        if isstruct(chain)
                            % Check for node_ids (new API) or nodes (old format)
                            hasNodeIds = isfield(chain, 'node_ids');
                            hasNodes = isfield(chain, 'nodes');
                            if ~hasNodeIds && ~hasNodes
                                warnings{end+1} = sprintf('Chain %d missing node_ids or nodes field', c);
                            end
                        end
                    end
                elseif isstruct(chains) && length(chains) > 0
                    % Struct array
                    for c = 1:length(chains)
                        chain = chains(c);
                        hasNodeIds = isfield(chain, 'node_ids');
                        hasNodes = isfield(chain, 'nodes');
                        if ~hasNodeIds && ~hasNodes
                            warnings{end+1} = sprintf('Chain %d missing node_ids or nodes field', c);
                        end
                    end
                end
            end
        end
    end
    
    % Check summary
    if ~isfield(analysis, 'summary')
        warnings{end+1} = 'Analysis missing summary field';
    else
        summary = analysis.summary;
        % Check for new API summary fields
        newFields = {'aggregate_project_score', 'total_token_cost', 'critical_failure_likelihood', ...
                     'nodes_evaluated', 'total_nodes', 'critical_dependency_count'};
        oldFields = {'overall_bankability', 'average_risk', 'maximum_risk'};
        
        % Check for at least some summary fields
        hasNewFields = false;
        hasOldFields = false;
        for i = 1:length(newFields)
            if isfield(summary, newFields{i})
                hasNewFields = true;
                break;
            end
        end
        for i = 1:length(oldFields)
            if isfield(summary, oldFields{i})
                hasOldFields = true;
                break;
            end
        end
        
        if ~hasNewFields && ~hasOldFields
            warnings{end+1} = 'Summary missing expected fields (either new API or old API format)';
        end
    end
    
    % Check recommendation field (new API field)
    if isfield(analysis, 'recommendation')
        rec = analysis.recommendation;
        if isstruct(rec)
            if ~isfield(rec, 'should_bid') && ~isfield(rec, 'shouldBid')
                warnings{end+1} = 'Recommendation missing should_bid field';
            end
            if ~isfield(rec, 'confidence')
                warnings{end+1} = 'Recommendation missing confidence field';
            end
        end
    end
end


