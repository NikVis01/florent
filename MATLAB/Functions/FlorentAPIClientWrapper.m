classdef FlorentAPIClientWrapper < handle
    % FLORENTAPICLIENTWRAPPER API client wrapper for Florent Python API
    %
    % This class provides a convenient interface to the Florent Python API.
    % It automatically uses manual HTTP calls (webread/webwrite) and optionally
    % uses a generated OpenAPI client if available. It handles error responses,
    % timeouts, retries, and data transformation.
    %
    % Usage:
    %   client = FlorentAPIClientWrapper()
    %   client = FlorentAPIClientWrapper('http://localhost:8000')
    %   client = FlorentAPIClientWrapper(config)
    %
    % Methods:
    %   healthCheck() - Check API health
    %   analyzeProject(projectId, firmId, budget) - Run analysis
    %   analyzeProjectWithData(firmData, projectData, budget) - Run with inline data
    
    properties (Access = private)
        BaseUrl char
        Timeout double
        RetryAttempts double
        RetryDelay double
        GeneratedClient % The generated OpenAPI client
    end
    
    methods
        function obj = FlorentAPIClientWrapper(baseUrlOrConfig, varargin)
            % Constructor
            %
            % Arguments:
            %   baseUrlOrConfig - Base URL string or config structure
            %   varargin - Optional name-value pairs for configuration
            
            % Parse arguments
            if nargin == 0
                % Use defaults
                obj.BaseUrl = 'http://localhost:8000';
                obj.Timeout = 120; % Long timeout for analysis
                obj.RetryAttempts = 3;
                obj.RetryDelay = 2;
            elseif isstruct(baseUrlOrConfig)
                % Config structure provided
                config = baseUrlOrConfig;
                obj.BaseUrl = config.api.baseUrl;
                obj.Timeout = config.api.timeout;
                obj.RetryAttempts = config.api.retryAttempts;
                obj.RetryDelay = config.api.retryDelay;
            else
                % Base URL string provided
                obj.BaseUrl = baseUrlOrConfig;
                obj.Timeout = 120;
                obj.RetryAttempts = 3;
                obj.RetryDelay = 2;
            end
            
            % Override with varargin if provided
            p = inputParser;
            addParameter(p, 'Timeout', obj.Timeout, @isnumeric);
            addParameter(p, 'RetryAttempts', obj.RetryAttempts, @isnumeric);
            addParameter(p, 'RetryDelay', obj.RetryDelay, @isnumeric);
            parse(p, varargin{:});
            
            obj.Timeout = p.Results.Timeout;
            obj.RetryAttempts = p.Results.RetryAttempts;
            obj.RetryDelay = p.Results.RetryDelay;
            
            % Initialize generated client if available
            obj.initializeGeneratedClient();
        end
        
        function result = healthCheck(obj)
            % HEALTHCHECK Check API health status
            %
            % Returns:
            %   result - Health check response string
            
            try
                if ~isempty(obj.GeneratedClient)
                    result = obj.GeneratedClient.HealthCheck();
                else
                    % Fallback to manual HTTP call
                    endpoint = sprintf('%s/', obj.BaseUrl);
                    options = weboptions('Timeout', obj.Timeout, 'MediaType', 'application/json');
                    result = webread(endpoint, options);
                end
            catch ME
                error('Health check failed: %s', ME.message);
            end
        end
        
        function data = analyzeProject(obj, projectId, firmId, budget)
            % ANALYZEPROJECT Run analysis using project and firm IDs
            %
            % Arguments:
            %   projectId - Project identifier (e.g., 'proj_001')
            %   firmId    - Firm identifier (e.g., 'firm_001')
            %   budget    - Analysis budget (default: 100)
            %
            % Returns:
            %   data - Transformed analysis data structure
            
            if nargin < 4
                budget = 100;
            end
            
            % Build request
            request = buildAnalysisRequest(projectId, firmId, budget);
            
            % Call API
            response = obj.callAnalyzeEndpoint(request);
            
            % Transform response
            data = parseAnalysisResponse(response, projectId, firmId);
        end
        
        function data = analyzeProjectWithData(obj, firmData, projectData, budget)
            % ANALYZEPROJECTWITHDATA Run analysis with inline data
            %
            % Arguments:
            %   firmData    - Firm data structure or JSON string
            %   projectData - Project data structure or JSON string
            %   budget      - Analysis budget (default: 100)
            %
            % Returns:
            %   data - Transformed analysis data structure
            
            if nargin < 4
                budget = 100;
            end
            
            % Build request with inline data
            request = struct();
            if ischar(firmData) || isstring(firmData)
                % JSON string - parse it
                firmData = jsondecode(firmData);
            end
            if ischar(projectData) || isstring(projectData)
                % JSON string - parse it
                projectData = jsondecode(projectData);
            end
            
            request.firm_data = firmData;
            request.project_data = projectData;
            request.budget = budget;
            
            % Call API
            response = obj.callAnalyzeEndpoint(request);
            
            % Extract IDs from data
            projectId = projectData.id;
            firmId = firmData.id;
            
            % Transform response
            data = parseAnalysisResponse(response, projectId, firmId);
        end
        
        function response = callAnalyzeEndpoint(obj, request)
            % CALLANALYZEENDPOINT Call the /analyze endpoint with retry logic
            %
            % Arguments:
            %   request - Analysis request structure
            %
            % Returns:
            %   response - API response structure
            
            lastError = [];
            
            for attempt = 1:obj.RetryAttempts
                try
                    if ~isempty(obj.GeneratedClient)
                        % Use generated client
                        response = obj.GeneratedClient.AnalyzeAnalyzeProject(request);
                    else
                        % Fallback to manual HTTP call
                        endpoint = sprintf('%s/analyze', obj.BaseUrl);
                        options = weboptions(...
                            'Timeout', obj.Timeout, ...
                            'MediaType', 'application/json', ...
                            'RequestMethod', 'post');
                        response = webwrite(endpoint, request, options);
                    end
                    
                    % Validate response structure
                    [isValid, errors, warnings] = validateAnalysisResponse(response);
                    if ~isValid
                        errorMsg = strjoin(errors, '; ');
                        error('Invalid API response: %s', errorMsg);
                    end
                    
                    % Check for error status in response
                    if isfield(response, 'status') && strcmp(response.status, 'error')
                        errorMsg = 'API returned error';
                        if isfield(response, 'message')
                            errorMsg = sprintf('%s: %s', errorMsg, response.message);
                        end
                        error(errorMsg);
                    end
                    
                    % Log warnings if any
                    if ~isempty(warnings)
                        for w = 1:length(warnings)
                            warning('API response warning: %s', warnings{w});
                        end
                    end
                    
                    % Success
                    return;
                    
                catch ME
                    lastError = ME;
                    
                    % Check if it's a retryable error
                    if attempt < obj.RetryAttempts
                        % Check error type
                        errorMsg = ME.message;
                        if contains(errorMsg, 'timeout', 'IgnoreCase', true) || ...
                           contains(errorMsg, 'network', 'IgnoreCase', true) || ...
                           contains(errorMsg, 'connection', 'IgnoreCase', true)
                            % Retryable error
                            fprintf('Attempt %d failed: %s. Retrying in %d seconds...\n', ...
                                attempt, errorMsg, obj.RetryDelay);
                            pause(obj.RetryDelay);
                            continue;
                        else
                            % Non-retryable error
                            break;
                        end
                    end
                end
            end
            
            % All retries failed
            if ~isempty(lastError)
                error('API call failed after %d attempts: %s', ...
                    obj.RetryAttempts, lastError.message);
            else
                error('API call failed: Unknown error');
            end
        end
    end
    
    methods (Access = private)
        function initializeGeneratedClient(obj)
            % Initialize the generated OpenAPI client if available
            % If not available, automatically falls back to manual HTTP calls (webread/webwrite)
            
            % Check if generated client exists
            if exist('FlorentAPIClient', 'class') == 8
                try
                    obj.GeneratedClient = FlorentAPIClient(obj.BaseUrl);
                catch ME
                    % Silently fall back to manual HTTP calls - no warning needed
                    obj.GeneratedClient = [];
                end
            else
                % Generated client not found - use manual HTTP calls (webread/webwrite)
                % This is the normal mode when REST API Client Generator is not installed
                obj.GeneratedClient = [];
            end
        end
    end
end

