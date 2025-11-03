## Dart plugin development conventions

- **Package Structure**: Follow standard Dart package layout with `lib/` for source, `src/` for implementation details, and exports through main library file
- **FFI Organization**: Place FFI bindings in `lib/src/ffi/` and expose high-level Dart API in `lib/src/` with clean public exports
- **Native Assets Integration**: Use Dart's native assets system with `hook/build.dart` for compiling native libraries at build time
- **Platform Abstraction**: Design platform-agnostic APIs that abstract platform-specific implementation details from users
- **Documentation First**: Provide comprehensive API documentation, setup guides, and examples before considering package complete
- **Null Safety**: All code must be soundly null-safe; avoid `!` operator except when guaranteed by FFI contracts
- **Semantic Versioning**: Follow semver strictly; native binding changes often require major version bumps
- **Platform Support**: Clearly document which platforms (Android, iOS, Windows, Linux, macOS, Web) are supported
- **Dependencies**: Minimize dependencies; prefer `dart:ffi` and standard library over third-party packages
- **Example App**: Include working example in `example/` directory demonstrating all major features
- **Changelog Maintenance**: Maintain detailed CHANGELOG.md documenting API changes, platform additions, and breaking changes; **REQUIRED: Update CHANGELOG.md at the end of implementing each spec** with entries for all changes made
- **License**: Include clear license file (MIT, BSD, Apache 2.0) and ensure native code licenses are compatible
- **CI/CD**: Set up GitHub Actions or similar to test across all supported platforms automatically
- **Memory Safety**: Document memory ownership clearly; specify when Dart owns memory vs. when native code owns it
- **Error Propagation**: Convert native errors into Dart exceptions with meaningful messages and context
- **Async by Default**: Wrap blocking native calls in `compute()` or isolates to prevent UI freezing
- **Resource Management**: Implement proper finalizers for native resources using `NativeFinalizer` to prevent memory leaks
- **Version Pinning**: Pin exact Rust toolchain versions in `rust-toolchain.toml` for reproducible builds across environments

## References

- [Dart FFI Documentation](https://dart.dev/guides/libraries/c-interop)
- [Dart Native Assets](https://dart.dev/tools/hooks)
- [Effective Dart Guidelines](https://dart.dev/effective-dart)
- [Package Layout Conventions](https://dart.dev/tools/pub/package-layout)
