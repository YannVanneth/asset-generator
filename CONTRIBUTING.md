# Contributing

## Local checks

Before opening a pull request, run:

```bash
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
dart pub publish --dry-run
```

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
