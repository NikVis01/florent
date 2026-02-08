function main()
    % MAIN Main entry point for Florent risk analysis
    %
    % This function runs Florent risk analysis and visualizations using the
    % POC data files (firm.json and project.json) from src/data/poc.
    %
    % Usage:
    %   main()
    %
    % The function will:
    %   1. Find the JSON files in src/data/poc
    %   2. Call runFlorentVisualization to run analysis and create visualizations
    
    fprintf('\n=== Florent Risk Analysis Main ===\n\n');
    
    % Step 1: Find workspace root
    fprintf('[STEP 1] Locating workspace root...\n');
    matlabDir = fileparts(mfilename('fullpath'));
    workspaceRoot = fileparts(matlabDir);
    fprintf('  [OK] MATLAB directory: %s\n', matlabDir);
    fprintf('  [OK] Workspace root: %s\n', workspaceRoot);
    fprintf('\n');
    
    % Step 2: Construct file paths
    fprintf('[STEP 2] Constructing file paths...\n');
    firmPath = fullfile(workspaceRoot, 'src', 'data', 'poc', 'firm.json');
    projectPath = fullfile(workspaceRoot, 'src', 'data', 'poc', 'project.json');
    fprintf('  Firm path: %s\n', firmPath);
    fprintf('  Project path: %s\n', projectPath);
    fprintf('\n');
    
    % Step 3: Validate files exist
    fprintf('[STEP 3] Validating JSON files exist...\n');
    if ~isfile(firmPath)
        fprintf('  [ERROR] Firm JSON file not found: %s\n', firmPath);
        error('Firm JSON file not found: %s', firmPath);
    end
    fprintf('  [OK] Firm JSON file found\n');
    
    if ~isfile(projectPath)
        fprintf('  [ERROR] Project JSON file not found: %s\n', projectPath);
        error('Project JSON file not found: %s', projectPath);
    end
    fprintf('  [OK] Project JSON file found\n');
    fprintf('\n');
    
    % Step 4: Prepare relative paths
    fprintf('[STEP 4] Preparing relative paths for API...\n');
    firmPathRelative = 'src/data/poc/firm.json';
    projectPathRelative = 'src/data/poc/project.json';
    fprintf('  Firm (relative): %s\n', firmPathRelative);
    fprintf('  Project (relative): %s\n', projectPathRelative);
    fprintf('\n');
    
    % Step 5: Call visualization function
    fprintf('[STEP 5] Calling runFlorentVisualization...\n');
    fprintf('  This will:\n');
    fprintf('    - Initialize Florent paths\n');
    fprintf('    - Load configuration\n');
    fprintf('    - Call Python API for analysis\n');
    fprintf('    - Run Monte Carlo simulations\n');
    fprintf('    - Generate visualizations\n');
    fprintf('\n');
    
    try
        % Call runFlorentVisualization with the paths
        % It will handle initialization, API calls, analysis, and visualizations
        runFlorentVisualization(projectPathRelative, firmPathRelative);
        fprintf('\n[STEP 6] Main execution complete\n');
        fprintf('  [OK] All steps completed successfully\n');
    catch ME
        fprintf('\n[STEP 6] Main execution failed\n');
        fprintf('  [ERROR] %s\n', ME.message);
        fprintf('  Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
        end
        rethrow(ME);
    end
    
    fprintf('\n=== Main Complete ===\n\n');
end

