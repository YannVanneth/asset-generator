# Standalone CLI & Asset Watcher with Rust FFI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide a high-performance standalone CLI (`dart run lazy_asset_generator`) and watcher (`--watch`) using a Rust native engine via `dart:ffi` with an automatic pure Dart fallback.

**Architecture:** A Dart CLI entry point scans annotations in `lib/` using AST parsing. If the Rust dynamic library is available (or can be auto-compiled with `cargo`), it delegates generation and watching to the Rust engine via C-ABI; otherwise, it seamlessly falls back to the pure Dart `AssetSourceGenerator`.

**Tech Stack:** Dart 3.8+ (`dart:ffi`, `package:analyzer`, `package:ffi`), Rust (2021 edition, `walkdir`, `serde`, `serde_json`, `notify`).

**Spec:** `docs/superpowers/specs/2026-11-16-standalone-cli-watcher-design.md`

## Global Constraints
- Dart SDK floor: `>=3.8.0 <4.0.0`.
- Safe memory handling across FFI boundary: all strings returned by Rust must be freed via `lazy_asset_free_string`.
- 100% backward compatibility: existing `build_runner` and `build.yaml` pipelines must not be modified or broken.
- Pure Dart fallback: if `cargo` is missing or Rust compilation fails, generation must succeed using the pure Dart engine.

## Review Focus
1. Memory leaks across FFI boundary -> verify Rust strings are safely allocated via `CString` and freed via Dart FFI deallocator.
2. Infinite watch loop -> ensure watcher ignores changes to `.g.dart` files.
3. Path separator normalization on Windows -> verify all asset paths in generated Dart code use forward slashes (`/`).
4. Missing directories (`assets/` or `lib/`) -> CLI must fail gracefully with a clean user-facing error message instead of an unhandled exception.
5. Concurrent rapid filesystem events -> verify debounce logic aggregates multiple file copy/paste events into a single generation run.

---

### Task 1: Package Configuration & Rust Crate Scaffolding

**Files:**
- Modify: `pubspec.yaml`
- Create: `native/Cargo.toml`
- Create: `native/src/lib.rs`

**Interfaces:**
- Consumes: None
- Produces: `package:ffi` in Dart, Rust cdylib crate `lazy_asset_core`

- [ ] **Step 1: Write the failing test**
Run command to verify `native/Cargo.toml` and `package:ffi` are not yet configured:
```bash
cargo check --manifest-path native/Cargo.toml
```
Expected: FAIL (No such file or directory)

- [ ] **Step 2: Add `ffi` dependency and executable to `pubspec.yaml`**
Add `ffi: ^2.1.3` under `dependencies` and declare `executables: lazy_asset_generator:` in `pubspec.yaml`.

- [ ] **Step 3: Create `native/Cargo.toml`**
Configure crate `lazy_asset_core` with `crate-type = ["cdylib", "rlib"]`, edition 2021, and dependencies:
- `walkdir = "2.5"`
- `serde = { version = "1.0", features = ["derive"] }`
- `serde_json = "1.0"`

- [ ] **Step 4: Create placeholder `native/src/lib.rs`**
Expose a dummy C-ABI function `pub extern "C" fn lazy_asset_ping() -> i32 { 42 }`.

- [ ] **Step 5: Verify Rust compilation and Dart dependencies**
Run:
```bash
dart pub get && cargo check --manifest-path native/Cargo.toml
```
Expected: PASS

- [ ] **Step 6: Commit**
```bash
git add pubspec.yaml pubspec.lock native/Cargo.toml native/src/lib.rs
git commit -m "chore: scaffold native crate and add ffi dependency"
```

---

### Task 2: Rust Native Asset Generation Engine

**Files:**
- Create: `native/src/scanner.rs`
- Create: `native/src/generator.rs`
- Create: `native/src/ffi.rs`
- Modify: `native/src/lib.rs`

**Interfaces:**
- Consumes: `project_path: *const c_char`, `config_json: *const c_char`
- Produces: `lazy_asset_generate`, `lazy_asset_free_string` exported C-ABI functions

- [ ] **Step 1: Write failing Rust unit test in `native/src/generator.rs`**
Add unit test `test_code_generation` verifying formatted Dart accessor string from sample folder tree:
```rust
#[test]
fn test_code_generation() {
    let output = generate_dart_code("lib/asset_manager.dart", "AssetManager", &["images"], true);
    assert!(output.contains("abstract class _AssetManagerContext"));
}
```

- [ ] **Step 2: Run test to verify it fails**
Run: `cargo test --manifest-path native/Cargo.toml`
Expected: FAIL (unresolved function `generate_dart_code`)

- [ ] **Step 3: Implement `scanner.rs` and `generator.rs`**
- `scanner.rs`: Walks `assets/<folder>` ignoring hidden files/folders (`.*`), collecting relative asset paths.
- `generator.rs`: Replicates `AssetSourceGenerator` logic:
  - Sanitizes identifiers (numbers prefixed with `_`, special characters replaced with `_`, lowercase camelCase).
  - Emits `class AssetPath`, `abstract class _<ClassName>Context`, and accessor classes.
- `ffi.rs`:
  - `lazy_asset_generate(root_dir: *const c_char, config_json: *const c_char) -> *mut c_char`
  - `lazy_asset_free_string(ptr: *mut c_char)`: Deallocates string via `CString::from_raw`.

- [ ] **Step 4: Run Rust tests to verify they pass**
Run: `cargo test --manifest-path native/Cargo.toml`
Expected: PASS

- [ ] **Step 5: Build release dynamic library**
Run: `cargo build --release --manifest-path native/Cargo.toml`
Expected: Produces `native/target/release/liblazy_asset_core.so`

- [ ] **Step 6: Commit**
```bash
git add native/
git commit -m "feat(native): implement rust asset scanner, generator, and C-ABI"
```

---

### Task 3: Dart AST Annotation Parser & Pure Dart Generator

**Files:**
- Create: `lib/src/parser/annotation_parser.dart`
- Create: `lib/src/generator/dart_asset_generator.dart`
- Create: `test/annotation_parser_test.dart`

**Interfaces:**
- Consumes: Dart source code in `lib/`
- Produces: `AssetConfig` model with parsed annotation metadata, `DartAssetGenerator.generate(...)`

- [ ] **Step 1: Write failing test in `test/annotation_parser_test.dart`**
Test parsing `@GenerateAssets(folders: ['images', 'data'], recursive: true)` using `parseString`:
```dart
test('parses @GenerateAssets annotation correctly', () {
  const source = '''
    import 'package:lazy_asset_generator/lazy_asset_generator.dart';
    part 'test.g.dart';
    @GenerateAssets(folders: ['images'], recursive: true)
    class Assets extends _AssetsContext {}
  ''';
  final configs = AnnotationParser.parseSource(source, 'lib/test.dart');
  expect(configs.length, equals(1));
  expect(configs.first.className, equals('Assets'));
  expect(configs.first.folders, equals(['images']));
  expect(configs.first.recursive, isTrue);
});
```

- [ ] **Step 2: Run test to verify it fails**
Run: `dart test test/annotation_parser_test.dart`
Expected: FAIL (classes not defined)

- [ ] **Step 3: Implement `AnnotationParser` and `DartAssetGenerator`**
- `AnnotationParser`:
  - Reads `lib/**/*.dart`.
  - Uses `parseString(content: ...).unit` to inspect class annotations named `GenerateAssets`.
  - Extracts `folders`, `folder`, `recursive`, `className`.
- `DartAssetGenerator`:
  - Reads directories under `assets/` on disk using `dart:io`.
  - Invokes `AssetSourceGenerator.generate` directly.
  - Writes output to `<file>.g.dart`.

- [ ] **Step 4: Run test to verify it passes**
Run: `dart test test/annotation_parser_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add lib/src/ test/annotation_parser_test.dart
git commit -m "feat: add AST annotation parser and pure dart generator"
```

---

### Task 4: Dart FFI Bridge & Auto-Compile with Fallback

**Files:**
- Create: `lib/src/ffi/native_bindings.dart`
- Create: `test/ffi_bridge_test.dart`

**Interfaces:**
- Consumes: `native/target/release/liblazy_asset_core.*`
- Produces: `NativeAssetEngine.isAvailable`, `NativeAssetEngine.generate(...)`, fallback execution

- [ ] **Step 1: Write failing test in `test/ffi_bridge_test.dart`**
Verify `NativeAssetEngine` loads the compiled shared library and invokes `lazy_asset_generate`:
```dart
test('NativeAssetEngine generates asset code via FFI', () {
  final engine = NativeAssetEngine();
  expect(engine.isAvailable, isTrue);
  final code = engine.generate(
    projectRoot: Directory.current.path,
    inputFileName: 'asset_manager.dart',
    className: 'AssetManager',
    folders: ['images'],
    recursive: true,
  );
  expect(code, contains('abstract class _AssetManagerContext'));
});
```

- [ ] **Step 2: Run test to verify it fails**
Run: `dart test test/ffi_bridge_test.dart`
Expected: FAIL (class not defined)

- [ ] **Step 3: Implement `NativeAssetEngine`**
- Locates dynamic library based on `Platform.isLinux` (`.so`), `Platform.isMacOS` (`.dylib`), `Platform.isWindows` (`.dll`).
- If missing, checks if `cargo` is in PATH; if present, triggers `cargo build --release` and waits.
- Binds FFI symbols:
  - `lazy_asset_generate`
  - `lazy_asset_free_string`
- Safely converts Dart Strings to Native Utf8 pointers, calls native function, reads result, and frees native string via `lazy_asset_free_string`.
- Exposes `fallbackToDart(reason)` when native library cannot be loaded.

- [ ] **Step 4: Run test to verify it passes**
Run: `dart test test/ffi_bridge_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add lib/src/ffi/ test/ffi_bridge_test.dart
git commit -m "feat(ffi): implement native bindings with auto-compile and fallback"
```

---

### Task 5: CLI Runner & Watcher Daemon

**Files:**
- Create: `bin/lazy_asset_generator.dart`
- Create: `lib/src/cli/runner.dart`
- Create: `lib/src/cli/watcher.dart`
- Create: `test/cli_test.dart`

**Interfaces:**
- Consumes: Command line arguments (`--watch`, `--force-dart`, `--verbose`, `--path`)
- Produces: Executable `lazy_asset_generator`

- [ ] **Step 1: Write failing test in `test/cli_test.dart`**
Test CLI runner executing generation on a mock asset directory:
```dart
test('CLI runner performs generation on target project', () async {
  final runner = CliRunner();
  final result = await runner.run(['--path', 'example']);
  expect(result.exitCode, equals(0));
});
```

- [ ] **Step 2: Run test to verify it fails**
Run: `dart test test/cli_test.dart`
Expected: FAIL (`CliRunner` not defined)

- [ ] **Step 3: Implement `CliRunner`, `Watcher`, and `bin/lazy_asset_generator.dart`**
- `CliRunner`:
  - Discovers all `@GenerateAssets` classes across `lib/`.
  - Determines engine (Rust FFI or Dart fallback).
  - Generates `.g.dart` files and prints timings.
- `Watcher`:
  - Watches `assets/` and `lib/` recursively.
  - Ignores `.g.dart` files.
  - Implements 250ms debounce window.
  - Listens to `ProcessSignal.sigint` for clean exit.
- `bin/lazy_asset_generator.dart`: Top-level `main(List<String> args)` forwarding to `CliRunner`.

- [ ] **Step 4: Run test to verify it passes**
Run: `dart test test/cli_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**
```bash
git add bin/ lib/src/cli/ test/cli_test.dart
git commit -m "feat(cli): implement standalone executable and watch daemon"
```

---

### Task 6: Verification, Documentation & End-to-End Test

**Files:**
- Modify: `README.md`
- Test: Full test suite (`dart test` and `cargo test`)

**Interfaces:**
- Verifies all features work end-to-end.

- [ ] **Step 1: Update `README.md`**
Document the new CLI usage:
```bash
dart run lazy_asset_generator
dart run lazy_asset_generator --watch
```
Explain Rust acceleration and automatic fallback.

- [ ] **Step 2: Run all Dart tests**
Run: `dart test`
Expected: All tests pass.

- [ ] **Step 3: Run all Rust tests**
Run: `cargo test --manifest-path native/Cargo.toml`
Expected: All tests pass.

- [ ] **Step 4: Test CLI execution directly**
Run: `dart run bin/lazy_asset_generator.dart --verbose`
Expected: Discovers asset managers and generates code with timing report.

- [ ] **Step 5: Commit**
```bash
git add README.md
git commit -m "docs: document standalone cli and watcher"
```
