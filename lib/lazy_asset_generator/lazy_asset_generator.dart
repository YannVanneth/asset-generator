library;

import 'dart:async';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:source_gen/source_gen.dart';
import 'annotations.dart';
import 'package:lazy_asset_generator/extension/extensions.dart';
import 'package:path/path.dart' as p;

// Performance safeguard: Maximum assets to process per folder
const int _maxAssetsPerFolder = 1000;
// Timeout for asset scanning operations (in seconds)
const int _assetScanTimeoutSeconds = 30;

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

    log.fine('Starting asset folder discovery for ${element.name}');
    
    final targetFolders = folderName.isNotEmpty
        ? [folderName]
        : folders.isNotEmpty
            ? folders
            : await _discoverAssetFolders(buildStep);
    
    log.fine('Found ${targetFolders.length} folders to process: $targetFolders');

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
      log.fine('Processing folder: $folder');
      final helperClassName = "_${folder.sanitizeIdentifier.capitalize}";
      classBuffer.writeln("class $helperClassName {");
      
      try {
        final assetsList = await _loadFolderAssets(buildStep, folder);
        log.fine('Found ${assetsList.length} assets in folder: $folder');
        
        int processedCount = 0;
        for (final asset in assetsList) {
          if (processedCount >= _maxAssetsPerFolder) {
            log.warning(
                'Reached maximum asset limit ($_maxAssetsPerFolder) for folder: $folder. '
                'Skipping remaining assets.');
            break;
          }
          
          final assetName = p.basename(asset.path);
          final id = assetName.sanitizeIdentifier;
          final methodName = folder.sanitizeIdentifier;
          classBuffer.writeln(
              '  final String $id = AssetPath.$methodName("$assetName");');
          processedCount++;
        }
        
        log.fine('Processed $processedCount assets from folder: $folder');
      } catch (e) {
        log.severe('Error processing folder $folder: $e');
        throw Exception(
            'Failed to process assets in folder "$folder": $e');
      }
      
      classBuffer.writeln("}\n");
    }

    return classBuffer.toString();
  }
  
  /// Discovers asset folders with optimized scanning and error handling
  Future<List<String>> _discoverAssetFolders(BuildStep buildStep) async {
    log.fine('Discovering asset folders...');
    
    try {
      // Use a more specific glob pattern and add timeout protection
      final foldersSet = <String>{};
      
      // Scan for assets with timeout protection
      final assetsFuture = buildStep
          .findAssets(Glob('assets/*'))
          .timeout(
            Duration(seconds: _assetScanTimeoutSeconds),
            onTimeout: (sink) {
              log.warning(
                  'Asset folder discovery timed out after $_assetScanTimeoutSeconds seconds');
              sink.close();
            },
          )
          .toList();
      
      final assets = await assetsFuture;
      
      // Extract unique folder names from asset paths
      for (final asset in assets) {
        if (asset.pathSegments.length >= 2) {
          final folderName = asset.pathSegments[1];
          if (folderName.isNotEmpty) {
            foldersSet.add(folderName);
          }
        }
      }
      
      final folders = foldersSet.toList()..sort();
      
      if (folders.isEmpty) {
        log.warning(
            'No asset folders found. Make sure assets are in the assets/ directory.');
      }
      
      return folders;
    } catch (e) {
      log.severe('Error discovering asset folders: $e');
      throw Exception(
          'Failed to discover asset folders. Ensure the assets/ directory exists and is accessible: $e');
    }
  }
  
  /// Loads assets from a specific folder with optimizations
  Future<List<AssetId>> _loadFolderAssets(
      BuildStep buildStep, String folder) async {
    try {
      // Use non-recursive glob pattern to avoid deep scanning
      // The pattern 'assets/$folder/*' matches only immediate children
      final assetsFuture = buildStep
          .findAssets(Glob('assets/$folder/*'))
          .timeout(
            Duration(seconds: _assetScanTimeoutSeconds),
            onTimeout: (sink) {
              log.warning(
                  'Asset loading timed out for folder: $folder after $_assetScanTimeoutSeconds seconds');
              sink.close();
            },
          )
          .toList();
      
      final assets = await assetsFuture;
      
      // Filter early to only include image files
      final imageAssets = assets.where((asset) {
        final assetName = p.basename(asset.path);
        return assetName.isImage;
      }).toList();
      
      return imageAssets;
    } catch (e) {
      log.severe('Error loading assets from folder $folder: $e');
      throw Exception('Failed to load assets from folder "$folder": $e');
    }
  }
}

Builder assetFolderBuilder(BuilderOptions options) => LibraryBuilder(
      AssetFolderGenerator(),
      generatedExtension: ".g.dart",
    );
