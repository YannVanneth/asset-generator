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
