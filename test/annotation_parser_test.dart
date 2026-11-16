import 'dart:io';

import 'package:lazy_asset_generator/src/generator/dart_asset_generator.dart';
import 'package:lazy_asset_generator/src/parser/annotation_parser.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('AnnotationParser', () {
    test('parses @GenerateAssets annotation correctly', () {
      const source = '''
        import 'package:lazy_asset_generator/lazy_asset_generator.dart';
        part 'test.g.dart';
        @GenerateAssets(folders: ['images'], recursive: true)
        class Assets extends _AssetsContext {}
      ''';
      final configs = AnnotationParser.parseSource(source, 'lib/test.dart');
      expect(configs.length, equals(1));
      expect(configs.first.className, equals('Assets'));
      expect(configs.first.folders, equals(['images']));
      expect(configs.first.recursive, isTrue);
      expect(configs.first.targetFilePath, equals('lib/test.dart'));
      expect(configs.first.outputFilePath, equals('lib/test.g.dart'));
    });

    test('parses single folder parameter and custom className', () {
      const source = '''
        @GenerateAssets(folder: 'icons', className: 'MyIcons')
        class IconsManager extends _IconsManagerContext {}
      ''';
      final configs = AnnotationParser.parseSource(source, 'lib/sub/icons.dart');
      expect(configs.length, equals(1));
      expect(configs.first.className, equals('MyIcons'));
      expect(configs.first.folders, equals(['icons']));
      expect(configs.first.recursive, isFalse);
      expect(configs.first.outputFilePath, equals('lib/sub/icons.g.dart'));
    });
  });

  group('DartAssetGenerator', () {
    test('generates Dart code from filesystem assets', () {
      final tempDir = Directory.systemTemp.createTempSync('dart_asset_gen_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final imageDir = Directory(p.join(tempDir.path, 'assets', 'images'))..createSync(recursive: true);
      File(p.join(imageDir.path, 'logo.png')).writeAsStringSync('png');

      const config = AssetConfig(
        targetFilePath: 'lib/assets.dart',
        outputFilePath: 'lib/assets.g.dart',
        className: 'AppAssets',
        folders: ['images'],
        recursive: false,
      );

      final code = DartAssetGenerator.generate(
        projectRoot: tempDir.path,
        config: config,
        writeToFile: true,
      );

      expect(code, contains("part of 'assets.dart';"));
      expect(code, contains('abstract class _AppAssetsContext'));
      expect(code, contains('final String logo = AssetPath.images("logo.png");'));

      final writtenFile = File(p.join(tempDir.path, 'lib', 'assets.g.dart'));
      expect(writtenFile.existsSync(), isTrue);
      expect(writtenFile.readAsStringSync(), equals(code));
    });
  });
}
