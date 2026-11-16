import 'dart:async';
import 'dart:io';

import 'package:lazy_asset_generator/src/ffi/native_bindings.dart';
import 'package:lazy_asset_generator/src/parser/annotation_parser.dart';
import 'package:path/path.dart' as p;

/// Continuous filesystem watcher for assets and annotations.
class AssetWatcher {
  final String projectRoot;
  final NativeAssetEngine nativeEngine;
  final bool forceDart;
  final bool verbose;

  Timer? _debounceTimer;
  final Completer<void> _doneCompleter = Completer<void>();
  final List<StreamSubscription> _subscriptions = [];

  AssetWatcher({
    required this.projectRoot,
    required this.nativeEngine,
    this.forceDart = false,
    this.verbose = false,
  });

  /// Starts watching `assets/` and `lib/`.
  Future<void> start() async {
    stdout.writeln(
      '[WATCH] Watching assets/ and lib/ for changes... (Press Ctrl+C to stop)',
    );

    final assetsDir = Directory(p.join(projectRoot, 'assets'));
    if (assetsDir.existsSync()) {
      _watchRecursively(assetsDir);
    } else {
      stdout.writeln(
        '[WATCH WARNING] assets/ directory not found in $projectRoot.',
      );
    }

    final libDir = Directory(p.join(projectRoot, 'lib'));
    if (libDir.existsSync()) {
      _watchRecursively(libDir);
    }

    // Handle process signals for graceful exit
    ProcessSignal.sigint.watch().listen((_) => stop());
    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) => stop());
    }

    await _doneCompleter.future;
  }

  void _watchRecursively(Directory dir) {
    _subscriptions.add(dir.watch().listen(_onFileSystemEvent));
    try {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!name.startsWith('.')) {
            _watchRecursively(entity);
          }
        }
      }
    } catch (_) {}
  }

  void _onFileSystemEvent(FileSystemEvent event) {
    final eventPath = p.normalize(event.path);

    // If a new directory was created, watch it too
    if (event.type == FileSystemEvent.create &&
        FileSystemEntity.isDirectorySync(eventPath)) {
      _watchRecursively(Directory(eventPath));
    }

    // Ignore generated .g.dart files to prevent infinite loops
    if (eventPath.endsWith('.g.dart')) return;

    // Ignore hidden files and directories (.git, .dart_tool, etc.)
    final segments = eventPath.split(p.separator);
    if (segments.any((s) => s.startsWith('.'))) return;

    // Debounce to batch multiple rapid operations (e.g. multi-file drops)
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _regenerate(eventPath);
    });
  }

  void _regenerate(String triggerPath) {
    final relPath = p.relative(triggerPath, from: projectRoot);
    final sw = Stopwatch()..start();

    try {
      final libDir = Directory(p.join(projectRoot, 'lib'));
      final configs = AnnotationParser.scanDirectory(libDir.path);

      for (final config in configs) {
        nativeEngine.generate(
          projectRoot: projectRoot,
          config: config,
          writeToFile: true,
          forceDart: forceDart,
        );
      }
      sw.stop();
      stdout.writeln(
        '[WATCH] $relPath changed -> Regenerated in ${sw.elapsedMilliseconds}ms',
      );
    } catch (e) {
      stderr.writeln(
        '[WATCH ERROR] Failed to regenerate on $relPath change: $e',
      );
    }
  }

  /// Stops the watcher.
  void stop() {
    _debounceTimer?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    stdout.writeln('\n[WATCH] Stopped.');
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }
}
