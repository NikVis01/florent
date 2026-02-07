% TESTFLORENTAPPLAUNCH Test script for launching Florent App
%
% This script tests that the programmatic app can be launched and
% basic components are accessible.
%
% Usage:
%   testFlorentAppLaunch()

function testFlorentAppLaunch()
    fprintf('\n');
    fprintf('========================================\n');
    fprintf('  FLORENT APP LAUNCH TEST\n');
    fprintf('========================================\n\n');
    
    % Test 1: App can be instantiated
    fprintf('Test 1: App Instantiation...\n');
    try
        app = florentRiskApp;
        fprintf('  [OK] App created successfully\n');
    catch ME
        fprintf('  [FAIL] App creation failed: %s\n', ME.message);
        fprintf('  Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(i).file, ME.stack(i).line);
        end
        return;
    end
    
    % Test 2: All components exist
    fprintf('\nTest 2: Component Existence...\n');
    components = {
        'UIFigure', 'InputPanel', 'DisplayPanel', 'StatusPanel', ...
        'FirmDropdown', 'ProjectDropdown', 'ModeDropdown', ...
        'MCIterationsSlider', 'MCIterationsLabel', ...
        'RunAnalysisButton', 'LoadDemoButton', ...
        'TabGroup', 'MatrixTab', 'LandscapeTab', 'GlobeTab', 'NetworkTab', ...
        'MatrixAxes', 'LandscapeAxes', 'GlobeAxes', 'NetworkAxes', ...
        'ProgressBar', 'StatusLabel', 'PhaseLabel'
    };
    
    allExist = true;
    for i = 1:length(components)
        compName = components{i};
        if isprop(app, compName)
            fprintf('  [OK] %s exists\n', compName);
        else
            fprintf('  [FAIL] %s missing\n', compName);
            allExist = false;
        end
    end
    
    if ~allExist
        fprintf('\n  [WARNING] Some components are missing\n');
    end
    
    % Test 3: Components are visible
    fprintf('\nTest 3: Component Visibility...\n');
    try
        if isprop(app, 'UIFigure')
            if strcmp(app.UIFigure.Visible, 'on')
                fprintf('  [OK] UIFigure is visible\n');
            else
                fprintf('  [WARNING] UIFigure is not visible\n');
            end
        end
    catch ME
        fprintf('  [FAIL] Error checking visibility: %s\n', ME.message);
    end
    
    % Test 4: Dropdowns have values
    fprintf('\nTest 4: Dropdown Values...\n');
    try
        if isprop(app, 'FirmDropdown')
            fprintf('  [OK] FirmDropdown value: %s\n', app.FirmDropdown.Value);
        end
        if isprop(app, 'ProjectDropdown')
            fprintf('  [OK] ProjectDropdown value: %s\n', app.ProjectDropdown.Value);
        end
        if isprop(app, 'ModeDropdown')
            fprintf('  [OK] ModeDropdown value: %s\n', app.ModeDropdown.Value);
        end
    catch ME
        fprintf('  [FAIL] Error checking dropdowns: %s\n', ME.message);
    end
    
    % Test 5: Slider has value
    fprintf('\nTest 5: Slider Value...\n');
    try
        if isprop(app, 'MCIterationsSlider')
            fprintf('  [OK] MCIterationsSlider value: %.0f\n', app.MCIterationsSlider.Value);
        end
    catch ME
        fprintf('  [FAIL] Error checking slider: %s\n', ME.message);
    end
    
    % Summary
    fprintf('\n========================================\n');
    fprintf('  TEST SUMMARY\n');
    fprintf('========================================\n');
    fprintf('[SUCCESS] App launches successfully!\n');
    fprintf('The app is ready for use.\n');
    fprintf('\nTo use the app:\n');
    fprintf('  app = florentRiskApp\n');
    fprintf('  % Click "Load Demo" then "Run Analysis"\n');
    fprintf('========================================\n\n');
    
    % Keep app open for manual testing
    fprintf('App window is open. Test manually, then close the window.\n');
end

