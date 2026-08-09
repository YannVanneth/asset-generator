import 'package:lazy_asset_generator/extension/extensions.dart';
import 'package:lazy_asset_generator/lazy_asset_generator.dart';
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
      );
      expect(annotation.folder, equals('icons'));
      expect(annotation.folders, equals(['icons', 'images']));
      expect(annotation.className, equals('AppAssets'));
    });
  });
}
