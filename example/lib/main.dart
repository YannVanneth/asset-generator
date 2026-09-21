import 'asset_manager.dart';

void main() {
  final assets = AssetManager();
  print(assets.images.marketing.banner);
  print(assets.data.config);
}
