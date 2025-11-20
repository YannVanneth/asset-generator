/// An annotation used to generate a strongly-typed asset helper class.
///
/// Apply this annotation to an **abstract class** to automatically generate a
/// `.g.dart` file containing a typed asset context based on the provided
/// folder information. The generated class name is based on the annotated
/// class name and will follow the pattern:
///
///   `_<ClassName>Context`
///
/// To use the generated asset constants, simply extend your annotated class
/// with its generated context class.
///
/// ---
///
/// ### How It Works
///
/// When the build runner executes, the generator:
/// - Reads the `folder` or `folders` you specify.
/// - Scans those directories in your `pubspec.yaml` asset section.
/// - Generates static, strongly-typed constants for every asset found.
/// - Groups assets by folder structure when multiple folders are provided.
///
/// ---
///
/// ### Example
///
/// ```dart
/// @GenerateAssets(folder: "icons")
/// abstract class Icons {}
/// ```
///
/// This will generate a file: `icons.g.dart` containing:
///
/// ```dart
/// class _IconsContext {
///   // generated asset getters here...
/// }
/// ```
///
/// To use the generated context:
///
/// ```dart
/// class Icons extends _IconsContext {}
/// ```
///
/// Now you can access your assets in a typed, auto-completed way.
///
/// ---
///
/// Use [folder] for a single directory or [folders] for multiple directories.
/// If [className] is provided, it overrides the generated context class name.
class GenerateAssets {
  final String folder;
  final List<String> folders;
  final String className;

  const GenerateAssets({
    this.folder = '',
    this.folders = const [],
    this.className = '',
  });
}
