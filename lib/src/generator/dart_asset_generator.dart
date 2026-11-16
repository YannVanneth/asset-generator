import 'dart:io';

import 'package:lazy_asset_generator/lazy_asset_generator/lazy_asset_generator.dart';
import 'package:lazy_asset_generator/src/parser/annotation_parser.dart';
import 'package:path/path.dart' as p;

/// Pure Dart asset generator using [AssetSourceGenerator].
class DartAssetGenerator {
  /// Scans assets on disk and generates the `.g.dart` file for [config].
  static String generate({
    required String projectRoot,
    required AssetConfig config,
    bool writeToFile = true,
  }) {
    final assetsByFolder = <String, List<String>>{};

    for (final folder in config.folders) {
      final normalizedFolder = folder.replaceAll(r'\', '/').replaceAll(RegExp(r'^/+|/+$'), '');
      final dir = Directory(p.join(projectRoot, 'assets', normalizedFolder));
      if (!dir.existsSync()) {
        throw FormatException("No visible assets were found in 'assets/$normalizedFolder/'.");
      }

      final assets = <String>[];
      for (final entity in dir.listSync(recursive: config.recursive)) {
        if (entity is! File) continue;

        // Skip hidden files or files in hidden folders
        final relativeToProject = p.relative(entity.path, from: projectRoot).replaceAll(r'\', '/');
        final segments = relativeToProject.split('/');
        if (segments.any((s) => s.startsWith('.'))) continue;

        assets.add(relativeToProject);
      }

      assets.sort();
      if (assets.isEmpty) {
        throw FormatException("No visible assets were found in 'assets/$normalizedFolder/'.");
      }
      assetsByFolder[normalizedFolder] = assets;
    }

    final code = AssetSourceGenerator.generate(
      inputFileName: config.inputFileName,
      contextClassName: config.className,
      folders: config.folders,
      assetsByFolder: assetsByFolder,
      recursive: config.recursive,
    );

    if (writeToFile) {
      final outputFile = File(p.join(projectRoot, config.outputFilePath));
      outputFile.parent.createSync(recursive: true);
      outputFile.writeAsStringSync(code);
    }

    return code;
  }
}
