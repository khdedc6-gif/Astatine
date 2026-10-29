import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final builder = CBuilder.library(
      name: input.packageName,
      assetName: 'molecule_tile_physics_bindings_generated.dart',
      sources: ['src/molecule_tile_physics.cpp'],
      language: .cpp,
      std: 'c++17',
    );
    Logger.root.level = .ALL;
    Logger.root.onRecord.listen((record) => print(record.message));
    await builder.run(input: input, output: output, logger: Logger.root);
  });
}
