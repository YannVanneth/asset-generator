import 'dart:io';

import 'package:lazy_asset_generator/src/ffi/native_bindings.dart';
import 'package:lazy_asset_generator/src/parser/annotation_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('NativeAssetEngine', () {
    test('NativeAssetEngine generates asset code via FFI', () {
      final tempDir = Directory.systemTemp.createTempSync('ffi_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final imgDir = Directory(p.join(tempDir.path, 'assets', 'images'))..createSync(recursive: true);
      File(p.join(imgDir.path, 'logo.png')).writeAsStringSync('png');

      final engine = NativeAssetEngine();
      expect(engine.isAvailable, isTrue);

      const config = AssetConfig(
        targetFilePath: 'lib/asset_manager.dart',
        outputFilePath: 'lib/asset_manager.g.dart',
        className: 'AssetManager',
        folders: ['images'],
        recursive: true,
      );

      final code = engine.generate(
        projectRoot: tempDir.path,
        config: config,
        writeToFile: true,
      );

      expect(code, contains("part of 'asset_manager.dart';"));
      expect(code, contains('abstract class _AssetManagerContext'));
      expect(code, contains('final String logo = AssetPath.images("logo.png");'));

      final outFile = File(p.join(tempDir.path, 'lib', 'asset_manager.g.dart'));
      expect(outFile.existsSync(), isTrue);
      expect(outFile.readAsStringSync(), equals(code));
    });

    test('NativeAssetEngine resolves package root from consumer project', () {
      final exampleDir = p.join(Directory.current.path, 'example');
      final packageRoot = NativeAssetEngine.resolvePackageRoot(exampleDir);
      expect(packageRoot, isNotNull);
      expect(File(p.join(packageRoot!, 'pubspec.yaml')).existsSync(), isTrue);
    });

    test('NativeAssetEngine supports forceDart fallback', () {
      final tempDir = Directory.systemTemp.createTempSync('ffi_fallback_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final imgDir = Directory(p.join(tempDir.path, 'assets', 'images'))..createSync(recursive: true);
      File(p.join(imgDir.path, 'icon.png')).writeAsStringSync('png');

      final engine = NativeAssetEngine();

      const config = AssetConfig(
        targetFilePath: 'lib/fallback.dart',
        outputFilePath: 'lib/fallback.g.dart',
        className: 'FallbackAssets',
        folders: ['images'],
        recursive: false,
      );

      final code = engine.generate(
        projectRoot: tempDir.path,
        config: config,
        writeToFile: true,
        forceDart: true,
      );

      expect(code, contains("part of 'fallback.dart';"));
      expect(code, contains('abstract class _FallbackAssetsContext'));
      expect(code, contains('final String icon = AssetPath.images("icon.png");'));
    });
  });
}
