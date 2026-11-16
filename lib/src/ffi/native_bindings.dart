import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:lazy_asset_generator/src/generator/dart_asset_generator.dart';
import 'package:lazy_asset_generator/src/parser/annotation_parser.dart';
import 'package:path/path.dart' as p;

typedef _GenerateNative =
    Pointer<Utf8> Function(Pointer<Utf8> root, Pointer<Utf8> configJson);
typedef _GenerateDart =
    Pointer<Utf8> Function(Pointer<Utf8> root, Pointer<Utf8> configJson);

typedef _FreeStringNative = Void Function(Pointer<Utf8> ptr);
typedef _FreeStringDart = void Function(Pointer<Utf8> ptr);

/// High-performance asset generator backed by the native Rust engine via FFI.
///
/// Seamlessly falls back to [DartAssetGenerator] if the native engine is not
/// compiled and Cargo is not available.
class NativeAssetEngine {
  DynamicLibrary? _dylib;
  _GenerateDart? _generateFn;
  _FreeStringDart? _freeStringFn;
  bool _initialized = false;
  String? _loadError;

  /// Whether the native Rust engine is loaded and available.
  bool get isAvailable {
    _ensureInitialized();
    return _dylib != null && _generateFn != null && _freeStringFn != null;
  }

  /// Explanation if native loading failed.
  String? get loadError {
    _ensureInitialized();
    return _loadError;
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;

    try {
      final libFile = _findOrBuildLibrary();
      if (libFile != null && libFile.existsSync()) {
        final dylib = DynamicLibrary.open(libFile.path);
        _generateFn = dylib.lookupFunction<_GenerateNative, _GenerateDart>(
          'lazy_asset_generate',
        );
        _freeStringFn = dylib
            .lookupFunction<_FreeStringNative, _FreeStringDart>(
              'lazy_asset_free_string',
            );
        _dylib = dylib;
      } else {
        _loadError = 'Native library not found and could not be built.';
      }
    } catch (e) {
      _loadError = 'Failed to load native library: $e';
    }
  }

  /// Resolves the root directory of the `lazy_asset_generator` package.
  static String? resolvePackageRoot([String? startDir]) {
    var current = Directory(startDir ?? Directory.current.path);
    while (true) {
      final configJson = File(
        p.join(current.path, '.dart_tool', 'package_config.json'),
      );
      if (configJson.existsSync()) {
        try {
          final data =
              jsonDecode(configJson.readAsStringSync()) as Map<String, dynamic>;
          final packages = data['packages'] as List<dynamic>?;
          if (packages != null) {
            for (final pkg in packages) {
              if (pkg is Map<String, dynamic> &&
                  pkg['name'] == 'lazy_asset_generator') {
                final rootUriStr = pkg['rootUri'] as String;
                final resolvedUri = configJson.uri.resolve(rootUriStr);
                return p.normalize(resolvedUri.toFilePath());
              }
            }
          }
        } catch (_) {}
      }

      final pubspec = File(p.join(current.path, 'pubspec.yaml'));
      if (pubspec.existsSync()) {
        try {
          final content = pubspec.readAsStringSync();
          if (content.contains('name: lazy_asset_generator')) {
            return current.path;
          }
        } catch (_) {}
      }

      final parent = current.parent;
      if (parent.path == current.path) break;
      current = parent;
    }

    if (Platform.script.scheme == 'file') {
      try {
        final scriptPath = Platform.script.toFilePath();
        final scriptDir = Directory(p.dirname(scriptPath));
        if (File(p.join(scriptDir.parent.path, 'pubspec.yaml')).existsSync()) {
          return scriptDir.parent.path;
        }
      } catch (_) {}
    }

    return null;
  }

  File? _findOrBuildLibrary() {
    final libName = _libraryFileName;
    final packageRoot = resolvePackageRoot();

    final candidates = <String>[];
    if (packageRoot != null) {
      candidates.add(
        p.join(packageRoot, 'native', 'target', 'release', libName),
      );
      candidates.add(p.join(packageRoot, '.dart_tool', 'native', libName));
    }
    candidates.add(
      p.join(Directory.current.path, 'native', 'target', 'release', libName),
    );
    candidates.add(
      p.join(Directory.current.path, '.dart_tool', 'native', libName),
    );

    for (final candidate in candidates) {
      final file = File(p.normalize(candidate));
      if (file.existsSync()) return file;
    }

    // Try auto-compiling if Cargo is present at packageRoot or current directory
    final rootForCargo = packageRoot ?? Directory.current.path;
    final cargoToml = File(p.join(rootForCargo, 'native', 'Cargo.toml'));
    if (cargoToml.existsSync()) {
      try {
        final check = Process.runSync('cargo', ['--version']);
        if (check.exitCode == 0) {
          final build = Process.runSync('cargo', [
            'build',
            '--release',
            '--manifest-path',
            cargoToml.path,
          ]);
          if (build.exitCode == 0) {
            final builtFile = File(
              p.join(rootForCargo, 'native', 'target', 'release', libName),
            );
            if (builtFile.existsSync()) return builtFile;
          }
        }
      } catch (_) {
        // Auto-compile failed; will fall back to Dart
      }
    }

    return null;
  }

  static String get _libraryFileName {
    if (Platform.isLinux) return 'liblazy_asset_core.so';
    if (Platform.isMacOS) return 'liblazy_asset_core.dylib';
    if (Platform.isWindows) return 'lazy_asset_core.dll';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  /// Generates code for [config] using Rust native engine, or pure Dart fallback.
  String generate({
    required String projectRoot,
    required AssetConfig config,
    bool writeToFile = true,
    bool forceDart = false,
  }) {
    if (forceDart || !isAvailable) {
      return DartAssetGenerator.generate(
        projectRoot: projectRoot,
        config: config,
        writeToFile: writeToFile,
      );
    }

    final rootUtf8 = projectRoot.toNativeUtf8();
    final jsonStr = jsonEncode(config.toJson());
    final jsonUtf8 = jsonStr.toNativeUtf8();

    Pointer<Utf8>? resultPtr;
    try {
      resultPtr = _generateFn!(rootUtf8, jsonUtf8);
      final resultStr = resultPtr.toDartString();

      if (resultStr.startsWith('__ERROR__: ')) {
        final errorMsg = resultStr.substring('__ERROR__: '.length);
        throw FormatException(errorMsg);
      }

      if (writeToFile) {
        final outFile = File(p.join(projectRoot, config.outputFilePath));
        outFile.parent.createSync(recursive: true);
        outFile.writeAsStringSync(resultStr);
      }

      return resultStr;
    } finally {
      malloc.free(rootUtf8);
      malloc.free(jsonUtf8);
      if (resultPtr != null && _freeStringFn != null) {
        _freeStringFn!(resultPtr);
      }
    }
  }
}
