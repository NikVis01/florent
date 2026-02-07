# App Designer Setup Instructions

Since App Designer files (.mlapp) are binary and must be created in the MATLAB App Designer GUI, follow these instructions to create the app.

## Quick Start

1. **Open App Designer in MATLAB:**
   ```matlab
   appdesigner
   ```

2. **Create New App:**
   - Click "New App" → "Blank App"
   - Save as `florentRiskApp.mlapp` in `MATLAB/Apps/`

3. **Use the Template:**
   - Reference `florentRiskApp_Template.m` for component structure
   - Follow component specifications below
   - Use provided callbacks

## Component Specifications

### Layout Structure

```
UIFigure (1400x900)
├── InputPanel (400x880, left side)
│   ├── FirmDropdown
│   ├── ProjectDropdown
│   ├── ModeDropdown
│   ├── MCIterationsSlider
│   ├── MCIterationsLabel
│   ├── RunAnalysisButton
│   └── LoadDemoButton
├── DisplayPanel (970x880, right side)
│   └── TabGroup
│       ├── MatrixTab → MatrixAxes
│       ├── LandscapeTab → LandscapeAxes
│       ├── GlobeTab → GlobeAxes
│       └── NetworkTab → NetworkAxes
└── StatusPanel (1380x100, bottom)
    ├── ProgressBar
    └── StatusLabel
```

### Component Properties

#### Input Panel Components

**FirmDropdown:**
- Type: DropDown
- Items: {'firm_001', 'firm_002'} (or load dynamically)
- Value: 'firm_001'
- Position: [20, 800, 360, 30]
- Label: 'Firm:'

**ProjectDropdown:**
- Type: DropDown
- Items: {'proj_001', 'proj_002'}
- Value: 'proj_001'
- Position: [20, 750, 360, 30]
- Label: 'Project:'

**ModeDropdown:**
- Type: DropDown
- Items: {'test', 'interactive', 'production'}
- Value: 'interactive'
- Position: [20, 700, 360, 30]
- Label: 'Mode:'

**MCIterationsSlider:**
- Type: Slider
- Limits: [100, 10000]
- Value: 1000
- Position: [20, 650, 360, 3]
- Callback: `MCIterationsSliderValueChanged`

**MCIterationsLabel:**
- Type: Label
- Text: 'MC Iterations: 1000'
- Position: [20, 630, 360, 22]

**RunAnalysisButton:**
- Type: Button
- Text: 'Run Analysis'
- Position: [20, 550, 360, 40]
- FontSize: 14, FontWeight: 'bold'
- Callback: `RunAnalysisButtonPushed`

**LoadDemoButton:**
- Type: Button
- Text: 'Load Demo'
- Position: [20, 500, 360, 40]
- Callback: `LoadDemoButtonPushed`

#### Display Panel Components

**TabGroup:**
- Type: TabGroup
- Position: [10, 50, 950, 820]
- Tabs: Matrix, Landscape, Globe, Network
- Callback: `TabGroupSelectionChanged`

**MatrixAxes (in MatrixTab):**
- Type: UIAxes
- Position: [10, 10, 930, 780]

**LandscapeAxes (in LandscapeTab):**
- Type: UIAxes
- Position: [10, 10, 930, 780]

**GlobeAxes (in GlobeTab):**
- Type: UIAxes
- Position: [10, 10, 930, 780]

**NetworkAxes (in NetworkTab):**
- Type: UIAxes
- Position: [10, 10, 930, 780]

#### Status Panel Components

**ProgressBar:**
- Type: LinearGauge
- Position: [20, 50, 500, 30]
- Limits: [0, 100]
- Value: 0

**StatusLabel:**
- Type: Label
- Text: 'Ready'
- Position: [540, 50, 800, 30]
- FontSize: 12

## Callback Functions

### StartupFcn
```matlab
function startupFcn(app)
    % Initialize paths
    initializeFlorent(false);
    
    % Load configuration
    mode = app.ModeDropdown.Value;
    app.Config = loadFlorentConfig(mode);
    
    % Update UI
    app.MCIterationsSlider.Value = app.Config.monteCarlo.nIterations;
    app.MCIterationsLabel.Text = sprintf('MC Iterations: %d', app.Config.monteCarlo.nIterations);
    
    app.StatusLabel.Text = 'Ready - Select parameters and click Run Analysis';
end
```

### RunAnalysisButtonPushed
```matlab
function RunAnalysisButtonPushed(app, event)
    app.IsRunning = true;
    app.RunAnalysisButton.Enable = 'off';
    
    projectId = app.ProjectDropdown.Value;
    firmId = app.FirmDropdown.Value;
    mode = app.ModeDropdown.Value;
    app.Config.monteCarlo.nIterations = round(app.MCIterationsSlider.Value);
    
    try
        results = appIntegration('runAnalysis', app, projectId, firmId, mode, app.Config);
        app.Data = results.data;
        app.StabilityData = results.stabilityData;
        app.MCResults = results.mcResults;
        
        appIntegration('displayResults', app, results);
        updateCurrentVisualization(app);
    catch ME
        app.StatusLabel.Text = sprintf('Error: %s', ME.message);
        uialert(app.UIFigure, ME.message, 'Analysis Error');
    end
    
    app.IsRunning = false;
    app.RunAnalysisButton.Enable = 'on';
end
```

### LoadDemoButtonPushed
```matlab
function LoadDemoButtonPushed(app, event)
    app.FirmDropdown.Value = 'firm_001';
    app.ProjectDropdown.Value = 'proj_001';
    app.ModeDropdown.Value = 'test';
    app.MCIterationsSlider.Value = 100;
    app.MCIterationsLabel.Text = 'MC Iterations: 100';
    app.StatusLabel.Text = 'Demo parameters loaded';
end
```

### MCIterationsSliderValueChanged
```matlab
function MCIterationsSliderValueChanged(app, event)
    value = round(app.MCIterationsSlider.Value);
    app.MCIterationsLabel.Text = sprintf('MC Iterations: %d', value);
end
```

### TabGroupSelectionChanged
```matlab
function TabGroupSelectionChanged(app, event)
    if ~isempty(app.StabilityData)
        updateCurrentVisualization(app);
    end
end
```

### Helper: updateCurrentVisualization
```matlab
function updateCurrentVisualization(app)
    if isempty(app.StabilityData) || isempty(app.Data)
        return;
    end
    
    selectedTab = app.TabGroup.SelectedTab;
    
    if selectedTab == app.MatrixTab
        appIntegration('updateVisualization', app, '2x2matrix', app.Data, app.StabilityData);
    elseif selectedTab == app.LandscapeTab
        appIntegration('updateVisualization', app, '3dlandscape', app.Data, app.StabilityData);
    elseif selectedTab == app.GlobeTab
        appIntegration('updateVisualization', app, 'globe', app.Data, app.StabilityData);
    elseif selectedTab == app.NetworkTab
        appIntegration('updateVisualization', app, 'stabilitynetwork', app.Data, app.StabilityData);
    end
end
```

## App Properties

Add these private properties in App Designer:
- `Data` - Analysis data structure
- `StabilityData` - Stability results
- `MCResults` - MC simulation results
- `Config` - Configuration structure
- `IsRunning` - Boolean flag for analysis state
- `CurrentTab` - Current tab index

## Testing the App

1. **Launch App:**
   ```matlab
   app = florentRiskApp
   ```

2. **Test Basic Flow:**
   - Click "Load Demo"
   - Click "Run Analysis"
   - Verify visualizations appear
   - Switch tabs
   - Check status updates

3. **Test Error Handling:**
   - Disconnect API (if applicable)
   - Verify graceful fallback
   - Check error messages

## Next Steps

After creating the basic app:
1. Add more tabs (Dashboard, Parameters)
2. Add export buttons
3. Add results table
4. Add parameter controls
5. Polish styling
6. Add help system

See the full plan for Phase 2-6 enhancements.

