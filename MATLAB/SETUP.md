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
addpath(genpath('path/to/florent/MATLAB/Functions'))
addpath(genpath('path/to/florent/MATLAB/Scripts'))
addpath(genpath('path/to/florent/MATLAB/Config'))
```

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
   % In your startup.m
   run('path/to/florent/MATLAB/initializeFlorent.m')
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
├── Data/          # Data files and cache
├── Figures/      # Generated visualizations
└── Reports/      # Generated reports
```

## Next Steps

After setup:
1. Try the demo: `runFlorentDemo()`
2. Run full analysis: `runFlorentAnalysis()`
3. Check documentation: See `README_FUNCTIONS.md`

## Getting Help

If you encounter issues:
1. Run `quickHealthCheck()` to diagnose
2. Run `verifyFlorentCodebase()` for detailed analysis
3. Check error messages for specific function names
4. Verify paths are set correctly: `path`

