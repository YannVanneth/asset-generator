import 'dart:io';

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:lazy_asset_generator/builder.dart';
import 'package:source_gen/builder.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

const _input = 'app|lib/manager.dart';
const _fragment = 'app|lib/manager.lazy_asset_generator.g.part';
const _output = 'app|lib/manager.g.dart';

String manager(
  String arguments, {
  String declarations = '',
  String name = 'AssetManager',
  String context = 'AssetManager',
}) =>
    '''
import 'package:lazy_asset_generator/lazy_asset_generator.dart';
part 'manager.g.dart';
@GenerateAssets($arguments)
class $name extends _${context}Context {}
$declarations
''';

Future<TestBuilderResult> build(
  Map<String, Object> sources, {
  Map<String, Object>? outputs,
  List<String>? logs,
  bool combine = false,
  bool companion = false,
}) async {
  final packageSources = {
    'lazy_asset_generator|lib/lazy_asset_generator.dart': await File(
      'lib/lazy_asset_generator.dart',
    ).readAsString(),
    'lazy_asset_generator|lib/lazy_asset_generator/annotations.dart':
        await File('lib/lazy_asset_generator/annotations.dart').readAsString(),
    ...sources,
  };
  return testBuilders(
    [
      assetFolderBuilder(BuilderOptions.empty),
      if (companion) SharedPartBuilder([_CompanionGenerator()], 'companion'),
      if (combine) combiningBuilder(BuilderOptions.empty),
    ],
    packageSources,
    rootPackage: 'app',
    generateFor: {_input},
    flattenOutput: true,
    outputs: outputs,
    onLog: (log) => logs?.add(log.message),
  );
}

class _CompanionGenerator extends Generator {
  @override
  String generate(LibraryReader library, BuildStep buildStep) =>
      'const companionValue = 42;';
}

void main() {
  test(
    'explicit folder produces a declaration fragment without part directive',
    () async {
      final result = await build(
        {_input: manager("folder: 'images'"), 'app|assets/images/logo.png': ''},
        outputs: {
          _fragment: decodedMatches(
            allOf(
              contains('abstract class _AssetManagerContext'),
              contains('final String logo'),
              isNot(contains('part of')),
            ),
          ),
        },
      );
      expect(result.succeeded, isTrue);
    },
  );

  test(
    'automatic discovery ignores hidden roots and nonrecursive descendants',
    () async {
      final result = await build(
        {
          _input: manager(''),
          'app|assets/images/logo.png': '',
          'app|assets/data/config.json': '',
          'app|assets/images/nested/banner.png': '',
          'app|assets/.private/secret.json': '',
        },
        outputs: {
          _fragment: decodedMatches(
            allOf(
              contains('final String logo'),
              contains('final String config'),
              isNot(contains('banner')),
              isNot(contains('secret')),
            ),
          ),
        },
      );
      expect(result.succeeded, isTrue);
    },
  );

  test(
    'recursive automatic discovery finds roots containing only nested files',
    () async {
      final result = await build(
        {
          _input: manager('recursive: true'),
          'app|assets/images/marketing/banner.png': '',
          'app|assets/images/.hidden/secret.png': '',
        },
        outputs: {
          _fragment: decodedMatches(
            allOf(
              contains('_ImagesMarketing'),
              contains('final String banner'),
              isNot(contains('secret')),
            ),
          ),
        },
      );
      expect(result.succeeded, isTrue);
    },
  );

  test(
    'normalizes nested Windows annotation paths and honors custom name',
    () async {
      final result = await build(
        {
          _input: manager(
            r"folder: r'images\marketing\', className: 'AppAssets'",
            context: 'AppAssets',
          ),
          'app|assets/images/marketing/banner.png': '',
        },
        outputs: {
          _fragment: decodedMatches(
            allOf(
              contains('_AppAssetsContext'),
              contains('assets/images/marketing/'),
            ),
          ),
        },
      );
      expect(result.succeeded, isTrue);
    },
  );

  test('unannotated libraries do not generate output', () async {
    final result = await build({_input: 'class Unannotated {}'}, outputs: {});
    expect(result.succeeded, isTrue);
  });

  test(
    'combines with another shared-part generator in the same g.dart',
    () async {
      final result = await build(
        {_input: manager("folder: 'images'"), 'app|assets/images/logo.png': ''},
        combine: true,
        companion: true,
      );
      expect(result.succeeded, isTrue);
      final output = result.readerWriter.testing.readString(
        AssetId.parse(_output),
      );
      expect(output, contains("part of 'manager.dart';"));
      expect(output, contains('final String logo'));
      expect(output, contains('const companionValue = 42;'));
      expect('part of'.allMatches(output), hasLength(1));
    },
  );

  final invalidCases = <String, (String, String)>{
    'both folder options': (
      manager("folder: 'images', folders: ['images']"),
      'both',
    ),
    'empty entry': (manager("folders: ['']"), 'Invalid asset folder'),
    'traversal': (manager("folder: 'images/../icons'"), 'Invalid asset folder'),
    'absolute path': (manager("folder: '/images'"), 'Invalid asset folder'),
    'glob': (manager("folder: 'images/*'"), 'Invalid asset folder'),
    'reserved context': (
      manager("folder: 'images', className: 'class'"),
      'Invalid className',
    ),
    'multiple managers': (
      manager(
        "folder: 'images'",
        declarations: "@GenerateAssets(folder: 'images') class Other {}",
      ),
      'Only one',
    ),
    'non-class target': (
      "import 'package:lazy_asset_generator/lazy_asset_generator.dart'; @GenerateAssets(folder: 'images') void function() {}",
      'must annotate a class',
    ),
    'existing path utility': (
      manager("folder: 'images'", declarations: 'class AssetPath {}'),
      "declaration 'AssetPath'",
    ),
    'existing helper': (
      manager("folder: 'images'", declarations: 'class _Images {}'),
      "declaration '_Images'",
    ),
    'existing context': (
      manager(
        "folder: 'images'",
        declarations: 'class _AssetManagerContext {}',
      ),
      "declaration '_AssetManagerContext'",
    ),
  };
  for (final entry in invalidCases.entries) {
    test('reports ${entry.key} at the annotation source', () async {
      final logs = <String>[];
      final result = await build({
        _input: entry.value.$1,
        'app|assets/images/logo.png': '',
      }, logs: logs);
      expect(result.succeeded, isFalse);
      expect(logs.join('\n'), contains(entry.value.$2));
      expect(logs.join('\n'), contains('manager.dart'));
    });
  }

  test('empty roots and filename collisions report useful errors', () async {
    for (final paths in [
      <String>[],
      ['assets/images/logo.png', 'assets/images/logo.svg'],
    ]) {
      final logs = <String>[];
      final result = await build({
        _input: manager("folder: 'images'"),
        for (final path in paths) 'app|$path': '',
      }, logs: logs);
      expect(result.succeeded, isFalse);
      expect(
        logs.join('\n'),
        contains(paths.isEmpty ? 'No visible assets' : 'logo.svg'),
      );
    }
  });

  test(
    'declarations in a user-written part also participate in collision checks',
    () async {
      final logs = <String>[];
      final result = await build({
        _input: manager("folder: 'images'").replaceFirst(
          "part 'manager.g.dart';",
          "part 'manager.g.dart';\npart 'manual.dart';",
        ),
        'app|lib/manual.dart': "part of 'manager.dart'; class AssetPath {}",
        'app|assets/images/logo.png': '',
      }, logs: logs);
      expect(result.succeeded, isFalse);
      expect(logs.join('\n'), contains("declaration 'AssetPath'"));
    },
  );
}
