import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'clean consumer builds, analyzes, runs, and updates incrementally',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'asset-generator-consumer-',
      );
      addTearDown(() => directory.delete(recursive: true));
      Future<void> write(String path, String content) async {
        final file = File('${directory.path}/$path');
        await file.parent.create(recursive: true);
        await file.writeAsString(content);
      }

      Future<ProcessResult> dart(List<String> arguments) async {
        final result = await Process.run(
          Platform.resolvedExecutable,
          arguments,
          workingDirectory: directory.path,
        );
        expect(
          result.exitCode,
          0,
          reason:
              'dart ${arguments.join(' ')}\n${result.stdout}\n${result.stderr}',
        );
        return result;
      }

      await write('pubspec.yaml', '''
name: asset_generator_consumer
environment:
  sdk: '>=3.8.0 <4.0.0'
dependencies:
  lazy_asset_generator:
    path: ${jsonEncode(Directory.current.path)}
dev_dependencies:
  build_runner: ^2.8.0
''');
      await write('lib/manager.dart', r'''
import 'dart:convert';
import 'package:lazy_asset_generator/lazy_asset_generator.dart';
part 'manager.g.dart';
@GenerateAssets(recursive: true)
class Assets extends _AssetsContext {}
void main() {
  final assets = Assets();
  print(jsonEncode([assets.images.logo, assets.cash.priceUsd, assets.images.marketing.banner]));
}
''');
      await write('assets/images/logo.png', '');
      await write(r'assets/cash$/price$usd.png', '');
      await write('assets/images/marketing/banner.png', '');
      await dart(['pub', 'get', '--offline']);
      Future<String> generate() async {
        await dart([
          'run',
          'build_runner',
          'build',
          '--delete-conflicting-outputs',
        ]);
        return File('${directory.path}/lib/manager.g.dart').readAsString();
      }

      final initial = await generate();
      await dart(['analyze']);
      final execution = await dart(['run', 'lib/manager.dart']);
      expect(jsonDecode((execution.stdout as String).trim()), [
        'assets/images/logo.png',
        r'assets/cash$/price$usd.png',
        'assets/images/marketing/banner.png',
      ]);
      expect(await generate(), initial);
      await write('assets/images/added.png', '');
      expect(await generate(), contains('final String added'));
      await File(
        '${directory.path}/assets/images/added.png',
      ).rename('${directory.path}/assets/images/renamed.png');
      final renamed = await generate();
      expect(renamed, contains('final String renamed'));
      expect(renamed, isNot(contains('final String added')));
      await File('${directory.path}/assets/images/renamed.png').delete();
      expect(await generate(), initial);
      await dart(['analyze']);
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}
