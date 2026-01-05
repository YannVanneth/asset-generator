# Performance Improvements

## Overview
This document describes the performance optimizations made to the asset generator to prevent build hangs and improve performance with large asset directories.

## Changes Made

### 1. Stream-to-List Conversion
**Problem**: The original code used `await for` to iterate over asset streams, which could cause backpressure issues and hangs.

**Solution**: Convert streams to lists using `.toList()` before iteration, which:
- Loads all assets into memory at once
- Prevents stream backpressure
- Enables early error detection
- Allows for performance safeguards (max asset limits)

### 2. Timeout Protection
**Problem**: Slow file system operations could cause builds to hang indefinitely with no feedback.

**Solution**: Added 30-second timeouts on all asset scanning operations with `.timeout()`:
- Prevents indefinite hangs
- Provides warning messages on timeout
- Allows build to continue or fail gracefully

### 3. Error Handling
**Problem**: No error handling meant silent failures or confusing error messages.

**Solution**: Wrapped all asset scanning in try-catch blocks with:
- Descriptive error messages indicating which folder failed
- Context about what operation was being performed
- Guidance on how to fix common issues

### 4. Build Logging
**Problem**: No visibility into what the generator was doing made debugging difficult.

**Solution**: Added comprehensive logging at `log.fine()` and `log.warning()` levels:
- Asset folder discovery start/completion
- Number of folders found
- Processing status for each folder
- Number of assets found per folder
- Number of assets processed
- Warnings when limits are reached

### 5. Performance Safeguards
**Problem**: No limits on asset counts could cause memory issues or very slow builds.

**Solution**: Added safeguards:
- Maximum 1000 assets per folder limit
- Early filtering to skip non-image files
- Deduplication of folder names
- Fail-fast error when limit is exceeded with clear guidance

When a folder exceeds the limit, the build fails with a clear error message:
```
Folder "images" contains 1500 assets, which exceeds the maximum limit of 1000.
Consider splitting assets into multiple folders or increasing the limit.
```

### 6. Code Organization
**Problem**: The main method was doing too much, making it hard to maintain.

**Solution**: Extracted helper methods:
- `_discoverAssetFolders()`: Handles folder discovery with error handling and timeout
- `_loadFolderAssets()`: Handles asset loading for a specific folder with filtering

## Backward Compatibility

All changes maintain backward compatibility:
- Generated code structure remains identical
- Public API unchanged
- Same glob patterns used (no behavior change for normal use cases)
- Only internal implementation optimized

## Performance Characteristics

### Before
- Could hang indefinitely on slow file systems
- No feedback during long operations
- Could consume excessive memory with many assets
- Poor error messages

### After
- 30-second timeout on all operations
- Clear logging of progress
- Maximum 1000 assets per folder
- Descriptive error messages with context
- Early filtering reduces processing time

## Testing Recommendations

1. **Small projects**: Should see no difference in behavior
2. **Large projects**: Should see faster builds and better feedback
3. **Error cases**: Should get clear error messages
4. **Slow file systems**: Should timeout gracefully instead of hanging

## Configuration

Two constants can be adjusted if needed by modifying the source code:
```dart
const int _maxAssetsPerFolder = 1000;  // Max assets per folder
const int _assetScanTimeoutSeconds = 30;  // Timeout in seconds
```

**Note**: If you consistently hit the 1000 asset limit, consider:
1. Organizing assets into more specific subfolders
2. Using the `folders` parameter to explicitly list folders
3. Removing unused assets from your project
