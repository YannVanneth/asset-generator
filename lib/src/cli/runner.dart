import 'dart:io';

import 'package:lazy_asset_generator/src/cli/watcher.dart';
import 'package:lazy_asset_generator/src/ffi/native_bindings.dart';
import 'package:lazy_asset_generator/src/parser/annotation_parser.dart';
import 'package:path/path.dart' as p;

/// Main CLI runner for `lazy_asset_generator`.
class CliRunner {
  final NativeAssetEngine _nativeEngine = NativeAssetEngine();

  /// Runs the CLI with [args]. Returns exit code (0 for success).
  Future<int> run(List<String> args) async {
    var watchMode = false;
    var forceDart = false;
    var verbose = false;
    var projectRoot = Directory.current.path;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--watch' || arg == '-w') {
        watchMode = true;
      } else if (arg == '--force-dart') {
        forceDart = true;
      } else if (arg == '--verbose' || arg == '-v') {
        verbose = true;
      } else if (arg.startsWith('--path=')) {
        projectRoot = p.normalize(p.absolute(arg.substring('--path='.length)));
      } else if (arg == '--path') {
        if (i + 1 < args.length) {
          projectRoot = p.normalize(p.absolute(args[++i]));
        } else {
          stderr.writeln('[ERROR] Missing value for --path argument.');
          return 1;
        }
      } else if (arg == '--help' || arg == '-h') {
        _printHelp();
        return 0;
      } else {
        stderr.writeln('[ERROR] Unrecognized argument: $arg');
        _printHelp();
        return 1;
      }
    }

    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (!libDir.existsSync()) {
      stderr.writeln('[ERROR] Directory "lib/" not found in $projectRoot.');
      return 1;
    }

    final configs = AnnotationParser.scanDirectory(libDir.path);
    if (configs.isEmpty) {
      stdout.writeln('[INFO] No @GenerateAssets annotations found in lib/.');
      return 0;
    }

    final engineName = (!forceDart && _nativeEngine.isAvailable)
        ? 'Rust Native FFI'
        : 'Pure Dart';
    if (verbose) {
      stdout.writeln('[INFO] Using $engineName engine for $projectRoot');
    }

    // Perform initial generation
    final success = _generateAll(projectRoot, configs, forceDart: forceDart, verbose: verbose);
    if (!success && !watchMode) {
      return 1;
    }

    if (watchMode) {
      final watcher = AssetWatcher(
        projectRoot: projectRoot,
        nativeEngine: _nativeEngine,
        forceDart: forceDart,
        verbose: verbose,
      );
      await watcher.start();
    }

    return 0;
  }

  bool _generateAll(
    String projectRoot,
    List<AssetConfig> configs, {
    required bool forceDart,
    required bool verbose,
  }) {
    var allSucceeded = true;
    for (final config in configs) {
      final sw = Stopwatch()..start();
      try {
        _nativeEngine.generate(
          projectRoot: projectRoot,
          config: config,
          writeToFile: true,
          forceDart: forceDart,
        );
        sw.stop();
        stdout.writeln(
          '[INFO] Generated ${config.outputFilePath} (${sw.elapsedMilliseconds}ms)',
        );
      } catch (e) {
        allSucceeded = false;
        stderr.writeln(
          '[ERROR] Failed to generate ${config.outputFilePath}: $e',
        );
      }
    }
    return allSucceeded;
  }

  void _printHelp() {
    stdout.writeln('''
Lazy Asset Generator CLI

Usage: dart run lazy_asset_generator [options]

Options:
  -w, --watch        Start continuous file watcher daemon
      --force-dart   Force pure Dart engine (bypass Rust FFI)
  -v, --verbose      Enable detailed logs
      --path <path>  Target project root (defaults to current directory)
  -h, --help         Show this help message
''');
  }
}
