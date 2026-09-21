import 'package:lazy_asset_generator/extension/extensions.dart';
import 'package:lazy_asset_generator/lazy_asset_generator.dart';
import 'package:lazy_asset_generator/lazy_asset_generator/lazy_asset_generator.dart';
import 'package:test/test.dart';

void main() {
  group('SanitizeIdentifier Extension', () {
    test('sanitizes standard image file names', () {
      expect('home_icon.png'.sanitizeIdentifier, equals('homeIcon'));
      expect('logo-main.png'.sanitizeIdentifier, equals('logoMain'));
    });

    test('sanitizes multi-dot filenames properly', () {
      expect('theme.dark.json'.sanitizeIdentifier, equals('themeDark'));
      expect('config.v1.prod.yaml'.sanitizeIdentifier, equals('configV1Prod'));
    });

    test('prepends underscore for leading digits', () {
      expect('24_hours.svg'.sanitizeIdentifier, equals('_24Hours'));
      expect('4k_wallpaper.jpg'.sanitizeIdentifier, equals('_4kWallpaper'));
    });

    test('handles hyphenated and space-separated names', () {
      expect('my-font sample.ttf'.sanitizeIdentifier, equals('myFontSample'));
    });

    test('appends Asset suffix to Dart keywords', () {
      expect('default.json'.sanitizeIdentifier, equals('defaultAsset'));
      expect('switch.mp3'.sanitizeIdentifier, equals('switchAsset'));
      expect('class.rive'.sanitizeIdentifier, equals('classAsset'));
    });

    test('handles empty or special string input gracefully', () {
      expect(''.sanitizeIdentifier, equals('_'));
      expect('.DS_Store'.sanitizeIdentifier, equals('dsStore'));
    });
  });

  group('StringHelper Extension', () {
    test('isAsset identifies valid asset filenames across formats', () {
      expect('assets/images/logo.png'.isAsset, isTrue);
      expect('assets/json/config.json'.isAsset, isTrue);
      expect('assets/fonts/custom.ttf'.isAsset, isTrue);
      expect('assets/audio/music.mp3'.isAsset, isTrue);
      expect('assets/animations/hero.rive'.isAsset, isTrue);
      expect('assets/animations/loader.lottie'.isAsset, isTrue);
      expect('assets/docs/manual.pdf'.isAsset, isTrue);
    });

    test('isAsset ignores hidden files', () {
      expect('.DS_Store'.isAsset, isFalse);
      expect('assets/images/.gitkeep'.isAsset, isFalse);
      expect(''.isAsset, isFalse);
    });

    test('capitalize upper-cases first character', () {
      expect('icons'.capitalize, equals('Icons'));
      expect(''.capitalize, equals(''));
    });
  });

  group('Library Export Safety', () {
    test('GenerateAssets annotation can be instantiated without mirrors', () {
      const annotation = GenerateAssets(
        folder: 'icons',
        folders: ['icons', 'images'],
        className: 'AppAssets',
        recursive: true,
      );
      expect(annotation.folder, equals('icons'));
      expect(annotation.folders, equals(['icons', 'images']));
      expect(annotation.className, equals('AppAssets'));
      expect(annotation.recursive, isTrue);
    });
  });

  group('AssetSourceGenerator', () {
    test('renders deterministic flat output', () {
      final source = AssetSourceGenerator.generate(
        inputFileName: 'asset_manager.dart',
        contextClassName: 'AssetManager',
        folders: ['images'],
        assetsByFolder: {
          'images': [
            'assets/images/z-last.png',
            'assets/images/a-first.png',
            'assets/images/.DS_Store',
          ],
        },
      );

      expect(source, contains("part of 'asset_manager.dart';"));
      expect(source, contains('abstract class _AssetManagerContext'));
      expect(
        source,
        contains(
            "static String images(String assetName) => 'assets/images/\$assetName';"),
      );
      expect(source, contains('final String aFirst'));
      expect(source, contains('final String zLast'));
      expect(source, isNot(contains('DS_Store')));
      expect(source.indexOf('aFirst'), lessThan(source.indexOf('zLast')));
    });

    test('mirrors nested directories when recursive is enabled', () {
      final source = AssetSourceGenerator.generate(
        inputFileName: 'asset_manager.dart',
        contextClassName: 'AssetManager',
        folders: ['images'],
        assetsByFolder: {
          'images': [
            'assets/images/marketing/banner-header.png',
            'assets/images/marketing/logo.svg',
          ],
        },
        recursive: true,
      );

      expect(
          source, contains('_ImagesMarketing marketing = _ImagesMarketing();'));
      expect(source, contains('final String bannerHeader'));
      expect(
        source,
        contains('AssetPath.images("marketing/banner-header.png")'),
      );
    });

    test('fails when sanitized identifiers collide', () {
      expect(
        () => AssetSourceGenerator.generate(
          inputFileName: 'asset_manager.dart',
          contextClassName: 'AssetManager',
          folders: ['images'],
          assetsByFolder: {
            'images': [
              'assets/images/logo.png',
              'assets/images/logo.svg',
            ],
          },
        ),
        throwsA(
          predicate<FormatException>(
            (error) =>
                error.message.contains('logo') &&
                error.message.contains('logo.png') &&
                error.message.contains('logo.svg'),
          ),
        ),
      );
    });

    test('fails when folder identifiers collide', () {
      expect(
        () => AssetSourceGenerator.generate(
          inputFileName: 'asset_manager.dart',
          contextClassName: 'AssetManager',
          folders: ['my-icons', 'my_icons'],
          assetsByFolder: {
            'my-icons': ['assets/my-icons/a.png'],
            'my_icons': ['assets/my_icons/b.png'],
          },
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects empty asset roots', () {
      expect(
        () => AssetSourceGenerator.generate(
          inputFileName: 'asset_manager.dart',
          contextClassName: 'AssetManager',
          folders: ['images'],
          assetsByFolder: const {'images': []},
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('uses the configured context class name', () {
      final source = AssetSourceGenerator.generate(
        inputFileName: 'asset_manager.dart',
        contextClassName: 'AppAssets',
        folders: ['images'],
        assetsByFolder: const {
          'images': ['assets/images/logo.png'],
        },
      );

      expect(source, contains('abstract class _AppAssetsContext'));
    });
  });
}
