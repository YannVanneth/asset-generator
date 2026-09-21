import 'package:lazy_asset_generator/lazy_asset_generator.dart';

part 'asset_manager.g.dart';

@GenerateAssets(
  folders: ['images', 'data'],
  recursive: true,
)
class AssetManager extends _AssetManagerContext {}
