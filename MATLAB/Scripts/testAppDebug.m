% TESTAPPDEBUG Simple test to verify app loads and shows debug output
%
% Usage:
%   testAppDebug()

function testAppDebug()
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('TESTING APP DEBUG OUTPUT\n');
    fprintf('========================================\n\n');
    
    fprintf('Step 1: Testing basic fprintf output...\n');
    fprintf('[TEST] This should appear in the terminal\n');
    pause(0.5);
    
    fprintf('\nStep 2: Checking if app file exists...\n');
    appFile = which('florentRiskApp');
    if isempty(appFile)
        fprintf('[ERROR] florentRiskApp.m not found in path!\n');
        fprintf('Current directory: %s\n', pwd);
        fprintf('Please run: initializeFlorent()\n');
        return;
    else
        fprintf('[OK] Found app file: %s\n', appFile);
    end
    
    fprintf('\nStep 3: Attempting to instantiate app...\n');
    fprintf('This should trigger constructor debug output...\n\n');
    
    try
        app = florentRiskApp;
        fprintf('\n[OK] App created successfully!\n');
        fprintf('App handle: %s\n', class(app));
        
        % Keep app open for a moment
        fprintf('\nApp window should be visible now.\n');
        fprintf('Press any key to close the app...\n');
        pause(5);
        
        if isvalid(app.UIFigure)
            delete(app);
            fprintf('[OK] App closed\n');
        end
        
    catch ME
        fprintf('\n[ERROR] Failed to create app!\n');
        fprintf('Error message: %s\n', ME.message);
        fprintf('\nStack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s at line %d in %s\n', ...
                ME.stack(i).name, ME.stack(i).line, ME.stack(i).file);
        end
    end
    
    fprintf('\n========================================\n');
    fprintf('TEST COMPLETE\n');
    fprintf('========================================\n\n');
end

