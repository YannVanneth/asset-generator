import 'dart:io';

import 'package:lazy_asset_generator/src/cli/runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('CliRunner', () {
    test('CLI runner performs generation on target project', () async {
      final tempDir = Directory.systemTemp.createTempSync('cli_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      // Setup assets/images/logo.png
      final imgDir = Directory(p.join(tempDir.path, 'assets', 'images'))..createSync(recursive: true);
      File(p.join(imgDir.path, 'logo.png')).writeAsStringSync('png');

      // Setup lib/assets.dart
      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync(recursive: true);
      File(p.join(libDir.path, 'assets.dart')).writeAsStringSync('''
import 'package:lazy_asset_generator/lazy_asset_generator.dart';
part 'assets.g.dart';

@GenerateAssets(folders: ['images'], recursive: true)
class Assets extends _AssetsContext {}
''');

      final runner = CliRunner();
      final exitCode = await runner.run(['--path', tempDir.path]);
      expect(exitCode, equals(0));

      final generatedFile = File(p.join(tempDir.path, 'lib', 'assets.g.dart'));
      expect(generatedFile.existsSync(), isTrue);
      expect(generatedFile.readAsStringSync(), contains('abstract class _AssetsContext'));
      expect(generatedFile.readAsStringSync(), contains('final String logo = AssetPath.images("logo.png");'));
    });

    test('CLI runner handles --force-dart flag', () async {
      final tempDir = Directory.systemTemp.createTempSync('cli_force_dart_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final imgDir = Directory(p.join(tempDir.path, 'assets', 'data'))..createSync(recursive: true);
      File(p.join(imgDir.path, 'info.json')).writeAsStringSync('{}');

      final libDir = Directory(p.join(tempDir.path, 'lib'))..createSync(recursive: true);
      File(p.join(libDir.path, 'data_assets.dart')).writeAsStringSync('''
import 'package:lazy_asset_generator/lazy_asset_generator.dart';
part 'data_assets.g.dart';

@GenerateAssets(folder: 'data')
class DataAssets extends _DataAssetsContext {}
''');

      final runner = CliRunner();
      final exitCode = await runner.run(['--path', tempDir.path, '--force-dart']);
      expect(exitCode, equals(0));

      final generatedFile = File(p.join(tempDir.path, 'lib', 'data_assets.g.dart'));
      expect(generatedFile.existsSync(), isTrue);
      expect(generatedFile.readAsStringSync(), contains('abstract class _DataAssetsContext'));
    });
  });
}
