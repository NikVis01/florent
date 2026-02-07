# OpenAPI MATLAB Client Setup Guide

**⚠️ IMPORTANT: This guide is OPTIONAL!**

The Florent MATLAB codebase works perfectly with **manual HTTP calls** (using `webread`/`webwrite`). The `FlorentAPIClientWrapper` automatically uses manual HTTP calls when the generated client is not available.

**You can skip this entire guide** - the codebase works out of the box with manual API calls!

This guide is only for users who want to generate a type-safe OpenAPI client (provides minor benefits like IntelliSense).

---

## Quick Start (Recommended - No Setup Needed!)

```matlab
% Just use the wrapper - it works automatically!
client = FlorentAPIClientWrapper('http://localhost:8000')
data = client.analyzeProject('proj_001', 'firm_001', 100)
```

That's it! No OpenAPI client generation needed.

---

## Optional: Generate OpenAPI Client

If you want to generate a type-safe client (completely optional), you need:

1. **MATLAB R2020b or newer**
2. **Communications Toolbox OR MATLAB Web App Server** (one required)
3. **REST API Client Generator add-on** (install from MATLAB Add-On Explorer)
4. **Python backend running** (for testing)

## Verification

Before generating the client, verify your setup:

```matlab
% Run verification script
result = verifyRESTAPIClient()

% Check results
if result.available
    fprintf('Ready to generate client!\n');
else
    fprintf('Please install required toolbox\n');
end
```

## Generating the MATLAB Client

### Method 1: Using REST API Client Generator (Recommended)

1. **Open the REST API Client Generator**
   - In MATLAB, go to: `Apps` → `REST API Client Generator`
   - Or run: `restApiClient` in the command window

2. **Specify OpenAPI Source**
   - **Option A**: Use local file
     - Click "Browse" and select: `docs/openapi.json`
   - **Option B**: Use live endpoint (if server is running)
     - Enter URL: `http://localhost:8000/schema/openapi.json`

3. **Configure Client Settings**
   - **Output Folder**: `MATLAB/Classes/FlorentAPIClient/`
   - **Client Class Name**: `FlorentAPIClient`
   - **Base URL**: `http://localhost:8000` (or your server URL)

4. **Generate Client**
   - Click "Generate" button
   - Wait for generation to complete
   - The generated client will be in `MATLAB/Classes/FlorentAPIClient/`

### Method 2: Using Command Line (if available)

```matlab
% Set paths
openapiPath = fullfile(pwd, 'docs', 'openapi.json');
outputPath = fullfile(pwd, 'MATLAB', 'Classes', 'FlorentAPIClient');

% Generate client (syntax may vary by MATLAB version)
restApiClient(openapiPath, 'OutputFolder', outputPath, ...
              'ClassName', 'FlorentAPIClient', ...
              'BaseURL', 'http://localhost:8000');
```

## Generated Client Structure

After generation, you should have:

```
MATLAB/Classes/FlorentAPIClient/
├── FlorentAPIClient.m          % Main client class
├── +FlorentAPIClient/          % Package directory
│   ├── AnalyzeAnalyzeProject.m % Generated method for /analyze
│   └── HealthCheck.m           % Generated method for /
└── ... (other generated files)
```

## Using the Generated Client

### Basic Usage

```matlab
% Create client instance
client = FlorentAPIClient('http://localhost:8000');

% Health check
response = client.HealthCheck();
fprintf('Server: %s\n', response);

% Analyze project
request = struct();
request.firm_path = 'src/data/poc/firm.json';
request.project_path = 'src/data/poc/project.json';
request.budget = 100;

response = client.AnalyzeAnalyzeProject(request);
```

### Using the Wrapper Class

For easier usage with error handling and data transformation:

```matlab
% Use the wrapper class (recommended)
client = FlorentAPIClientWrapper('http://localhost:8000');

% Analyze with automatic transformation
data = client.analyzeProject('proj_001', 'firm_001', 100);
```

## Troubleshooting

### Client Generation Fails

**Problem**: "REST API Client Generator not found"
- **Solution**: Install Communications Toolbox or MATLAB Web App Server
- Check: `license('test', 'Communication_Toolbox')`

**Problem**: "OpenAPI spec is invalid"
- **Solution**: Verify `docs/openapi.json` is valid JSON
- Try: `jsondecode(fileread('docs/openapi.json'))`

**Problem**: "Cannot connect to server"
- **Solution**: Ensure Python backend is running
- Test: `webread('http://localhost:8000/')`

### Client Usage Issues

**Problem**: "Method not found"
- **Solution**: Ensure generated client is on MATLAB path
- Run: `addpath(genpath('MATLAB/Classes'))`

**Problem**: "Timeout errors"
- **Solution**: Increase timeout in wrapper configuration
- Update: `config.api.timeout` in `florentConfig.m`

**Problem**: "Response structure doesn't match"
- **Solution**: Use the wrapper's transformation functions
- The wrapper handles response parsing automatically

## Regenerating the Client

If the Python API changes, regenerate the client:

1. Update OpenAPI spec: `python scripts/generate_openapi.py`
2. Regenerate MATLAB client using steps above
3. Test with: `testFlorentAPIClient()`

## Migration from Old Approach

If you're migrating from `callPythonAPI()`:

1. **Old approach**:
   ```matlab
   response = callPythonAPI(endpoint, 'GET');
   data = jsondecode(response);
   ```

2. **New approach**:
   ```matlab
   client = FlorentAPIClientWrapper(config.api.baseUrl);
   data = client.analyzeProject(projectId, firmId, budget);
   ```

The wrapper maintains backward compatibility with existing data structures.

## Next Steps

- See `MATLAB/README_FUNCTIONS.md` for complete API documentation
- Run `testFlorentAPIClient()` to verify setup
- Check `MATLAB/SETUP.md` for general setup instructions

