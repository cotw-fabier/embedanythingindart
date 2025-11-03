## Dart plugin tech stack standards

- **Dart Language**: Use modern Dart (3.0+) with null safety, pattern matching, records, and sealed classes
- **FFI Integration**: Use `dart:ffi` for native interop; leverage `package:ffi` for helpers like `malloc`, `calloc`, `Utf8`
- **Native Assets**: Use Dart's native assets system via `hook/build.dart` for automated native library compilation
- **Rust Integration**: Use `native_toolchain_rs` (from GitHub) for compiling Rust code via build hooks
- **C/C++ Integration**: Use `native_toolchain_c` or similar for compiling C/C++ code via build hooks
- **Build System**: Use `package:hooks` for build and link hooks; understand native asset lifecycle
- **Code Generation**: Use `build_runner` when needed for code generation (rare for pure FFI packages)
- **Memory Management**: Rely on `NativeFinalizer` for automatic resource cleanup tied to Dart GC
- **Async Operations**: Use `compute()` from `package:flutter/foundation.dart` or manual isolates for background work
- **Platform Channels**: For Flutter plugins, combine FFI with platform channels when platform-specific APIs needed
- **Testing**: Use `package:test` for unit and integration tests; test on all supported platforms
- **Linting**: Use `package:lints` or `package:flutter_lints` with strict analysis options
- **Documentation**: Generate API docs with `dartdoc`; include comprehensive README and examples
- **CI/CD**: Use GitHub Actions or similar to test across all platforms (Windows, macOS, Linux, iOS, Android)
- **Versioning**: Follow semantic versioning strictly; tag releases and maintain detailed CHANGELOG
- **Dependencies**: Minimize dependencies; prefer standard library and `dart:ffi` over third-party packages
- **Example App**: Include working Flutter example app demonstrating all major plugin features
- **Platform Support**: Clearly document supported platforms and minimum OS versions

## Core Dependencies

**Minimal FFI Package:**
```yaml
name: my_ffi_plugin
version: 1.0.0

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  ffi: ^2.1.0

dev_dependencies:
  test: ^1.24.0
  lints: ^4.0.0
```

**Rust-based Plugin:**
```yaml
dependencies:
  ffi: ^2.1.0

dev_dependencies:
  native_toolchain_rs:
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: <commit-hash>
  test: ^1.24.0
  lints: ^4.0.0
```

**Flutter Plugin:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  ffi: ^2.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  native_toolchain_rs:
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: <commit-hash>
  flutter_lints: ^4.0.0
```

## Development Tools

- **Dart SDK**: Latest stable Dart SDK (3.0+)
- **Flutter SDK**: For Flutter plugins (if applicable)
- **Rust Toolchain**: rustup with specific version pinned in `rust-toolchain.toml`
- **Native Toolchain**: Platform-specific build tools (MSVC, Xcode, GCC/Clang)
- **ffigen**: Optional - for generating FFI bindings from C headers
- **IDE**: VS Code with Dart/Flutter extensions or IntelliJ IDEA

## References

- [Dart FFI](https://dart.dev/guides/libraries/c-interop)
- [Native Assets](https://dart.dev/tools/hooks)
- [native_toolchain_rs](https://github.com/GregoryConrad/native_toolchain_rs)
- [Package Development](https://dart.dev/guides/libraries/create-packages)
