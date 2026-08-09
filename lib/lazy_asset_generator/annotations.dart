/// An annotation used to generate a strongly-typed asset access class.
///
/// Apply this annotation to a class (or abstract class) to automatically generate a
/// `.g.dart` file containing a strongly-typed asset context based on your project's
/// asset directories. The generated class follow the pattern:
///
///   `_<ClassName>Context`
///
/// Simply extend your annotated class with the generated context class to gain
/// auto-completed, strongly-typed accessors to all your assets.
///
/// ---
///
/// ### How It Works
///
/// When `build_runner` executes, the generator:
/// - Reads the specified target folder(s) from [folder] or [folders].
/// - Scans those directories for any asset files (images `.png`, `.svg`, data `.json`,
///   fonts `.ttf`, audio `.mp3`, animations `.rive`/`.lottie`, etc.).
/// - Sanitizes asset filenames into valid Dart identifiers (`theme.dark.json` -> `themeDark`,
///   `24_hours.svg` -> `_24Hours`, `default.json` -> `defaultAsset`).
/// - Excludes hidden system files (e.g. `.DS_Store`, `.gitkeep`).
/// - Outputs a strongly-typed context class with instant IDE auto-completion.
///
/// ---
///
/// ### Example Usage
///
/// ```dart
/// import 'package:lazy_asset_generator/lazy_asset_generator.dart';
///
/// part 'asset_manager.g.dart';
///
/// @GenerateAssets(folders: ["Icons", "images", "json"])
/// class AssetManager extends _AssetManagerContext {}
/// ```
///
/// Access your assets anywhere safely:
/// ```dart
/// Image.asset(AssetManager().icons.home);
/// String jsonPath = AssetManager().json.configDark;
/// ```
class GenerateAssets {
  /// The target folder name under `assets/` to scan for assets (e.g. `"icons"`).
  final String folder;

  /// A list of folder names under `assets/` to scan (e.g. `["icons", "images", "json"]`).
  final List<String> folders;

  /// Optional override for the generated context class name.
  final String className;

  /// Creates a new [@GenerateAssets] annotation.
  ///
  /// Specify either [folder] for a single directory or [folders] for multiple directories.
  const GenerateAssets({
    this.folder = '',
    this.folders = const [],
    this.className = '',
  });
}
