/// Builder entry point library for `build_runner`.
///
/// This file is referenced by `build.yaml` to instantiate the generator.
/// It is kept separate from `package:lazy_asset_generator/lazy_asset_generator.dart`
/// so Flutter applications importing annotations do not compile `package:build`
/// or reflection dependencies (`dart:mirrors`).
library;

import 'package:build/build.dart';
import 'package:lazy_asset_generator/lazy_asset_generator/lazy_asset_generator.dart';

/// Builder factory invoked by `build_runner` to construct the [AssetFolderGenerator].
Builder assetFolderBuilder(BuilderOptions options) => assetFolderBuilderImpl(options);
