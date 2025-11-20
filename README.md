# 🖼 Lazy Asset Generator

A **Flutter/Dart code generator** that automatically creates **strongly-typed asset access classes** based on the folders you specify.  
No more manually typing long asset paths or worrying about typos — this generator produces a **clean, organized API** for your project’s assets.

--

## ✨ Features

- Scans asset folders listed in your `pubspec.yaml`.
- Generates a **strongly-typed asset context class**.
- Supports **single or multiple folders**.
- Outputs `.g.dart` files using **source_gen** & **build_runner**.
- Eliminates string-based asset paths.
- Provides **IDE auto-completion** for all assets.

---

## 📦 Installation

Add the annotation and generator to your `pubspec.yaml`:

```yaml
dependencies:
  lazy_asset_generator: ^1.3.1

dev_dependencies:
  build_runner: ^2.4.9
```

## 🧩 Usage

1. Add assets to your pubspec.yaml

```yaml
  assets:
    - assets/images/
    - assets/Icons/
    - assets/Illustrations/
```

2. Annotate an abstract class

```dart
// asset_manager.dart

@GenerateAssets(folders: ["Icons", "images", "Illustrations"])
class AssetManager {}
   ```


3. Running the Generator

    - run in terminal

   ```dart
   dart run build_runner build
   ```

    - Or watch mode:

   ```dart
   dart run build_runner watch
   ```

then it will generate :
```dart
// asset_manager.g.dart

part of 'asset_manager.dart';

class AssetPath {
  const AssetPath._();
  static String icons(String assetName) => 'assets/Icons/$assetName';
  static String images(String assetName) => 'assets/images/$assetName';
  static String illustrations(String assetName) =>
      'assets/Illustrations/$assetName';
}

abstract class _AssetManagerContext {
  _Icons icons = _Icons();
  _Images images = _Images();
  _Illustrations illustrations = _Illustrations();
}

class _Icons {
  /// generated content
  /// example
  final String cart = AssetPath.icons("Home.png");
}

class _Images {
  // generated content
}

class _Illustrations {
  // generated content
}
```


4. Extend the generated context class and add part 'asset_manager.g.dart';
```dart
// asset_manager.dart

part 'asset_manager.g.dart';

@GenerateAssets(folders: ["Icons", "images", "Illustrations"])
class AssetManager extends _AssetManagerContext {}

```

Now you can use your assets like this:

```dart
Image.asset(AssetManager().icons.home);
```

## 🤝 Contributing

Contributions are welcome!
Feel free to open issues or pull requests on the GitHub repo.

## 📄 License

MIT License — Use freely in personal and commercial projects.