import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart' as p;

/// Configuration extracted from an `@GenerateAssets` annotation.
class AssetConfig {
  final String targetFilePath;
  final String outputFilePath;
  final String className;
  final List<String> folders;
  final bool recursive;

  const AssetConfig({
    required this.targetFilePath,
    required this.outputFilePath,
    required this.className,
    required this.folders,
    required this.recursive,
  });

  String get inputFileName => p.basename(targetFilePath);

  Map<String, dynamic> toJson() => {
    'input_file_name': inputFileName,
    'context_class_name': className,
    'folders': folders,
    'recursive': recursive,
    'include_part': true,
  };
}

/// AST parser that scans Dart source files for `@GenerateAssets` annotations.
class AnnotationParser {
  /// Scans a Dart file at [path] and extracts all [AssetConfig] declarations.
  static List<AssetConfig> parseFile(String path) {
    final file = File(path);
    if (!file.existsSync()) return const [];
    return parseSource(file.readAsStringSync(), path);
  }

  /// Parses Dart [source] string and extracts all [AssetConfig] declarations.
  static List<AssetConfig> parseSource(String source, String filePath) {
    final configs = <AssetConfig>[];
    try {
      final result = parseString(
        content: source,
        path: filePath,
        throwIfDiagnostics: false,
      );
      final unit = result.unit;

      for (final declaration in unit.declarations) {
        if (declaration is! ClassDeclaration) continue;

        for (final metadata in declaration.metadata) {
          if (metadata.name.name != 'GenerateAssets') continue;

          final config = _extractConfig(declaration, metadata, filePath);
          if (config != null) {
            configs.add(config);
          }
        }
      }
    } catch (_) {
      // Ignored for malformed files
    }
    return configs;
  }

  /// Scans a directory (e.g. `lib/`) for all Dart files containing `@GenerateAssets`.
  static List<AssetConfig> scanDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return const [];

    final configs = <AssetConfig>[];
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.g.dart')) {
        configs.addAll(parseFile(entity.path));
      }
    }
    return configs;
  }

  static AssetConfig? _extractConfig(
    ClassDeclaration classDecl,
    Annotation annotation,
    String targetFilePath,
  ) {
    final args = annotation.arguments?.arguments;
    var folderName = '';
    var folders = <String>[];
    var recursive = false;
    var configuredClassName = '';

    if (args != null) {
      for (final arg in args) {
        if (arg is! NamedArgument) continue;
        final name = arg.name.lexeme;
        final expression = arg.argumentExpression;

        switch (name) {
          case 'folder':
            if (expression is SimpleStringLiteral) {
              folderName = expression.value;
            }
          case 'folders':
            if (expression is ListLiteral) {
              folders = expression.elements
                  .whereType<SimpleStringLiteral>()
                  .map((e) => e.value)
                  .toList();
            }
          case 'recursive':
            if (expression is BooleanLiteral) {
              recursive = expression.value;
            }
          case 'className':
            if (expression is SimpleStringLiteral) {
              configuredClassName = expression.value;
            }
        }
      }
    }

    final targetFolders = folderName.isNotEmpty
        ? [folderName]
        : (folders.isNotEmpty ? folders : <String>[]);

    final className = configuredClassName.isNotEmpty
        ? configuredClassName
        : classDecl.namePart.typeName.lexeme;

    final outputFilePath = p.setExtension(targetFilePath, '.g.dart');

    return AssetConfig(
      targetFilePath: targetFilePath,
      outputFilePath: outputFilePath,
      className: className,
      folders: targetFolders,
      recursive: recursive,
    );
  }
}
