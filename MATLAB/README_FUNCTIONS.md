# Florent MATLAB Functions Reference

## Overview

This document describes the function organization and callability in the Florent MATLAB codebase.

## Function Organization

### Public Functions (Called from Multiple Files)

These functions are in `Functions/` and can be called from anywhere:

**Configuration:**
- `loadFlorentConfig()` - Load configuration
- `florentConfig()` - Get configuration structure

**Data Access:**
- `getRiskData()` - Load risk analysis data
- `callPythonAPI()` - Call Python API

**Risk Calculations:**
- `calculate_influence_score()` - Calculate influence score
- `calculate_topological_risk()` - Calculate cascading risk
- `calculate_weighted_alignment()` - Calculate alignment score
- `sigmoid()` - Sigmoid function

**Classification:**
- `classifyQuadrant()` - Classify node into 2x2 matrix
- `getActionFromQuadrant()` - Get action for quadrant

**Graph Utilities:**
- `buildAdjacencyMatrix()` - Build adjacency matrix
- `calculateEigenvectorCentrality()` - Calculate centrality
- `topologicalSort()` - Topological sort
- `getParentNodes()` - Get parent nodes
- `getChildNodes()` - Get child nodes
- `findAllPaths()` - Find all paths in graph

**Validation:**
- `validateData()` - Validate data structure
- `safeExecute()` - Safe function execution wrapper

**Visualization:**
- `plot2x2MatrixWithEllipses()` - 2x2 matrix plot
- `plot3DRiskLandscape()` - 3D landscape plot
- `plotStabilityNetwork()` - Stability network plot
- `displayGlobe()` - Globe visualization
- `drawGlobePath()` - Draw paths on globe
- All other `plot*` functions

### Script Functions (Entry Points)

These are in `Scripts/` and are meant to be run directly:

- `runFlorentAnalysis()` - Main entry point
- `runFlorentDemo()` - Quick demo
- `runAllMCSimulations()` - Run all MC simulations
- `createRiskDashboard()` - Create dashboard
- `testFlorentPipeline()` - Test suite
- `testEndToEnd()` - End-to-end test
- `verifyFlorentCodebase()` - Comprehensive verification
- `quickHealthCheck()` - Quick verification

### Local Functions

Some files contain local functions (not callable from other files):
- Functions after the first `function` declaration in a file
- These are only accessible within the same file

## Dependency Relationships

### Critical Path

```
initializeFlorent()
  └─> loadFlorentConfig()
      └─> florentConfig()

runFlorentAnalysis()
  └─> runAnalysisPipeline()
      ├─> loadAnalysisData()
      │   └─> getRiskData()
      │       └─> callPythonAPI()
      ├─> runMCSimulations()
      │   ├─> mc_parameterSensitivity()
      │   ├─> mc_crossEncoderUncertainty()
      │   ├─> mc_topologyStress()
      │   └─> mc_failureProbDist()
      │       └─> monteCarloFramework()
      ├─> aggregateResults()
      │   └─> calculateStabilityScores()
      ├─> generateVisualizations()
      │   └─> [all plot functions]
      └─> createDashboard()
```

### Visualization Dependencies

All visualization functions depend on:
- `classifyQuadrant()` - For quadrant classification
- `getActionFromQuadrant()` - For action labels
- `calculateEigenvectorCentrality()` - For centrality calculations

## Function Callability

### How to Verify Functions Are Callable

1. **Quick Check:**
   ```matlab
   which functionName
   ```
   Should return the file path, not empty.

2. **Health Check:**
   ```matlab
   quickHealthCheck()
   ```

3. **Comprehensive Check:**
   ```matlab
   verifyFlorentCodebase()
   ```

### Common Issues

**Function Not Found:**
- Run `initializeFlorent()` to add paths
- Check function name spelling (case-sensitive on Linux)
- Verify function is in correct directory

**Local Function Called Externally:**
- Move function to separate file in `Functions/`
- Or make it the first function in its file

**Shadowing:**
- Custom function has same name as MATLAB built-in
- Usually harmless, but can cause confusion
- Consider renaming if problematic

## Usage Examples

### Basic Usage

```matlab
% Initialize
initializeFlorent()

% Load data
data = getRiskData()

% Classify nodes
quadrants = classifyQuadrant(data.riskScores.risk, data.riskScores.influence)

% Run analysis
results = runFlorentAnalysis()
```

### Advanced Usage

```matlab
% Custom configuration
customConfig = struct();
customConfig.monteCarlo.nIterations = 5000;
config = loadFlorentConfig('production', customConfig);

% Run with custom config
results = runFlorentAnalysis('proj_001', 'firm_001', 'production', customConfig);
```

## Function Categories

### Core Functions (No Dependencies)
- `sigmoid()` - Pure function
- `getActionFromQuadrant()` - Simple lookup

### Data Functions
- `getRiskData()` - Data loading
- `loadGeographicData()` - Geographic data
- `validateData()` - Data validation

### Calculation Functions
- `calculate_influence_score()` - Risk calculations
- `calculate_topological_risk()` - Risk calculations
- `calculateStabilityScores()` - Aggregation

### Utility Functions
- `safeExecute()` - Error handling
- `cacheManager()` - Caching
- `verifyPaths()` - Path verification

### Visualization Functions
- All `plot*` functions
- `displayGlobe()` - Globe visualization
- `animateCascadingFailure()` - Animation

## Maintenance

### Adding New Functions

1. Place in appropriate directory:
   - `Functions/` if called from multiple files
   - `Scripts/` if it's an entry point script

2. Ensure function name matches file name

3. Run verification:
   ```matlab
   verifyFlorentCodebase()
   ```

### Modifying Functions

1. Check dependencies before modifying
2. Run tests after changes
3. Update documentation if signature changes

## See Also

- `SETUP.md` - Setup instructions
- `DEPENDENCIES.md` - Auto-generated dependency graph
- Function help: `help functionName`

