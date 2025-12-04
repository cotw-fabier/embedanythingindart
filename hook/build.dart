import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

/// Build hook for Native Assets
///
/// This hook runs during `dart run` and `flutter run` to compile the Rust code
/// into native libraries for the target platform.
void main(List<String> args) async {
  await build(args, (input, output) async {
    await const RustBuilder(
      // Must match the package name in rust/Cargo.toml
      assetName: 'embedanything_dart',
    ).run(input: input, output: output);
  });
}
