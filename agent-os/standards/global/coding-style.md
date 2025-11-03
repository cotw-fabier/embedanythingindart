## Dart plugin coding style best practices

- **Effective Dart Guidelines**: Follow the official Effective Dart guidelines for style, documentation, usage, and design
- **Naming Conventions**: Use `PascalCase` for classes/enums, `camelCase` for variables/functions/members, and `snake_case` for file names
- **FFI Naming**: Prefix FFI-related classes with `Native` (e.g., `NativeDatabase`, `NativeCrypto`) to distinguish from high-level API
- **Line Length**: Keep lines to 80 characters or fewer; configure formatter to enforce this limit
- **Concise and Declarative**: Write concise, modern, technical Dart code; prefer functional and declarative patterns
- **Small, Focused Functions**: Keep functions short and single-purpose, striving for less than 20 lines per function
- **Meaningful Names**: Use descriptive names that reveal intent; avoid abbreviations except in universally understood contexts (FFI, API, IO)
- **Arrow Functions**: Use arrow syntax (`=>`) for simple one-line functions
- **Null Safety**: Write soundly null-safe code; document when null represents "not yet initialized" vs. "optional value"
- **Pattern Matching**: Leverage Dart's pattern matching features to simplify code and improve readability
- **Exhaustive Switch**: Prefer exhaustive `switch` statements/expressions which don't require `break` statements
- **Remove Dead Code**: Delete unused code, commented-out blocks, and unused imports immediately
- **DRY Principle**: Extract common logic into reusable functions; especially important for repeated FFI call patterns
- **Const Constructors**: Use `const` constructors for configuration objects and immutable data structures
- **Automated Formatting**: Use `dart format` to ensure consistent code formatting across the codebase
- **Type Annotations**: Always provide explicit type annotations for public APIs and FFI signatures
- **Final by Default**: Mark all variables `final` unless they truly need to be reassigned
- **Pointer Safety**: Never expose raw `Pointer` types in public API; wrap them in opaque handles or Dart classes
- **Extension Methods**: Use extension methods to add convenience APIs to FFI types without modifying core definitions
- **Records for Multiple Returns**: Use records `(Type1, Type2)` when functions naturally return multiple values
- **Sealed Classes**: Use `sealed` classes for FFI result types to ensure exhaustive error handling

## FFI-Specific Style

- **Opaque Types**: Define opaque types for native handles: `final class NativeHandle extends Opaque {}`
- **Native Annotations**: Use `@Native` annotations with asset IDs following pattern: `package:<package-name>/<asset-name>`
- **Struct Alignment**: Respect native struct alignment; use `@Packed()` only when source library uses packed structs
- **Callback Isolation**: Isolate callbacks that bridge native→Dart to prevent GC issues during native execution
- **FFI Helper Methods**: Create helper extension methods for common Pointer operations (allocation, deallocation, casting)
- **Type Aliases**: Define clear type aliases for function pointers: `typedef NativeCallback = Void Function(Int32)`

## References

- [Effective Dart Style Guide](https://dart.dev/effective-dart/style)
- [Dart FFI Best Practices](https://dart.dev/guides/libraries/c-interop)
- [Dart Language Tour](https://dart.dev/language)
