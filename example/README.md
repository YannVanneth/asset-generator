# Example

This example demonstrates recursive generation across multiple asset folders.

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
