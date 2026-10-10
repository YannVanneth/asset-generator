# Lazy Asset Generator

A Dart code generator for Flutter asset paths. It turns files under `assets/`
into typed string accessors with IDE autocomplete, so asset names are checked
at compile time.

```dart
final assets = AssetManager();
Image.asset(assets.images.marketing.banner);
```

The generator supports any file format, including images, SVGs, JSON, fonts,
audio, video, animations, and documents. It ignores hidden files and directories,
sorts output deterministically, and reports naming collisions instead of
silently overwriting accessors. Annotation imports are safe for Flutter mobile,
web, and desktop applications.

## Requirements

Dart 3.8 or later, or a Flutter SDK that includes Dart 3.8 or later.

## Installation

Add the annotation package as a dependency and `build_runner` as a development
dependency:

```yaml
dependencies:
  lazy_asset_generator: ^1.6.0

dev_dependencies:
  build_runner: ^2.8.0
```

Run `flutter pub get` for a Flutter project, or `dart pub get` for a Dart project.

## Quick start

### 1. Add and declare assets

For this example, create these files:

```text
assets/
  images/
    logo.png
    marketing/
      banner.png
  data/
    config.json
```

In a Flutter application, declare the directories in `pubspec.yaml` so Flutter
bundles the files. Include nested directories separately:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/images/marketing/
    - assets/data/
```

The generator scans `assets/` directly. It does not read or filter by
`pubspec.yaml`, and generating a path does not add the file to Flutter's bundle.

### 2. Create an asset manager

Create `lib/asset_manager.dart`:

```dart
import 'package:lazy_asset_generator/lazy_asset_generator.dart';

part 'asset_manager.g.dart';

@GenerateAssets(folders: ['images', 'data'], recursive: true)
class AssetManager extends _AssetManagerContext {}
```

Use one annotated manager per Dart library. Put additional managers in separate
libraries.

### 3. Generate the accessors

```bash
dart run build_runner build --delete-conflicting-outputs
```

For continuous generation while editing assets:

```bash
dart run build_runner watch
```

### 4. Use the generated paths

```dart
final assets = AssetManager();

Image.asset(assets.images.logo);
Image.asset(assets.images.marketing.banner);
final configPath = assets.data.config;
```

Accessors return `String` paths, so they work with `Image.asset`, SVG packages,
asset bundle loaders, audio players, and other APIs that accept asset paths.

## Configuration

| Option | Default | Behavior |
| --- | --- | --- |
| `folder` | `''` | Scan one relative directory under `assets/`. |
| `folders` | `[]` | Scan multiple relative directories; cannot be combined with `folder`. |
| `recursive` | `false` | Include nested files and generate groups matching their directory structure. |
| `className` | Annotated class name | Override the name used in `_<Name>Context`. |

For one folder:

```dart
@GenerateAssets(folder: 'images')
class AssetManager extends _AssetManagerContext {}
```

To discover folders automatically:

```dart
@GenerateAssets(recursive: true)
class AssetManager extends _AssetManagerContext {}
```

Automatic discovery groups visible directories immediately under `assets/`.
Without recursion, only roots with top-level files are included. With recursion,
roots containing only nested files are included too. Files directly under
`assets/` are not generated.

To override the context name, extend the corresponding generated context:

```dart
@GenerateAssets(folder: 'images', className: 'AppAssets')
class AssetManager extends _AppAssetsContext {}
```

Nested relative folders such as `images/marketing`, Windows separators, and
trailing slashes are supported. Absolute paths, `.` or `..` segments, and glob
patterns are rejected. Empty configured roots and empty entries in `folders`
produce generation errors.

## Naming and validation

Filenames become Dart identifiers after removing the final extension:

| Filename | Accessor |
| --- | --- |
| `home_icon.png` | `homeIcon` |
| `theme.dark.json` | `themeDark` |
| `24_hours.svg` | `_24Hours` |
| `default.json` | `defaultAsset` |

The current naming algorithm lowercases the first filename segment. For
predictable names, use separators such as underscores or hyphens between words.
Accessors beginning with `_` are private to the Dart library; use a letter at
the start of filenames when access is needed from other libraries.

Generation fails when files or folders produce the same accessor. For example,
`logo.png` and `logo.svg` in the same directory both produce `logo`. Rename one
of them, such as `logo_vector.svg`.

Names that conflict with inherited Dart members, generated helper/context
classes, or existing declarations in the manager's library also produce errors.
Avoid configuring overlapping roots when recursion is enabled, since they can
produce duplicate helper classes. Errors identify the conflicting name and source. Rename the asset, folder, or
existing declaration rather than editing generated files.

## Updating an existing project

The builder uses `source_gen` shared parts so other shared-part generators can
contribute to the same `.g.dart` file. Existing annotations, accessors, and
`part 'asset_manager.g.dart';` declarations stay the same.

After updating, regenerate old outputs:

```bash
dart run build_runner build --delete-conflicting-outputs
```

If you configure the builder explicitly, its identifier remains
`lazy_asset_generator:asset_builder`. Intermediate
`.lazy_asset_generator.g.part` files stay in the build cache; the combining
builder writes the final `.g.dart` file. Newer `build_runner` versions may report
that `--delete-conflicting-outputs` is ignored; the command still builds normally.

## Example and contributing

The [example project](example/) demonstrates recursive generation with included
assets. To run it:

```bash
cd example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart analyze
dart run lib/main.dart
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for development checks and the integration
test workflow. Report bugs or request features in
[GitHub issues](https://github.com/YannVanneth/asset-generator/issues).

## License

[MIT](LICENSE).
