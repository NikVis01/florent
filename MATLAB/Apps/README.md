# Florent App Designer Frontend

This directory contains the MATLAB App Designer frontend for the Florent risk analysis system.

## Files

- `florentRiskApp_Template.m` - Programmatic template showing app structure
- `APP_DESIGNER_SETUP.md` - Detailed setup instructions for creating the .mlapp file
- `README.md` - This file

## Quick Start

### Option 1: Create App in App Designer (Recommended)

1. Open MATLAB App Designer:
   ```matlab
   appdesigner
   ```

2. Create new app:
   - Click "New App" → "Blank App"
   - Save as `florentRiskApp.mlapp` in this directory

3. Follow `APP_DESIGNER_SETUP.md` for component specifications

4. Use `florentRiskApp_Template.m` as reference for callbacks

### Option 2: Use Template Programmatically

The template file can be used as a starting point, but App Designer files (.mlapp) must be created in the GUI.

## Integration Functions

The app uses these integration functions (in `MATLAB/Functions/`):

- `appIntegration.m` - Main bridge between app and pipeline
- `updateAppProgress.m` - Progress update utilities
- `appExportFunctions.m` - Export capabilities
- `runAnalysisAsync.m` - Async analysis execution

## Features

### Phase 1 (MVP) - Completed
- Basic app structure
- Input panel with dropdowns
- Display panel with visualization
- Run analysis button
- Progress updates
- Integration with pipeline

### Phase 2 (Enhanced) - Ready to Implement
- Tabbed interface for multiple visualizations
- Parameter controls (sliders, checkboxes)
- Real-time updates
- Interactive visualization features

### Phase 3 (Advanced) - Ready to Implement
- Export capabilities
- Demo mode
- Results panel
- Parameter exploration

### Phase 4-6 (Polish) - Ready to Implement
- Background execution
- Loading states
- Error handling
- Help system
- Styling

## Testing

Run the test suite:
```matlab
testFlorentApp()
```

## Usage

Once the app is created:

1. Launch app:
   ```matlab
   app = florentRiskApp
   ```

2. Use the interface:
   - Select firm/project
   - Adjust parameters
   - Click "Run Analysis"
   - Explore visualizations

3. Export results:
   - Use export buttons (when implemented)
   - Or call `appExportFunctions()` directly

## Integration

The app integrates with the existing Florent pipeline:

```
App UI → appIntegration → runAnalysisPipeline → [pipeline functions]
```

All existing functions work with the app through the integration layer.

## Next Steps

1. Create the .mlapp file in App Designer (follow `APP_DESIGNER_SETUP.md`)
2. Test basic functionality
3. Add Phase 2 features (tabs, controls)
4. Add Phase 3 features (export, demo mode)
5. Polish and style

## Support

See:
- `APP_DESIGNER_SETUP.md` - Detailed setup guide
- `../README_FUNCTIONS.md` - Function reference
- `../SETUP.md` - General setup

