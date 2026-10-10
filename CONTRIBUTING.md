# Contributing

## Local checks

Use Dart 3.8 or later. CI tests both Dart 3.8.0 and stable; formatting and
publication validation use stable. Before opening a pull request, run:

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart pub publish --dry-run
```

The test suite includes a clean temporary consumer package. It resolves dependencies
from the local pub cache (`dart pub get --offline`), then builds, analyzes, executes,
and checks incremental updates. Run `dart pub get` first to populate the cache.

To verify the end-to-end example:

```bash
cd example
dart pub get
dart run build_runner build --delete-conflicting-outputs
dart run lib/main.dart
```

Generated files under `example/lib/` are ignored. Do not commit build output,
`.dart_tool/`, or generated example files.

## Pull requests

- Keep public API changes documented in `README.md`.
- Add or update tests for behavior changes.
- Update `CHANGELOG.md` under `Unreleased`.
- Keep commits focused and explain migration requirements when applicable.
