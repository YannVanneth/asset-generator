# Example

This example demonstrates recursive generation across multiple asset folders.
Use Dart 3.8 or later. The included banner is a small PNG fixture.

The generator scans `assets/` directly. In a Flutter application, declare the
nested `assets/images/marketing/` directory (or the banner file) separately to
bundle it; the example itself is a Dart command-line program.

From the repository root, run:

```bash
cd example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run lib/main.dart
```

The generated API includes:

```dart
AssetManager().images.marketing.banner;
AssetManager().data.config;
```
