# Florent App Designer Frontend

This directory contains the MATLAB App Designer frontend for the Florent risk analysis system.

## Files

- `florentRiskApp.m` - **Main programmatic app** (fully functional, Git-friendly!)
- `florentRiskApp_Template.m` - Original template (reference/backup)
- `APP_DESIGNER_SETUP.md` - Setup instructions (for reference)
- `README.md` - This file

## Quick Start

### Launch the App

The app is fully programmatic - no `.mlapp` binary file needed!

```matlab
% Initialize paths (if not already done)
initializeFlorent()

% Launch the app
app = florentRiskApp
```

That's it! The app window will open and you can start using it.

### Using the App

1. **Load Demo**: Click "Load Demo" to set quick demo parameters
2. **Run Analysis**: Click "Run Analysis" to start the analysis
3. **View Results**: Switch between tabs to see different visualizations:
   - **2x2 Matrix**: Risk-Influence matrix with confidence ellipses
   - **3D Landscape**: 3D visualization of risk, influence, and centrality
   - **Globe**: Geographic visualization of risk
   - **Stability Network**: Network graph showing stability scores

### Testing

Run the launch test:
```matlab
testFlorentAppLaunch()
```

## Features

### ✅ Implemented (MVP)
- ✅ Fully programmatic app (no .mlapp binary needed!)
- ✅ Input panel with firm/project/mode dropdowns
- ✅ MC iterations slider with live updates
- ✅ Tabbed interface with 4 visualization types
- ✅ Progress bar and status updates
- ✅ Demo mode (one-click demo setup)
- ✅ Full integration with analysis pipeline
- ✅ Error handling with user-friendly messages

### 🚀 Ready to Add (Optional Enhancements)
- Export buttons for figures and reports
- Results table showing node summary
- Findings text area with key insights
- Parameter checkboxes for MC simulation types
- Help system with tooltips

## Integration Functions

The app uses these integration functions (in `MATLAB/Functions/`):

- `appIntegration.m` - Main bridge between app and pipeline
- `updateAppProgress.m` - Progress update utilities
- `appExportFunctions.m` - Export capabilities
- `runAnalysisAsync.m` - Async analysis execution

## Architecture

The app integrates with the existing Florent pipeline:

```
App UI → runAnalysisAsync → appIntegration → runAnalysisPipeline → [pipeline functions]
```

All existing functions work with the app through the integration layer.

## Advantages of Programmatic Approach

1. **Git-friendly**: Single `.m` file, no binary merge conflicts
2. **Fast iteration**: Edit code, run, test - no GUI clicking
3. **Version control**: Easy to review diffs and track changes
4. **Debugging**: Set breakpoints, inspect variables easily
5. **Portable**: Share one file instead of binary

## Troubleshooting

### App won't launch
- Run `initializeFlorent()` first to set up paths
- Check that all integration functions exist
- Verify MATLAB version supports App Designer

### Visualizations don't appear
- Make sure analysis completed successfully
- Check that data exists: `app.Data` and `app.StabilityData`
- Try switching tabs to trigger visualization update

### Analysis fails
- Check error message in status label
- Verify Python API is running (if using API)
- Try demo mode first (uses cached/mock data)

## Support

See:
- `../README_FUNCTIONS.md` - Function reference
- `../SETUP.md` - General setup
- `APP_DESIGNER_SETUP.md` - Original setup guide (for reference)

