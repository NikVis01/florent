# MATLAB Quick Start - Get This Shit Running

**TL;DR: Run these 3 commands and you're done. Skip all the REST API Client Generator bullshit.**

## Step 1: Initialize Paths

Open MATLAB and run:

```matlab
initializeFlorent()
```

This adds all the necessary directories to your MATLAB path. That's it.

## Step 2: Verify It Works

```matlab
quickHealthCheck()
```

If this passes, you're good to go. If it fails, see troubleshooting below.

## Step 3: Run a Demo

```matlab
runFlorentDemo()
```

If this works, **YOU'RE DONE**. Everything is set up correctly.

---

## That's It. Seriously.

The API client uses manual HTTP calls automatically. **You don't need to install anything else.** 

**DO NOT** waste your time with:
- [X] REST API Client Generator
- [X] OpenAPI client generation
- [X] Communications Toolbox (unless you want it for other reasons)
- [X] Any of that complicated bullshit

The codebase works with **manual HTTP calls** (`webread`/`webwrite`) which are built into MATLAB. No add-ons needed.

---

## Using the API

Just use the wrapper - it works automatically:

```matlab
% Create client
client = FlorentAPIClientWrapper('http://localhost:8000')

% Health check
health = client.healthCheck()

% Run analysis
data = client.analyzeProject('proj_001', 'firm_001', 100)
```

That's it. No setup. No configuration. It just works.

---

## Troubleshooting

### "Function not found" Error

**Fix:** Run `initializeFlorent()` again. If that doesn't work, make sure you're in the right directory:

```matlab
cd('/path/to/florent/MATLAB')
initializeFlorent()
```

### Path Not Persisting Between Sessions

**Fix:** Run this once to save paths permanently:

```matlab
initializeFlorent(true)
```

If that fails (permissions issue), add this to your `startup.m` file:

```matlab
% Find your startup.m location:
userpath

% Then edit that file and add:
cd('/path/to/florent/MATLAB')
initializeFlorent(false)
```

### API Connection Errors

**Fix:** Make sure the Python API is running:

```bash
# In terminal:
./run.sh
```

Then test in MATLAB:

```matlab
webread('http://localhost:8000/')
```

If that fails, the Python API isn't running. Start it first.

### Parallel Processing Errors (UndefinedFunction on workers)

If you see errors like "An UndefinedFunction error was thrown on the workers for 'calculate_influence_score'", this means parallel workers can't find the functions.

**Fix:** The code now automatically handles this, but if you still see errors:

1. **Close and recreate the parallel pool:**
   ```matlab
   delete(gcp('nocreate'))  % Close existing pool
   initializeFlorent(false, true)  % Setup paths including parallel workers
   ```

2. **Or manually setup worker paths:**
   ```matlab
   pool = gcp('nocreate');
   if isempty(pool)
       pool = parpool('local');
   end
   pathManager('setupWorkerPaths', pool)
   ```

3. **Verify worker paths:**
   ```matlab
   verifyPaths(true)  % Check worker paths too
   ```

4. **Test path management:**
   ```matlab
   testPathManagement()  % Run comprehensive path tests
   ```

The system now automatically sets up worker paths when parallel pools are created, so this should rarely be needed.

### Still Having Issues?

1. Run: `quickHealthCheck()` - tells you what's broken (now includes parallel path checks)
2. Run: `verifyPaths(true)` - detailed path diagnostics including workers
3. Run: `testPathManagement()` - comprehensive path management tests
4. Run: `verifyFlorentCodebase()` - detailed diagnostics
5. Check: `which functionName` - should return a file path, not empty

---

## What About the REST API Client Generator?

**FUCK IT. SKIP IT.**

The REST API Client Generator is:
- [X] Not required
- [X] Complicated to set up
- [X] Requires add-ons you don't need
- [X] Provides minimal benefits (just IntelliSense)

The codebase works perfectly without it using manual HTTP calls. The `FlorentAPIClientWrapper` automatically uses `webread`/`webwrite` which are built into MATLAB.

**If you really want it** (you don't need it), see `docs/OPENAPI_CLIENT_SETUP.md`. But seriously, just skip it.

---

## Next Steps

Once setup works:

1. **Try the demo:** `runFlorentDemo()`
2. **Run full analysis:** `runFlorentAnalysis()`
3. **Launch the app (optional):** `app = florentRiskApp`

---

## Summary

1. Run `initializeFlorent()`
2. Run `quickHealthCheck()`
3. Run `runFlorentDemo()`
4. **DONE. STOP. DON'T INSTALL ANYTHING ELSE.**

The API client works automatically. No REST API Client Generator needed. No add-ons needed. Just MATLAB.

