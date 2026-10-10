import 'dart:io';

import 'asset_manager.dart';

void main() {
  final assets = AssetManager();
  stdout.writeln(assets.images.marketing.banner);
  stdout.writeln(assets.data.config);
}
