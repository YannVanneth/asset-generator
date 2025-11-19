part of 'extensions.dart';

extension StringHelper on String {
  String get capitalize =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
  bool get isImage {
    return endsWith(".png") ||
        endsWith(".jpeg") ||
        endsWith(".jpg") ||
        endsWith(".svg");
  }
}
