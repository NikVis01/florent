function response = callPythonAPI(endpoint, method, payload)
    % CALLPYTHONAPI Sends a request to a Python REST API
    % 
    % Usage:
    %   resp = callPythonAPI('http://192.168.1.50:8000/data', 'GET')
    %   resp = callPythonAPI('http://192.168.1.50:8000/add', 'POST', struct('x', 10))

    % 1. Setup Options
    % We set a timeout (20s) and specify we are sending/receiving JSON
    options = weboptions(...
        'MediaType', 'application/json', ...
        'CharacterEncoding', 'UTF-8', ...
        'Timeout', 20);

    % 2. Execute Request based on Method
    try
        if strcmpi(method, 'POST')
            if nargin < 3
                error('POST method requires a payload (struct).');
            end
            response = webwrite(endpoint, payload, options);
        else
            % Default to GET
            response = webread(endpoint, options);
        end
        
        fprintf('Successfully connected to: %s\n', endpoint);

    catch ME
        % 3. Error Handling
        fprintf('Error: Failed to reach the API at %s\n', endpoint);
        fprintf('Reason: %s\n', ME.message);
        
        % Return empty or throw error depending on your preference
        response = []; 
    end
end