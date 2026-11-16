## 1.7.0

### Standalone CLI & Instant Code Generation
- Added `bin/lazy_asset_generator.dart` executable, allowing developers to generate strongly-typed asset accessors directly with `dart run lazy_asset_generator` without the multi-second startup overhead of `build_runner`.
- Built lightweight AST annotation parser using `package:analyzer` (`parseString`) to locate and extract `@GenerateAssets` configuration (`folders`, `folder`, `recursive`, `className`) directly from Dart source files in under 2ms per file.
- Added validation in the CLI parser matching `build_runner` rules: enforces a maximum of one asset manager per library and prevents mutually exclusive `folder` and `folders` arguments.

### Continuous Watcher Daemon
- Added continuous background file watcher daemon via `dart run lazy_asset_generator --watch` (or `-w`).
- Implemented recursive directory watching across `assets/` and `lib/` with dynamic subscription for newly created folders and files across Linux, macOS, and Windows.
- Added a 250ms sliding debounce window to coalesce rapid file operations (such as batch asset imports or multi-file IDE saves) into a single generation pass.
- Added loop prevention that ignores events on generated `.g.dart` files and hidden directories (`.git`, `.dart_tool`).
- Added graceful shutdown on process signals (`SIGINT` / `SIGTERM`).

### High-Performance Rust FFI Engine
- Added native Rust engine (`lazy_asset_core`) in `native/`, compiled as a C-ABI shared library (`.so` on Linux, `.dylib` on macOS, `.dll` on Windows).
- Traverses asset folders with `walkdir` and emits deterministic Dart accessor classes in under 3ms.
- Features complete identifier sanitization matching Dart specifications: strips extensions, converts kebab/snake/space-separated names to camelCase, prepends underscores to leading digits, and appends `Asset` suffix to reserved Dart keywords.
- Generates identical class hierarchies and accessor names as the original `source_gen` builder, ensuring 100% backward compatibility for nested and recursive asset structures.
- Implemented safe C-ABI memory management with explicit deallocation (`lazy_asset_free_string` via `CString::from_raw`) and NUL-safe error handling across the FFI boundary.

### Pure Dart Fallback Engine & Auto-Compilation
- Implemented a resilient, zero-install pure Dart fallback engine (`DartAssetGenerator`) that automatically runs if the precompiled native library is absent and Cargo is not installed.
- Added automatic background compilation: when `cargo` is available on the machine, the CLI automatically compiles and caches the native release binary on first run.
- Added smart package root resolution via `.dart_tool/package_config.json` so the native binary is resolved seamlessly when invoked from external Flutter consumer projects.

### CLI Options & Flags
- `-w`, `--watch`: Start continuous file watcher daemon.
- `--force-dart`: Force using the pure Dart engine, bypassing the Rust native binary.
- `-v`, `--verbose`: Enable detailed logs displaying engine selection and generation timings.
- `--path <path>` / `--path=<path>`: Specify target project root directory (defaults to current working directory).
- `-h`, `--help`: Display usage and command options.

### Compatibility
- Existing `dart run build_runner build` and `build_runner watch` setups remain fully supported with zero breaking changes.

## 1.6.0
- Escape interpolation characters, quotes, backslashes, and control characters in generated asset paths.
- Validate folder paths before normalization and report invalid annotations at their source.
- Detect inherited-member, helper/context, and existing library declaration collisions.
- Require one annotated asset manager per library and reject non-class targets.
- Use shared-part generation so `.g.dart` outputs can coexist with other generators; keep the existing builder identifier and generated API.
- Align dependency floors with the analyzer API and require Dart 3.8 or later.
- Restore the missing example image and clarify filesystem discovery versus Flutter asset declarations.
- Add executable rendering, builder integration, and clean consumer incremental-build tests; test Dart 3.8 and stable in CI.

## 1.5.0
- Added opt-in recursive asset scanning with generated groups for nested directories.
- Added deterministic asset ordering and collision detection for sanitized identifiers.
- Added validation and actionable errors for empty asset folders, invalid folder paths, and invalid generated class names.
- Wired the `className` annotation option into generated context names.
- Added generator rendering tests and expanded usage documentation.
- Added a runnable example project, contribution guide, and GitHub Actions CI
  for formatting, analysis, tests, and package validation.

## 1.4.1
- Updated repository, homepage, and issue tracker GitHub URLs to point to `asset-generator`.
- Enhanced in-code Dart documentation comments across all package components.
- Modernized `README.md` documentation, badges, code snippets, and added Google Antigravity maintenance attribution.

## 1.4.0
- Refactored library exports to resolve Flutter `dart:mirrors` compilation error.
- Expanded asset generator to support all asset types (`.json`, `.ttf`, `.mp3`, `.rive`, `.lottie`, `.pdf`, `.svg`, `.png`, etc.).
- Upgraded dependencies (`build`, `source_gen`, `build_runner`, `flutter_lints`, `test`).
- Improved identifier sanitization for multi-dot filenames, leading numbers, and Dart keywords.

## 1.3.1
- Initial release of asset_generator.
