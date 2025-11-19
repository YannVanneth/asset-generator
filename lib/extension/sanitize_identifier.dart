part of 'extensions.dart';

extension SanitizeIdentifier on String {
  String get sanitizeIdentifier {
    var name = split('.').first;

    final parts = name.split(RegExp(r'[^a-zA-Z0-9]'));

    name =
        parts.first.toLowerCase() +
        parts
            .skip(1)
            .map((e) => e.isEmpty ? '' : e[0].toUpperCase() + e.substring(1))
            .join();

    if (RegExp(r'^[0-9]').hasMatch(name)) name = "_$name";

    return name;
  }
}
