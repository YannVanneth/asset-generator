part of 'extensions.dart';

extension StringHelper on String {
  String get capitalize =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);

  @Deprecated('Use isAsset instead')
  bool get isImage {
    return endsWith(".png") ||
        endsWith(".jpeg") ||
        endsWith(".jpg") ||
        endsWith(".svg");
  }

  /// Checks if the string represents a valid asset filename.
  ///
  /// Excludes hidden files (starting with '.') and empty filenames.
  bool get isAsset {
    if (isEmpty) return false;
    final name = split('/').last;
    if (name.startsWith('.')) return false;
    return true;
  }
}
