# Usage Examples

## Basic Usage (Unchanged)

The API remains the same - existing code will work without any changes.

### Example 1: Single Folder
```dart
import 'package:lazy_asset_generator/lazy_asset_generator.dart';

part 'assets.g.dart';

@GenerateAssets(folder: "images")
class Assets extends _AssetsContext {}
```

### Example 2: Multiple Folders
```dart
import 'package:lazy_asset_generator/lazy_asset_generator.dart';

part 'assets.g.dart';

@GenerateAssets(folders: ["icons", "images", "illustrations"])
class Assets extends _AssetsContext {}
```

### Example 3: Auto-discover All Folders
```dart
import 'package:lazy_asset_generator/lazy_asset_generator.dart';

part 'assets.g.dart';

@GenerateAssets()  // Discovers all folders in assets/
class Assets extends _AssetsContext {}
```

## Build Logging

When you run `dart run build_runner build`, you'll now see helpful progress logs:

```
[INFO] Starting asset folder discovery for Assets
[INFO] Found 3 folders to process: [icons, images, illustrations]
[INFO] Processing folder: icons
[INFO] Found 25 assets in folder: icons
[INFO] Processed 25 assets from folder: icons
[INFO] Processing folder: images
[INFO] Found 150 assets in folder: images
[INFO] Processed 150 assets from folder: images
[INFO] Processing folder: illustrations
[INFO] Found 45 assets in folder: illustrations
[INFO] Processed 45 assets from folder: illustrations
```

## Error Handling

### Example: Too Many Assets
If a folder has more than 1000 assets, the build will fail with a clear message:

```
[SEVERE] Error processing folder images: Exception: Folder "images" contains 1500 assets, 
which exceeds the maximum limit of 1000. Consider splitting assets into multiple folders 
or increasing the limit.
```

**Solution**: Split your assets into subfolders:
```yaml
assets:
  - assets/images/photos/
  - assets/images/backgrounds/
  - assets/images/ui/
```

### Example: Timeout
If asset scanning takes too long (> 30 seconds), you'll see:

```
[WARNING] Asset loading timed out for folder: images after 30 seconds
```

### Example: Missing Assets Directory
If the assets directory doesn't exist:

```
[WARNING] No asset folders found. Make sure assets are in the assets/ directory.
```

## Performance Tips

1. **Use specific folders**: Instead of auto-discovering, specify exact folders:
   ```dart
   @GenerateAssets(folders: ["icons", "images"])  // Better
   @GenerateAssets()  // Slower - scans everything
   ```

2. **Organize assets**: Keep related assets in separate folders:
   ```
   assets/
     icons/         (50 files)
     images/        (200 files)
     illustrations/ (100 files)
   ```

3. **Remove unused assets**: The generator processes all files, so remove unused assets.

4. **Use appropriate formats**: Only image files (png, jpg, jpeg, svg) are processed.

## Migration Guide

No migration needed! All existing code will continue to work exactly as before. The improvements are internal optimizations that:
- Make builds faster
- Prevent hangs
- Provide better error messages
- Add helpful logging

Your generated code remains identical.
