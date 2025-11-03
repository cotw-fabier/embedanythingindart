## Dart plugin package versioning and compatibility standards

- **Semantic Versioning**: Follow semver strictly: `MAJOR.MINOR.PATCH` where MAJOR = breaking changes, MINOR = new features, PATCH = bug fixes
- **Native Breaking Changes**: Changing native library version, FFI signatures, or native asset configuration typically requires MAJOR bump
- **API Stability**: Adding new public APIs is MINOR; changing existing public API signatures or behavior is MAJOR
- **Version Constraints**: Specify Dart SDK constraints in pubspec.yaml; use `>=` for minimum and `<` for maximum version
- **Platform Compatibility**: Document minimum platform versions (iOS 12+, Android API 21+, etc.) in README and pubspec.yaml
- **Changelog Maintenance**: Keep detailed CHANGELOG.md with sections for each version: Added, Changed, Deprecated, Removed, Fixed, Security
- **Deprecation Strategy**: Mark APIs as `@Deprecated('message')` one MAJOR version before removal; provide migration path
- **Beta/Alpha Versions**: Use pre-release identifiers (1.0.0-beta.1, 1.0.0-alpha.2) for unstable releases
- **Native Library Versions**: Document which native library version the package wraps; update when native library updates
- **ABI Compatibility**: When wrapping C libraries, note if ABI breaking changes require package MAJOR bump
- **Dependency Constraints**: Use compatible version constraints for dependencies; avoid overly restrictive pinning
- **Breaking Change Documentation**: Clearly document all breaking changes in CHANGELOG and provide migration guide
- **Version Detection**: Consider exposing `version` getter to allow runtime version checking if needed
- **Platform Feature Detection**: Provide APIs to detect platform capabilities rather than assuming features exist
- **Graceful Degradation**: Design APIs to work across versions when possible; throw clear errors for unsupported features
- **Migration Guides**: Write detailed migration guides for MAJOR version upgrades in docs/migration/ directory
- **Version Compatibility Matrix**: Maintain table showing package version → native library version → supported platforms

## Versioning Examples

**PATCH version (1.0.0 → 1.0.1):**
- Fix memory leak in finalizer
- Correct error message text
- Update documentation
- Improve example code

**MINOR version (1.0.1 → 1.1.0):**
- Add new optional parameter to existing function (with default)
- Add new public API function
- Add support for new platform
- Expose additional native library functionality

**MAJOR version (1.1.0 → 2.0.0):**
- Change function signature (remove parameter, change return type)
- Rename public class or function
- Change error handling behavior (throw exceptions instead of returning null)
- Upgrade to incompatible native library version
- Remove deprecated API
- Change memory ownership semantics

## pubspec.yaml Versioning

```yaml
name: my_native_plugin
version: 2.1.0
description: Dart FFI bindings for MyNativeLib

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  ffi: ^2.1.0

dev_dependencies:
  test: ^1.24.0
  native_toolchain_rs:
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: abc123def456

platforms:
  android:
  ios:
  linux:
  macos:
  windows:
```

## CHANGELOG.md Format

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2024-03-15

### Changed
- **BREAKING**: Renamed `Database.open()` to `Database.connect()` for clarity
- **BREAKING**: Changed error handling to throw `DatabaseException` instead of returning null
- Updated to MyNativeLib v3.0.0 (ABI breaking changes)

### Added
- Support for Windows platform
- New `Database.isConnected` getter
- Connection pooling support

### Deprecated
- `Database.query()` - use `Database.execute()` instead (will be removed in 3.0.0)

### Removed
- **BREAKING**: Removed deprecated `Database.rawQuery()` method

### Fixed
- Memory leak when closing database handles
- Crash on iOS when using async operations

### Migration Guide
See [docs/migration/v2.md](docs/migration/v2.md) for detailed migration instructions.

## [1.1.0] - 2024-02-01

### Added
- macOS support
- Optional `timeout` parameter to `Database.connect()`

### Fixed
- Improved error messages for connection failures
```

## Updating Changelog During Spec Implementation

**REQUIRED STEP**: At the end of implementing each spec, update CHANGELOG.md with all changes made.

- **When**: Always update CHANGELOG.md as the final step before marking spec as complete
- **What to Include**: Document all API changes, new features, bug fixes, breaking changes, and platform additions
- **Format**: Use "Unreleased" section at top of changelog for work-in-progress changes
- **Categories**: Organize changes under: Added, Changed, Deprecated, Removed, Fixed, Security
- **Be Specific**: Provide clear descriptions with enough detail for users to understand impact
- **Link Issues**: Reference related issue numbers or PR numbers when applicable
- **Breaking Changes**: Prefix breaking changes with **BREAKING**: for visibility

### Example Unreleased Section:

```markdown
## [Unreleased]

### Added
- New `Database.queryAsync()` method for async queries
- Support for Linux platform (x86_64, aarch64)

### Changed
- **BREAKING**: `Database.connect()` now returns `Future<void>` instead of synchronous
- Improved error messages for connection failures

### Fixed
- Memory leak in finalizer when connection closes unexpectedly
- Null pointer dereference in error handling path
```

When releasing a version, change `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD` and create new empty `[Unreleased]` section at top.

## Platform Compatibility Matrix

Maintain a table in README.md:

```markdown
| Package Version | Native Lib Version | iOS | Android | macOS | Windows | Linux |
|-----------------|-------------------|-----|---------|-------|---------|-------|
| 2.1.x | 3.0.x | 12+ | API 21+ | 10.14+ | 10 | glibc 2.31+ |
| 2.0.x | 3.0.x | 12+ | API 21+ | 10.14+ | ❌ | ❌ |
| 1.x.x | 2.5.x | 11+ | API 19+ | ❌ | ❌ | ❌ |
```

## References

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Dart Package Versioning](https://dart.dev/tools/pub/versioning)
- [Package Layout Conventions](https://dart.dev/tools/pub/package-layout)
