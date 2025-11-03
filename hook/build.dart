import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';

/// Build hook for Native Assets
///
/// This hook runs during `dart run` and `flutter run` to compile the Rust code
/// into native libraries for the target platform.
void main(List<String> args) async {
  await build(args, (input, output) async {
    await RustBuilder(
      // Must match the package name in rust/Cargo.toml
      assetName: 'embedanything_dart',
    ).run(input: input, output: output);
  });
}
