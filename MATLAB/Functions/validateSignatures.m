function report = validateSignatures(registry, signatures)
    % VALIDATESIGNATURES Validate function signatures are consistent
    %
    % Usage:
    %   report = validateSignatures()
    %   report = validateSignatures(registry, signatures)
    %
    % Output:
    %   report - Structure with validation results
    
    if nargin < 1
        registry = discoverFunctions();
    end
    if nargin < 2
        signatures = extractSignatures(registry);
    end
    
    fprintf('\n=== Validating Function Signatures ===\n\n');
    
    report = struct();
    report.issues = {};
    report.missingNarginChecks = {};
    report.inconsistentDefaults = {};
    report.status = 'success';
    
    funcNames = keys(signatures);
    issueCount = 0;
    
    for i = 1:length(funcNames)
        funcName = funcNames{i};
        sig = signatures(funcName);
        
        fprintf('Validating: %s\n', funcName);
        
        % Check nargin consistency
        if sig.nargin > 0
            % Function has required arguments
            % Check if nargin checks are present and consistent
            if isempty(sig.narginChecks)
                % No nargin checks found - might be okay if all args required
                fprintf('  [INFO] No nargin checks found (all args may be required)\n');
            else
                % Verify nargin checks make sense
                minCheck = min(sig.narginChecks);
                if minCheck > sig.nargin
                    issueCount = issueCount + 1;
                    issue = struct();
                    issue.function = funcName;
                    issue.type = 'nargin_inconsistent';
                    issue.expected = sig.nargin;
                    issue.found = minCheck;
                    report.issues{end+1} = issue;
                    report.missingNarginChecks{end+1} = issue;
                    fprintf('  [WARNING] nargin check (%d) > declared inputs (%d)\n', ...
                        minCheck, sig.nargin);
                    report.status = 'warning';
                end
            end
        end
        
        % Check default values are consistent with nargin checks
        defaultNames = fieldnames(sig.defaults);
        for j = 1:length(defaultNames)
            defaultName = defaultNames{j};
            % Check if default name is in inputs
            if ~ismember(defaultName, sig.inputs)
                issueCount = issueCount + 1;
                issue = struct();
                issue.function = funcName;
                issue.type = 'default_not_in_inputs';
                issue.argument = defaultName;
                report.issues{end+1} = issue;
                report.inconsistentDefaults{end+1} = issue;
                fprintf('  [WARNING] Default for %s but not in input list\n', defaultName);
                report.status = 'warning';
            end
        end
        
        fprintf('  [OK] Signature validated\n');
    end
    
    fprintf('\n=== Signature Validation Summary ===\n');
    fprintf('Functions validated: %d\n', length(funcNames));
    fprintf('Issues found: %d\n', issueCount);
    fprintf('Missing nargin checks: %d\n', length(report.missingNarginChecks));
    fprintf('Inconsistent defaults: %d\n', length(report.inconsistentDefaults));
    
    if strcmp(report.status, 'success')
        fprintf('\n[SUCCESS] All signatures are consistent!\n');
    else
        fprintf('\n[WARNING] Some signature issues found.\n');
    end
    
    fprintf('\n');
end

