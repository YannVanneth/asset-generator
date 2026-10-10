library;

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';

import 'annotations.dart';
import 'package:lazy_asset_generator/extension/extensions.dart';

/// Generates strongly-typed asset paths for classes annotated with
/// [GenerateAssets].
class AssetFolderGenerator extends GeneratorForAnnotation<GenerateAssets> {
  AssetFolderGenerator() : super(inPackage: 'lazy_asset_generator');

  @override
  FutureOr<String> generate(LibraryReader library, BuildStep buildStep) async {
    final managers = library.annotatedWith(typeChecker).toList();
    if (managers.length > 1) {
      throw InvalidGenerationSourceError(
        'Only one @GenerateAssets manager is supported per library. '
        'Move each manager to a separate library.',
        element: managers.last.element,
      );
    }
    return await super.generate(library, buildStep);
  }

  @override
  FutureOr<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@GenerateAssets must annotate a class.',
        element: element,
      );
    }
    try {
      return await _generate(element, annotation, buildStep);
    } on FormatException catch (error) {
      throw InvalidGenerationSourceError(error.message, element: element);
    }
  }

  Future<String> _generate(
    ClassElement element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final folderName = _readString(annotation, 'folder');
    final folders = annotation
        .read('folders')
        .listValue
        .map((value) => value.toStringValue() ?? '')
        .toList();
    final recursive = annotation.read('recursive').boolValue;
    final configuredClassName = _readString(annotation, 'className');

    if (folderName.isNotEmpty && folders.isNotEmpty) {
      throw FormatException(
        "Invalid @GenerateAssets usage on '${element.name}': "
        "both 'folder' and 'folders' are provided. Use only one.",
      );
    }

    final targetFolders = folderName.isNotEmpty
        ? [folderName]
        : folders.isNotEmpty
        ? folders
        : await _discoverFolders(buildStep, recursive);

    if (targetFolders.isEmpty) {
      throw FormatException(
        "No asset folders were found for '${element.name}'. "
        'Configure folder/folders or add files under assets/.',
      );
    }

    final assetsByFolder = <String, List<String>>{};
    for (final folder in targetFolders) {
      final normalizedFolder = _normalizeFolder(folder);
      final glob = recursive
          ? Glob('assets/$normalizedFolder/**')
          : Glob('assets/$normalizedFolder/*');
      final assets = <String>[];
      await for (final asset in buildStep.findAssets(glob)) {
        if (_isVisibleAsset(asset.path)) {
          assets.add(asset.path);
        }
      }

      if (assets.isEmpty) {
        throw FormatException(
          "No visible assets were found in 'assets/$normalizedFolder/'.",
        );
      }
      assetsByFolder[normalizedFolder] = assets;
    }

    final className = configuredClassName.isEmpty
        ? element.name as String
        : configuredClassName;
    _validateClassName(className);

    return AssetSourceGenerator._generate(
      inputFileName: p.basename(buildStep.inputId.path),
      includePartDirective: false,
      existingNames: LibraryReader(element.library).allElements
          .where(
            (declaration) => declaration.fragments.any((fragment) {
              final path = fragment.libraryFragment?.source.uri.path;
              return path != null &&
                  !path.endsWith(
                    '/${p.basename(buildStep.inputId.changeExtension('.g.dart').path)}',
                  );
            }),
          )
          .map((declaration) => declaration.name)
          .whereType<String>()
          .toSet(),
      contextClassName: className,
      folders: assetsByFolder.keys,
      assetsByFolder: assetsByFolder,
      recursive: recursive,
    );
  }

  Future<List<String>> _discoverFolders(
    BuildStep buildStep,
    bool recursive,
  ) async {
    final folders = <String>{};
    final glob = recursive ? Glob('assets/**') : Glob('assets/*/*');
    await for (final asset in buildStep.findAssets(glob)) {
      final segments = asset.pathSegments;
      if (segments.length > 1 &&
          segments.first == 'assets' &&
          !segments[1].startsWith('.') &&
          _isVisibleAsset(asset.path)) {
        folders.add(segments[1]);
      }
    }
    return folders.toList()..sort();
  }
}

/// Renders generated Dart source from a set of asset paths.
///
/// This is public to make deterministic rendering and validation testable
/// without requiring a complete build graph.
class AssetSourceGenerator {
  /// Generates the `.g.dart` source for [assetsByFolder].
  static String generate({
    required String inputFileName,
    required String contextClassName,
    required Iterable<String> folders,
    required Map<String, Iterable<String>> assetsByFolder,
    bool recursive = false,
  }) => _generate(
    inputFileName: inputFileName,
    contextClassName: contextClassName,
    folders: folders,
    assetsByFolder: assetsByFolder,
    recursive: recursive,
  );

  static String _generate({
    required String inputFileName,
    required String contextClassName,
    required Iterable<String> folders,
    required Map<String, Iterable<String>> assetsByFolder,
    bool recursive = false,
    bool includePartDirective = true,
    Set<String> existingNames = const {},
  }) {
    _validateClassName(contextClassName);
    final normalizedFolders = folders.map(_normalizeFolder).toSet().toList()
      ..sort();
    if (normalizedFolders.isEmpty) {
      throw const FormatException('At least one asset folder is required.');
    }

    final trees = <String, _AssetNode>{};
    for (final folder in normalizedFolders) {
      final root = _AssetNode();
      final expectedPrefix = 'assets/$folder/';
      final seenPaths = <String>{};
      for (final assetPath in assetsByFolder[folder] ?? const <String>[]) {
        if (!_isVisibleAsset(assetPath)) continue;
        if (!seenPaths.add(assetPath)) continue;
        if (!assetPath.startsWith(expectedPrefix)) {
          throw FormatException(
            "Asset '$assetPath' is outside configured folder '$folder'.",
          );
        }

        final relativePath = assetPath.substring(expectedPrefix.length);
        final segments = relativePath.split('/');
        if (segments.any(
          (segment) => segment.isEmpty || segment == '.' || segment == '..',
        )) {
          throw FormatException("Invalid asset path '$assetPath'.");
        }
        if (!recursive && segments.length != 1) continue;
        _insertAsset(root, assetPath, segments);
      }
      if (root.isEmpty) {
        throw FormatException(
          "No visible assets were found in 'assets/$folder/'.",
        );
      }
      trees[folder] = root;
    }

    _validateUniqueNames(normalizedFolders, trees);
    _validateGeneratedClassNames(
      normalizedFolders,
      trees,
      contextClassName,
      existingNames,
    );

    final output = StringBuffer();
    if (includePartDirective) {
      output.writeln("part of '${_quote(inputFileName)}';");
      output.writeln();
    }
    output
      ..writeln('class AssetPath {')
      ..writeln('  const AssetPath._();')
      ..writeln();

    for (final folder in normalizedFolders) {
      final methodName = folder.sanitizeIdentifier;
      output.writeln(
        "  static String $methodName(String assetName) => "
        "'assets/${_quote(folder)}/\$assetName';",
      );
    }
    output
      ..writeln('}')
      ..writeln()
      ..writeln('abstract class _${contextClassName}Context {');

    for (final folder in normalizedFolders) {
      final helperClassName = _classNameFor(folder, const []);
      final instanceName = folder.sanitizeIdentifier;
      output.writeln('  $helperClassName $instanceName = $helperClassName();');
    }
    output
      ..writeln('}')
      ..writeln();

    for (final folder in normalizedFolders) {
      _renderNode(
        output,
        root: trees[folder]!,
        folder: folder,
        pathSegments: const [],
      );
    }

    return output.toString();
  }

  static void _insertAsset(
    _AssetNode root,
    String assetPath,
    List<String> segments,
  ) {
    var node = root;
    for (var index = 0; index < segments.length; index++) {
      final segment = segments[index];
      if (index == segments.length - 1) {
        node.files.add(_AssetFile(assetPath, segments.join('/')));
      } else {
        node = node.children.putIfAbsent(segment, _AssetNode.new);
      }
    }
  }

  static void _validateUniqueNames(
    List<String> folders,
    Map<String, _AssetNode> trees,
  ) {
    final rootNames = <String, String>{};
    for (final folder in folders) {
      final name = folder.sanitizeIdentifier;
      _validateMemberName(name, folder);
      final previous = rootNames[name];
      if (previous != null && previous != folder) {
        _throwCollision(name, 'folders', [previous, folder]);
      }
      rootNames[name] = folder;
      _validateNode(trees[folder]!, folder, const []);
    }
  }

  static void _validateGeneratedClassNames(
    List<String> folders,
    Map<String, _AssetNode> trees,
    String contextClassName,
    Set<String> existingNames,
  ) {
    final classNames = <String, String>{
      'AssetPath': 'asset path utility',
      '_${contextClassName}Context': 'generated context',
    };
    for (final folder in folders) {
      _recordClassName(classNames, _classNameFor(folder, const []), folder);
      _walkClassNames(trees[folder]!, folder, const [], classNames);
    }
    for (final name in classNames.keys) {
      if (existingNames.contains(name)) {
        throw FormatException(
          "Generated declaration '$name' conflicts with "
          'an existing library declaration. Rename the declaration or asset folder.',
        );
      }
    }
  }

  static void _walkClassNames(
    _AssetNode node,
    String folder,
    List<String> parentSegments,
    Map<String, String> classNames,
  ) {
    for (final entry in node.children.entries) {
      final path = [...parentSegments, entry.key];
      _recordClassName(
        classNames,
        _classNameFor(folder, path),
        '$folder/${path.join('/')}',
      );
      _walkClassNames(entry.value, folder, path, classNames);
    }
  }

  static void _recordClassName(
    Map<String, String> classNames,
    String className,
    String source,
  ) {
    final previous = classNames[className];
    if (previous != null) {
      _throwCollision(className, 'generated helper classes', [
        previous,
        source,
      ]);
    }
    classNames[className] = source;
  }

  static void _validateNode(
    _AssetNode node,
    String folder,
    List<String> parentSegments,
  ) {
    final names = <String, String>{};
    for (final file in node.files) {
      final name = file.path.sanitizeIdentifier;
      _recordName(names, name, file.assetPath, folder, parentSegments);
    }
    for (final entry in node.children.entries) {
      final name = entry.key.sanitizeIdentifier;
      _recordName(names, name, entry.key, folder, parentSegments);
      _validateNode(entry.value, folder, [...parentSegments, entry.key]);
    }
  }

  static void _recordName(
    Map<String, String> names,
    String name,
    String source,
    String folder,
    List<String> parentSegments,
  ) {
    _validateMemberName(name, source);
    final previous = names[name];
    if (previous != null && previous != source) {
      _throwCollision(name, "'assets/$folder/${parentSegments.join('/')}'", [
        previous,
        source,
      ]);
    }
    names[name] = source;
  }

  static void _throwCollision(
    String name,
    String location,
    List<String> paths,
  ) {
    throw FormatException(
      "Asset identifier collision for '$name' in $location: "
      "${paths.join(' and ')}. Rename one of the assets or folders.",
    );
  }

  static void _renderNode(
    StringBuffer output, {
    required _AssetNode root,
    required String folder,
    required List<String> pathSegments,
  }) {
    final className = _classNameFor(folder, pathSegments);
    output.writeln('class $className {');

    for (final entry
        in root.children.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))) {
      final childClassName = _classNameFor(folder, [
        ...pathSegments,
        entry.key,
      ]);
      final childName = entry.key.sanitizeIdentifier;
      output.writeln('  $childClassName $childName = $childClassName();');
    }

    for (final file
        in root.files.toList()
          ..sort((a, b) => a.assetPath.compareTo(b.assetPath))) {
      final identifier = file.path.sanitizeIdentifier;
      final methodName = folder.sanitizeIdentifier;
      output.writeln(
        '  final String $identifier = '
        'AssetPath.$methodName("${_quote(file.relativePath)}");',
      );
    }
    output
      ..writeln('}')
      ..writeln();

    for (final entry
        in root.children.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))) {
      _renderNode(
        output,
        root: entry.value,
        folder: folder,
        pathSegments: [...pathSegments, entry.key],
      );
    }
  }

  static String _classNameFor(String folder, List<String> pathSegments) {
    final parts = [
      folder.sanitizeIdentifier,
      ...pathSegments.map((part) => part.sanitizeIdentifier),
    ];
    return '_${parts.map((part) => part.capitalize).join()}';
  }
}

class _AssetNode {
  final files = <_AssetFile>[];
  final children = <String, _AssetNode>{};

  bool get isEmpty => files.isEmpty && children.isEmpty;
}

class _AssetFile {
  final String assetPath;
  final String relativePath;

  _AssetFile(this.assetPath, this.relativePath);

  String get path => p.basename(assetPath);
}

String _readString(ConstantReader annotation, String field) =>
    annotation.read(field).stringValue;

String _normalizeFolder(String folder) {
  final portable = folder.replaceAll('\\', '/');
  final segments = portable.split('/');
  if (portable.isEmpty ||
      p.posix.isAbsolute(portable) ||
      p.windows.isAbsolute(folder) ||
      RegExp(r'^[A-Za-z]:').hasMatch(portable) ||
      segments.any((segment) => segment == '.' || segment == '..') ||
      RegExp(r'[*?\[\]{}]').hasMatch(portable)) {
    throw FormatException(
      "Invalid asset folder '$folder'. "
      'Use a relative folder under assets/ without traversal or glob patterns.',
    );
  }
  final normalized = p.posix
      .normalize(portable)
      .replaceFirst(RegExp(r'/+$'), '');
  if (normalized.isEmpty || normalized == '.') {
    throw FormatException("Invalid asset folder '$folder'.");
  }
  return normalized;
}

bool _isVisibleAsset(String path) {
  if (path.isEmpty) return false;
  final segments = path.replaceAll('\\', '/').split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && !segment.startsWith('.'),
  );
}

void _validateClassName(String name) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name) ||
      name == '_' ||
      SanitizeIdentifier.isDartKeyword(name)) {
    throw FormatException(
      "Invalid className '$name'. Use a valid Dart class identifier.",
    );
  }
}

String _quote(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')
    .replaceAll("'", "\\'")
    .replaceAll(r'$', r'\$')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r')
    .replaceAll('\t', r'\t')
    .replaceAll('\b', r'\b')
    .replaceAll('\f', r'\f')
    .replaceAllMapped(
      RegExp(r'[\x00-\x1f\x7f]'),
      (match) =>
          '\\u${match[0]!.codeUnitAt(0).toRadixString(16).padLeft(4, '0')}',
    );

void _validateMemberName(String name, String source) {
  if (const {
    'hashCode',
    'runtimeType',
    'toString',
    'noSuchMethod',
  }.contains(name)) {
    throw FormatException(
      "Asset identifier '$name' from '$source' conflicts "
      'with an inherited Dart member. Rename the asset or folder.',
    );
  }
}

Builder assetFolderBuilderImpl(BuilderOptions options) =>
    SharedPartBuilder([AssetFolderGenerator()], 'lazy_asset_generator');

Builder assetFolderBuilder(BuilderOptions options) =>
    assetFolderBuilderImpl(options);
