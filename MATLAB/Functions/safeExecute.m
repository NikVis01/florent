function [result, success, errorMsg] = safeExecute(func, varargin)
    % SAFEEXECUTE Safely executes a function with error handling
    %
    % Usage:
    %   [result, success, error] = safeExecute(@myFunction, arg1, arg2, ...)
    %
    % Inputs:
    %   func - Function handle to execute
    %   varargin - Arguments to pass to function
    %
    % Output:
    %   result - Function result (empty if failed)
    %   success - True if execution succeeded
    %   errorMsg - Error message if failed
    
    result = [];
    success = false;
    errorMsg = '';
    
    if ~isa(func, 'function_handle')
        errorMsg = 'First argument must be a function handle';
        return;
    end
    
    try
        % Execute function
        if nargin > 1
            result = func(varargin{:});
        else
            result = func();
        end
        success = true;
    catch ME
        errorMsg = ME.message;
        if isempty(errorMsg)
            errorMsg = 'Unknown error occurred';
        end
        
        % Log error
        fprintf('Error in safeExecute: %s\n', errorMsg);
        fprintf('  Function: %s\n', func2str(func));
        if ~isempty(ME.stack)
            fprintf('  Location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
        end
    end
end

