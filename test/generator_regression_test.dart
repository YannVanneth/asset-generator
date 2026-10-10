import 'dart:convert';
import 'dart:io';

import 'package:lazy_asset_generator/lazy_asset_generator/lazy_asset_generator.dart';
import 'package:test/test.dart';

String render(
  List<String> paths, {
  String folder = 'images',
  String name = 'Assets',
  bool recursive = false,
}) => AssetSourceGenerator.generate(
  inputFileName: 'consumer.dart',
  contextClassName: name,
  folders: [folder],
  assetsByFolder: {folder: paths},
  recursive: recursive,
);

void main() {
  group('Invalid generation inputs', () {
    for (final folder in [
      '',
      '.',
      '..',
      '../images',
      'images/../icons',
      '/images',
      r'C:\images',
      'C:images',
      'images/*',
      'images/?',
      'images/[a]',
      'images/{a,b}',
    ]) {
      test('rejects folder $folder before normalization', () {
        expect(
          () => render(['assets/$folder/logo.png'], folder: folder),
          throwsFormatException,
        );
      });
    }
    for (final name in [
      '',
      '_',
      'class',
      'abstract',
      '9Assets',
      'App-Assets',
    ]) {
      test('rejects context name $name', () {
        expect(
          () => render(['assets/images/logo.png'], name: name),
          throwsFormatException,
        );
      });
    }
    for (final filename in [
      'hash_code.png',
      'runtime_type.png',
      'to_string.png',
      'no_such_method.png',
    ]) {
      test('rejects inherited member from $filename', () {
        expect(
          () => render(['assets/images/$filename']),
          throwsA(
            predicate<FormatException>(
              (error) => error.message.contains('inherited Dart member'),
            ),
          ),
        );
      });
    }
    test('rejects inherited member as root and nested folder', () {
      expect(
        () => render(['assets/hash_code/a.png'], folder: 'hash_code'),
        throwsFormatException,
      );
      expect(
        () => render(['assets/images/to_string/a.png'], recursive: true),
        throwsFormatException,
      );
    });
    test('rejects file and directory accessor collision', () {
      expect(
        () => render([
          'assets/images/marketing.png',
          'assets/images/marketing/banner.png',
        ], recursive: true),
        throwsFormatException,
      );
    });
    test('rejects helper class collision with context', () {
      expect(
        () => render(
          ['assets/images_context/a.png'],
          folder: 'images_context',
          name: 'Images',
        ),
        throwsFormatException,
      );
    });
    test('rejects flattened helper class collisions across trees', () {
      expect(
        () => AssetSourceGenerator.generate(
          inputFileName: 'consumer.dart',
          contextClassName: 'Assets',
          folders: ['a', 'a_b'],
          assetsByFolder: {
            'a': ['assets/a/b/logo.png'],
            'a_b': ['assets/a_b/logo.png'],
          },
          recursive: true,
        ),
        throwsFormatException,
      );
    });
    test('rejects duplicate helper classes from overlapping roots', () {
      expect(
        () => AssetSourceGenerator.generate(
          inputFileName: 'consumer.dart',
          contextClassName: 'Assets',
          folders: ['images', 'images/marketing'],
          assetsByFolder: {
            'images': ['assets/images/marketing/banner.png'],
            'images/marketing': ['assets/images/marketing/banner.png'],
          },
          recursive: true,
        ),
        throwsFormatException,
      );
    });
    test('rejects asset outside its configured root', () {
      expect(() => render(['assets/icons/logo.png']), throwsFormatException);
    });
  });

  test('numeric folders and filenames keep distinct helper names', () {
    final source = render(['assets/24/24.png'], folder: '24');
    expect(source, contains('class __24'));
    expect(source, contains('final String _24'));
  });

  test('renders identical output for reordered and duplicate paths', () {
    final paths = [
      'assets/images/z/b.png',
      'assets/images/a.png',
      'assets/images/z/a.png',
    ];
    expect(
      render(paths, recursive: true),
      render([...paths.reversed, paths.first], recursive: true),
    );
  });

  test('excludes hidden directories as well as hidden files', () {
    final source = render([
      'assets/images/logo.png',
      'assets/images/.hidden/private.png',
      'assets/images/.keep',
    ], recursive: true);
    expect(source, contains('logo'));
    expect(source, isNot(contains('private')));
    expect(source, isNot(contains('keep')));
  });

  test('normalizes supported folder separators and trailing slash', () {
    // Renderer callers supply canonical map keys; the builder normalizes annotation paths.
    final output = AssetSourceGenerator.generate(
      inputFileName: 'consumer.dart',
      contextClassName: 'Assets',
      folders: [r'images\marketing\'],
      assetsByFolder: {
        'images/marketing': ['assets/images/marketing/banner.png'],
      },
    );
    expect(output, contains('assets/images/marketing/'));
  });

  test('generated Dart executes and preserves escaped path values', () async {
    final directory = await Directory.systemTemp.createTemp(
      'asset-generator-render-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final folder = 'cash\$';
    final paths = [
      'assets/$folder/price\$usd.png',
      'assets/$folder/single\'quote.png',
      'assets/$folder/double"quote.png',
      'assets/$folder/line\nfeed.png',
      'assets/$folder/tab\tstop.png',
      'assets/$folder/control\u0001.png',
      'assets/$folder/carriage\rreturn.png',
      'assets/$folder/form\ffeed.png',
      'assets/$folder/back\bspace.png',
      'assets/$folder/literal\\backslash.png',
    ];
    final output = render(paths, folder: folder);
    await File('${directory.path}/consumer.g.dart').writeAsString(output);
    await File('${directory.path}/consumer.dart').writeAsString('''
import 'dart:convert';
part 'consumer.g.dart';
class Assets extends _AssetsContext {}
void main() {
  final assets = Assets();
  print(jsonEncode([
    assets.cash.priceUsd, assets.cash.singleQuote, assets.cash.doubleQuote,
    assets.cash.lineFeed, assets.cash.tabStop, assets.cash.control,
    assets.cash.carriageReturn, assets.cash.formFeed, assets.cash.backSpace,
    assets.cash.literalBackslash,
    AssetPath.cash('literal\\\\backslash.png'),
  ]));
}
''');
    final result = await Process.run(Platform.resolvedExecutable, [
      '${directory.path}/consumer.dart',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(jsonDecode((result.stdout as String).trim()), [
      ...paths,
      'assets/$folder/literal\\backslash.png',
    ]);
  });
}
