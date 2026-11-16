import 'dart:io';

import 'package:lazy_asset_generator/src/cli/runner.dart';

Future<void> main(List<String> args) async {
  final runner = CliRunner();
  final exitCode = await runner.run(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}
