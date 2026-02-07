# Florent MATLAB Setup Guide

This guide will help you set up the Florent MATLAB codebase for use.

## Quick Start

1. **Initialize Paths**
   ```matlab
   initializeFlorent()
   ```

2. **Verify Setup**
   ```matlab
   quickHealthCheck()
   ```

3. **Run Demo**
   ```matlab
   runFlorentDemo()
   ```

## Detailed Setup

### Step 1: Path Initialization

The Florent codebase requires several directories to be on the MATLAB path:

- `MATLAB/Functions/` - Core function files
- `MATLAB/Scripts/` - Analysis scripts
- `MATLAB/Config/` - Configuration files

**Automatic Setup:**
```matlab
% Add paths for current session
initializeFlorent()

% Add paths and save for future sessions
initializeFlorent(true)
```

**Manual Setup:**
If automatic setup fails, manually add paths:
```matlab
% Replace 'path/to/florent' with your actual path
basePath = 'path/to/florent/MATLAB';
addpath(genpath(fullfile(basePath, 'Functions')))
addpath(genpath(fullfile(basePath, 'Scripts')))
addpath(genpath(fullfile(basePath, 'Config')))
```

**Note:** `genpath` recursively adds all subdirectories. If you prefer to add only specific directories, use `addpath()` without `genpath()`.

### Step 2: Verify Installation

Run the quick health check:
```matlab
quickHealthCheck()
```

This verifies:
- Critical functions are accessible
- Paths are configured correctly
- System is ready for use

### Step 3: Run Comprehensive Verification (Optional)

For a full verification of the codebase:
```matlab
report = verifyFlorentCodebase()
```

This checks:
- All functions are discoverable
- Dependencies are resolved
- Function signatures are correct
- File organization is proper

## Troubleshooting

### "Function not found" Errors

**Solution:** Run `initializeFlorent()` to add paths.

### Path Not Persisting

**Solution:** 
1. Run `initializeFlorent(true)` to save paths
2. If that fails, you may need administrator privileges
3. Alternatively, add to your `startup.m` file:
   ```matlab
   % In your startup.m (located in userpath or MATLAB startup directory)
   % Replace 'path/to/florent' with your actual path
   cd('path/to/florent/MATLAB')
   initializeFlorent(false)  % false = don't save path (already in startup)
   ```
   
   To find your `startup.m` location:
   ```matlab
   userpath  % Shows user path directory
   ```

### Case Sensitivity Issues (Linux)

MATLAB is case-sensitive on Linux. Ensure:
- Function names match file names exactly
- Directory names match exactly

### Shadowing Warnings

If you see warnings about functions shadowing MATLAB built-ins:
- This is usually harmless
- If problematic, rename the conflicting function

## Directory Structure

```
MATLAB/
├── Functions/     # Core functions (automatically added to path)
├── Scripts/       # Analysis scripts (automatically added to path)
├── Config/        # Configuration files (automatically added to path)
├── Apps/          # App Designer frontend (optional, see Apps/README.md)
├── Data/          # Data files and cache
├── Figures/      # Generated visualizations
└── Reports/      # Generated reports
```

**Note:** The `Apps/` directory contains the App Designer frontend (`florentRiskApp.m`). This is optional and not required for command-line usage. See `Apps/README.md` for App Designer setup instructions.

## API Client Setup (Automatic - No Setup Required!)

The MATLAB frontend automatically uses manual HTTP calls (`webread`/`webwrite`) to communicate with the Python API. **No additional setup is required!**

### Using the API Client

The `FlorentAPIClientWrapper` class automatically handles all API communication:

```matlab
% Create client (uses manual HTTP calls automatically)
client = FlorentAPIClientWrapper('http://localhost:8000')

% Health check
health = client.healthCheck()

% Run analysis
data = client.analyzeProject('proj_001', 'firm_001', 100)
```

The wrapper provides:
- Automatic retry logic
- Error handling
- Response validation
- Data transformation

**Note:** The codebase works perfectly with manual HTTP calls. OpenAPI client generation is completely optional and only provides minor benefits (type safety, IntelliSense). You can skip it entirely.

## Next Steps

After setup:
1. Try the demo: `runFlorentDemo()`
2. Run full analysis: `runFlorentAnalysis()`
3. Launch the App Designer frontend (optional): `app = florentRiskApp`
4. Check documentation: See `README_FUNCTIONS.md` and `Apps/README.md`

**That's it!** The API client uses manual HTTP calls automatically - no additional setup needed.

## Getting Help

If you encounter issues:
1. Run `quickHealthCheck()` to diagnose
2. Run `verifyFlorentCodebase()` for detailed analysis
3. Check error messages for specific function names
4. Verify paths are set correctly: `path`
5. Check if function exists: `which functionName` (should return file path, not empty)

## Additional Resources

- **Function Reference**: `README_FUNCTIONS.md` - Complete function documentation
- **App Designer Setup**: `Apps/README.md` - Frontend application guide
- **App Designer Details**: `Apps/APP_DESIGNER_SETUP.md` - Detailed App Designer information

