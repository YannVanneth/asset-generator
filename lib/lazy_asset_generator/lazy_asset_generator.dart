library;

import 'dart:async';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'annotations.dart';
import 'package:lazy_asset_generator/extension/extensions.dart';
import 'package:path/path.dart' as p;

class AssetFolderGenerator extends GeneratorForAnnotation<GenerateAssets> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      element, annotation, buildStep) async {
    final folderName = annotation.read('folder').stringValue;
    final folders = annotation
        .read('folders')
        .listValue
        .map((e) => e.toStringValue() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    if (folderName.isNotEmpty && folders.isNotEmpty) {
      throw Exception(
          "Invalid @GenerateAsset usage on '${element.name}': "
          "both 'folder' and 'folders' are provided. Use only one.");
    }

    final targetFolders = folderName.isNotEmpty
        ? [folderName]
        : folders.isNotEmpty
            ? folders
            : await buildStep
                .findAssets(Glob('assets/*'))
                .map((id) => id.pathSegments[1])
                .toList();

    final classBuffer = StringBuffer();

    final inputFile = buildStep.inputId.path;
    final fileName = p.basename(inputFile);
    classBuffer.writeln("part of '$fileName';\n");

    classBuffer.writeln("class AssetPath {");
    classBuffer.writeln("  const AssetPath._();");
    classBuffer.writeln();
    for (var folder in targetFolders) {
      final methodName = folder.sanitizeIdentifier;
      classBuffer.writeln(
          "  static String $methodName(String assetName) => 'assets/$folder/\$assetName';");
    }
    classBuffer.writeln("}\n");

    final wrapperClassName = element.name;

    classBuffer.writeln("abstract class _${wrapperClassName}Context {");

    for (var folder in targetFolders) {
      final helperClassName = "_${folder.sanitizeIdentifier.capitalize}";
      final instanceName = folder.sanitizeIdentifier;
      classBuffer.writeln("  $helperClassName $instanceName = $helperClassName();");
    }

    classBuffer.writeln("}\n");

    for (var folder in targetFolders) {
      final helperClassName = "_${folder.sanitizeIdentifier.capitalize}";
      classBuffer.writeln("class $helperClassName {");
      final assets = buildStep.findAssets(Glob('assets/$folder/*'));
      await for (final asset in assets) {
        final assetName = p.basename(asset.path);
        if (assetName.isAsset) {
          final id = assetName.sanitizeIdentifier;
          final methodName = folder.sanitizeIdentifier;
          classBuffer.writeln(
              '  final String $id = AssetPath.$methodName("$assetName");');
        }
      }
      classBuffer.writeln("}\n");
    }

    return classBuffer.toString();
  }
}

Builder assetFolderBuilderImpl(BuilderOptions options) => LibraryBuilder(
      AssetFolderGenerator(),
      generatedExtension: ".g.dart",
    );

Builder assetFolderBuilder(BuilderOptions options) => assetFolderBuilderImpl(options);
