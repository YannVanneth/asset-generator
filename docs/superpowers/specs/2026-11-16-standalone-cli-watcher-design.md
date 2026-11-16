# Standalone CLI & Asset Watcher with Rust FFI Engine Design

## 1. Intent & The Why

Currently, Flutter developers using `lazy_asset_generator` must run `dart run build_runner build --delete-conflicting-outputs` whenever assets are added, renamed, or pulled from teammates. If someone forgets, code breaks or asset accessors are outdated. Furthermore, running `build_runner` has a noticeable startup overhead (5–15 seconds) because it analyzes whole package build graphs.

The goal is to provide a dedicated, lightweight standalone CLI command and file watcher for `lazy_asset_generator` with a high-performance native Rust core via Dart FFI (`dart:ffi`), accompanied by an automatic pure Dart fallback for environments without a Rust toolchain.

## 2. Goals, Non-Goals, & Anti-Goals

### Goals
- **Instant Generation**: Provide `dart run lazy_asset_generator` that generates asset accessors directly in < 5ms (Rust engine) or < 50ms (Dart fallback).
- **Continuous Watch Mode**: Provide `dart run lazy_asset_generator --watch` (or `-w`) that listens to filesystem events in `assets/` and `lib/` with debouncing, automatically regenerating output on any asset addition, deletion, or rename.
- **Rust FFI Acceleration**: Use Rust in `native/` for native file scanning, high-throughput string templating, and native OS file events via `notify`.
- **Zero-Friction Fallback**: If the Rust binary is missing and `cargo` is not installed, seamlessly fall back to pure Dart without failing.
- **Maintain Full Compatibility**: Preserve existing `build_runner` / `source_gen` builder functionality completely unchanged.

### Non-Goals
- Replacing `build_runner` for other code generators in the user's project (e.g. `json_serializable`, `freezed`).
- Forcing every teammate or CI runner to install Rust/Cargo (prevented by the Dart fallback).

### Anti-Goals
- Complex manual build steps for developers (compilation should be automatic if `cargo` exists).
- Breaking existing Flutter code or requiring new code structures in user projects.

## 3. Architecture & Technical Design

```
                      ┌──────────────────────────────────────────┐
                      │          Dart CLI Entry Point            │
                      │       `bin/lazy_asset_generator.dart`    │
                      └────────────────────┬─────────────────────┘
                                           │
                         ┌─────────────────┴─────────────────┐
                         │ Can load Rust Dynamic Library?    │
                         └─────────┬─────────────────┬───────┘
                               Yes │                 │ No (Fallback)
                                   ▼                 ▼
                      ┌──────────────────────┐  ┌──────────────────────┐
                      │   Rust FFI Bridge    │  │ Pure Dart Generator  │
                      │  (`dart:ffi` C-ABI)  │  │ (AssetSourceGenerator│
                      └────────────┬─────────┘  └──────────────────────┘
                                   │
                                   ▼
                      ┌──────────────────────┐
                      │ Rust Engine (native) │
                      │  • notify (watcher)  │
                      │  • walkdir (scan)    │
                      │  • code generation   │
                      └──────────────────────┘
```

### Components

#### 1. Rust Native Crate (`native/`)
- `Cargo.toml`:
  - `crate-type = ["cdylib"]`
  - Dependencies: `notify`, `walkdir`, `serde`, `serde_json`.
- Modules:
  - `scanner.rs`: Fast recursive/non-recursive traversal of `assets/`.
  - `generator.rs`: Constructs AST nodes, tree representations, and emits Dart code.
  - `ffi.rs`: C-ABI exports:
    - `lazy_asset_generate(root_dir: *const c_char, config_json: *const c_char) -> *mut c_char`
    - `lazy_asset_free_string(ptr: *mut c_char)`
    - `lazy_asset_start_watcher(...)`

#### 2. Dart FFI Loader & Fallback (`lib/src/ffi/`)
- Platform-aware dynamic library loading (`.so` on Linux, `.dylib` on macOS, `.dll` on Windows).
- If library not found:
  - Check if `cargo` is available via `Process.run('cargo', ['--version'])`.
  - If yes, execute `cargo build --release --manifest-path native/Cargo.toml` and load.
  - If no or failed, fall back to pure Dart `AssetSourceGenerator`.

#### 3. Dart CLI Runner (`bin/lazy_asset_generator.dart`)
- Command line arguments:
  - `--watch` / `-w`: Continuous file watcher.
  - `--force-dart`: Force using pure Dart engine even if Rust is available.
  - `--verbose` / `-v`: Verbose debug logs.
  - `--path`: Project root path (defaults to current directory).
- Uses `analyzer`'s `parseString` to discover `@GenerateAssets` annotations in `lib/`.

## 4. Constraints & Backward Compatibility
- Dart SDK `>=3.8.0 <4.0.0`.
- Safe memory deallocation on both sides of the FFI boundary (`free_string`).
- No impact on existing `build_runner` users.
