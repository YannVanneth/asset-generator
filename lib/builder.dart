library;

import 'package:build/build.dart';
import 'package:lazy_asset_generator/lazy_asset_generator/lazy_asset_generator.dart';

/// Builder entry point for build_runner.
Builder assetFolderBuilder(BuilderOptions options) => assetFolderBuilderImpl(options);
