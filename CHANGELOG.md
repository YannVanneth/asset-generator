## 1.3.2 (Unreleased)
### Performance Improvements
- Added logging for better build progress tracking and debugging
- Optimized asset scanning with stream-to-list conversion to prevent backpressure
- Added timeout protection (30 seconds) to prevent builds from hanging indefinitely
- Added maximum asset limit per folder (1000) to prevent memory issues with large directories
- Added comprehensive error handling with meaningful error messages
- Early filtering of non-image files to improve performance

### Bug Fixes
- Fixed hanging builds caused by synchronous asset iteration
- Fixed potential infinite hangs from unbounded asset scanning
- Improved error messages when asset discovery fails

## 1.3.1
- Initial release of asset_generator.