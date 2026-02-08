function [isValid, errors, warnings] = validateAnalysisResponse(response)
    % VALIDATEANALYSISRESPONSE Validate API response structure
    %
    % This function validates that an API response has the expected
    % structure and required fields. Uses enhanced schemas from
    % load_enhanced_schemas() for validation against AnalysisOutput schema.
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
    
    % Try to load enhanced schemas for validation
    enhancedSchemas = [];
    try
        enhancedSchemas = openapiHelpers('getEnhancedSchemas');
        if ~isempty(enhancedSchemas) && isfield(enhancedSchemas, 'AnalysisOutput')
            % Enhanced schemas available - will use for validation
        end
    catch
        % Enhanced schemas not available - will use basic validation
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
    
    % Check matrix_classifications (Python API only uses this field)
    if ~isfield(analysis, 'matrix_classifications')
        warnings{end+1} = 'Analysis missing matrix_classifications field';
    else
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
    end
    
    % Check all_chains (Python API only uses this field)
    if ~isfield(analysis, 'all_chains')
        warnings{end+1} = 'Analysis missing all_chains field';
    else
        chains = analysis.all_chains;
        
        if ~isempty(chains)
            if ~iscell(chains) && ~isnumeric(chains) && ~isstruct(chains)
                warnings{end+1} = 'all_chains should be a cell array, array, or struct array';
            else
                % Validate chain structure
                if iscell(chains)
                    for c = 1:length(chains)
                        chain = chains{c};
                        if isstruct(chain)
                            % Check for node_ids (Python API only uses this field)
                            if ~isfield(chain, 'node_ids')
                                warnings{end+1} = sprintf('Chain %d missing node_ids field', c);
                            end
                        end
                    end
                elseif isstruct(chains) && length(chains) > 0
                    % Struct array
                    for c = 1:length(chains)
                        chain = chains(c);
                        if ~isfield(chain, 'node_ids')
                            warnings{end+1} = sprintf('Chain %d missing node_ids field', c);
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
    
    % Validate enhanced sections against enhanced schemas if available
    if ~isempty(enhancedSchemas)
        % Validate graph_topology
        if isfield(analysis, 'graph_topology') && isfield(enhancedSchemas, 'GraphTopology')
            [sectionValid, sectionErrors, sectionWarnings] = validateEnhancedSection(...
                analysis.graph_topology, enhancedSchemas.GraphTopology, 'graph_topology');
            if ~sectionValid
                warnings = [warnings, sectionErrors];
            end
            warnings = [warnings, sectionWarnings];
        end
        
        % Validate risk_distributions
        if isfield(analysis, 'risk_distributions') && isfield(enhancedSchemas, 'RiskDistributions')
            [sectionValid, sectionErrors, sectionWarnings] = validateEnhancedSection(...
                analysis.risk_distributions, enhancedSchemas.RiskDistributions, 'risk_distributions');
            if ~sectionValid
                warnings = [warnings, sectionErrors];
            end
            warnings = [warnings, sectionWarnings];
        end
        
        % Validate monte_carlo_parameters
        if isfield(analysis, 'monte_carlo_parameters') && isfield(enhancedSchemas, 'MonteCarloParameters')
            [sectionValid, sectionErrors, sectionWarnings] = validateEnhancedSection(...
                analysis.monte_carlo_parameters, enhancedSchemas.MonteCarloParameters, 'monte_carlo_parameters');
            if ~sectionValid
                warnings = [warnings, sectionErrors];
            end
            warnings = [warnings, sectionWarnings];
        end
        
        % Validate graph_statistics
        if isfield(analysis, 'graph_statistics') && isfield(enhancedSchemas, 'GraphStatistics')
            [sectionValid, sectionErrors, sectionWarnings] = validateEnhancedSection(...
                analysis.graph_statistics, enhancedSchemas.GraphStatistics, 'graph_statistics');
            if ~sectionValid
                warnings = [warnings, sectionErrors];
            end
            warnings = [warnings, sectionWarnings];
        end
    end
end

function [isValid, errors, warnings] = validateEnhancedSection(data, schema, sectionName)
    % VALIDATEENHANCEDSECTION Validate an enhanced section against its schema
    %
    % Args:
    %   data - Data structure to validate
    %   schema - JSON schema for the section
    %   sectionName - Name of the section (for error messages)
    %
    % Returns:
    %   isValid - Boolean indicating if structure is valid
    %   errors - Cell array of error messages
    %   warnings - Cell array of warning messages
    
    isValid = true;
    errors = {};
    warnings = {};
    
    if isempty(schema) || ~isstruct(schema)
        return; % Can't validate without schema
    end
    
    % Basic structure validation
    if ~isstruct(data)
        errors{end+1} = sprintf('%s should be a struct', sectionName);
        isValid = false;
        return;
    end
    
    % Check required fields if schema has them
    if isfield(schema, 'required') && iscell(schema.required)
        requiredFields = schema.required;
        for i = 1:length(requiredFields)
            fieldName = requiredFields{i};
            if ~isfield(data, fieldName)
                warnings{end+1} = sprintf('%s missing required field: %s', sectionName, fieldName);
            end
        end
    end
    
    % Check properties if schema has them
    if isfield(schema, 'properties') && isstruct(schema.properties)
        props = schema.properties;
        propNames = fieldnames(props);
        dataFields = fieldnames(data);
        
        % Warn about unexpected fields
        for i = 1:length(dataFields)
            fieldName = dataFields{i};
            if ~any(strcmp(fieldName, propNames))
                warnings{end+1} = sprintf('%s has unexpected field: %s', sectionName, fieldName);
            end
        end
    end
end


