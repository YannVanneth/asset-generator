# 🖼 Lazy Asset Generator

[![pub package](https://img.shields.io/pub/v/lazy_asset_generator.svg)](https://pub.dev/packages/lazy_asset_generator)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Maintained with Antigravity](https://img.shields.io/badge/Maintained%20with-Google%20Antigravity-4285F4?style=flat&logo=google)](https://github.com/google/antigravity)

A **Flutter & Dart code generator** that automatically creates **strongly-typed asset access classes** based on your project's asset directories.

No more typing error-prone string paths like `"assets/icons/home_icon_24px.png"` manually — this generator produces a **clean, organized, type-safe API** with instant **IDE auto-completion**.

> 🚀 **Maintained with [Google Antigravity](https://github.com/google/antigravity)**

---

## ✨ Key Features

- 📁 **Universal Asset Support**: Supports images (`.png`, `.jpg`, `.webp`), vectors (`.svg`), data (`.json`, `.yaml`), fonts (`.ttf`, `.otf`), audio (`.mp3`, `.wav`), animations (`.rive`, `.lottie`), documents (`.pdf`), and more.
- ⚡ **Auto-Sanitization**: Converts filenames into valid Dart identifiers (`theme.dark.json` -> `themeDark`, `24_hours.svg` -> `_24Hours`, `default.json` -> `defaultAsset`).
- 🛡️ **Hidden File Filtering**: Automatically ignores OS system files like `.DS_Store` or `.gitkeep`.
- 🚀 **Zero Reflection (`dart:mirrors`)**: Fully compatible with Flutter mobile, web, and desktop builds.
- 💡 **IDE Auto-Completion**: Get autocomplete for all assets across single or multiple folders.

---

## 📂 Supported Asset Formats

| Category | Extensions |
| :--- | :--- |
| **Images & Vectors** | `.png`, `.jpg`, `.jpeg`, `.webp`, `.gif`, `.svg` |
| **Data & Configs** | `.json`, `.yaml`, `.yml`, `.xml` |
| **Fonts & Typography** | `.ttf`, `.otf` |
| **Audio & Video** | `.mp3`, `.wav`, `.aac`, `.mp4` |
| **Animations & Vectors** | `.rive`, `.lottie`, `.tgs` |
| **Documents & Other** | `.pdf`, `.txt`, and any custom format |

---

## 📦 Installation

Add `lazy_asset_generator` and `build_runner` to your `pubspec.yaml`:

```yaml
dependencies:
  lazy_asset_generator: ^1.4.1

dev_dependencies:
  build_runner: ^2.4.13
```

Run `flutter pub get` or `dart pub get`.

---

## 🧩 Quick Start

### 1. Declare assets in your `pubspec.yaml`

```yaml
flutter:
  assets:
    - assets/Icons/
    - assets/images/
    - assets/json/
```

### 2. Annotate your asset manager class

Create a file `lib/asset_manager.dart`:

```dart
import 'package:lazy_asset_generator/lazy_asset_generator.dart';

part 'asset_manager.g.dart';

@GenerateAssets(folders: ["Icons", "images", "json"])
class AssetManager extends _AssetManagerContext {}
```

For nested folders, enable recursive generation. The generated helper groups
mirror the directory structure below each configured folder:

```dart
@GenerateAssets(folders: ["images"], recursive: true)
class AssetManager extends _AssetManagerContext {}
```

### 3. Run the generator

Execute build_runner in your terminal:

```bash
dart run build_runner build
```

Or enable watch mode for continuous generation:

```bash
dart run build_runner watch
```

### 4. Use your strongly-typed assets anywhere!

```dart
import 'package:flutter/material.dart';
import 'asset_manager.dart';

Widget buildUI() {
  final assets = AssetManager();

  return Column(
    children: [
      Image.asset(assets.icons.home),
      Image.asset(assets.images.bannerHeader),
      // Use json, audio, fonts, lottie, etc.
      Text(assets.json.configDark),
    ],
  );
}
```

With `recursive: true`, an asset at `assets/images/marketing/banner.png` is
available as `assets.images.marketing.banner`.

The generator sorts its output and rejects files or folders that sanitize to
the same Dart identifier. For example, `logo.png` and `logo.svg` in one group
produce a clear generation error instead of silently overwriting an accessor.

If the generated context needs a different name, use `className` and extend
the corresponding generated context:

```dart
@GenerateAssets(folder: "images", className: "AppAssets")
class AssetManager extends _AppAssetsContext {}
```
---

## 💡 Before & After

### ❌ Before (Unsafe & Typo-Prone)
```dart
Image.asset('assets/Icons/Home_icon.png'); // Typo in string? Runtime crash!
```

### ✅ After (Type-Safe & Auto-Completed)
```dart
Image.asset(AssetManager().icons.homeIcon); // Checked at compile time!
```

---

## 🤝 Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for local
checks, the end-to-end example, and pull request guidelines. You can also open
issues on the [GitHub Repository](https://github.com/YannVanneth/asset-generator).

### Example project

The [`example/`](example/) project demonstrates recursive generation and can be
run with `dart run build_runner build --delete-conflicting-outputs`.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE) — feel free to use it in personal and commercial projects.
