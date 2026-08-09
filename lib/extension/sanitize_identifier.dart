part of 'extensions.dart';

extension SanitizeIdentifier on String {
  static const _dartKeywords = {
    'abstract', 'as', 'assert', 'async', 'await', 'base', 'break', 'case',
    'catch', 'class', 'const', 'continue', 'covariant', 'default', 'deferred',
    'do', 'dynamic', 'else', 'enum', 'export', 'extends', 'extension',
    'external', 'factory', 'false', 'final', 'finally', 'for', 'function',
    'get', 'hide', 'if', 'implements', 'import', 'in', 'interface', 'is',
    'late', 'library', 'mixin', 'new', 'null', 'on', 'operator', 'part',
    'required', 'rethrow', 'return', 'sealed', 'set', 'show', 'static',
    'super', 'switch', 'sync', 'this', 'throw', 'true', 'try', 'type',
    'typedef', 'var', 'void', 'when', 'while', 'with', 'yield',
  };

  String get sanitizeIdentifier {
    if (isEmpty) return '_';

    final lastDotIndex = lastIndexOf('.');
    final baseName = (lastDotIndex > 0) ? substring(0, lastDotIndex) : this;

    final parts = baseName.split(RegExp(r'[^a-zA-Z0-9]')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '_asset';

    final first = parts.first.toLowerCase();
    final rest = parts.skip(1).map((e) => e[0].toUpperCase() + e.substring(1)).join();
    var name = '$first$rest';

    if (RegExp(r'^[0-9]').hasMatch(name)) {
      name = '_$name';
    }

    if (_dartKeywords.contains(name)) {
      name = '${name}Asset';
    }

    return name;
  }
}
