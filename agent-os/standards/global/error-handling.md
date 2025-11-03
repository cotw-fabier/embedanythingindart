## FFI and native code error handling standards

- **Never Ignore Native Errors**: Always check return codes, error pointers, or result types from native calls
- **Exception Hierarchy**: Create custom exception hierarchy inheriting from `Exception` for different error categories
- **Preserve Native Context**: Include native error codes, error messages, and stack context in Dart exceptions
- **Result Types**: Use sealed classes or records to represent success/failure explicitly rather than throwing exceptions
- **Error Code Mapping**: Map native error codes to meaningful Dart exception types with descriptive messages
- **Null Pointer Checks**: Always validate pointers are non-null before dereferencing; throw `ArgumentError` for null inputs
- **Memory Allocation Failures**: Check for null return from allocation functions; throw `OutOfMemoryError` when detected
- **Resource Cleanup**: Use try-finally blocks to ensure native resources are freed even when exceptions occur
- **FFI Guard Pattern**: Wrap FFI calls in guard functions that validate preconditions and convert native errors
- **Callback Error Handling**: Catch all Dart exceptions in native callbacks; never let exceptions propagate into native code
- **Isolate Communication**: When using compute/isolates, serialize errors properly since exceptions don't cross isolate boundaries
- **Panic Handling**: Document Rust panic behavior; use `std::panic::catch_unwind` in Rust to prevent unwinding into Dart
- **Timeout Handling**: Set reasonable timeouts for blocking native operations; return error results rather than hanging indefinitely
- **Platform-Specific Errors**: Abstract platform-specific error codes (POSIX errno, Windows HRESULT) into unified Dart exceptions
- **Error Recovery**: Document whether errors are recoverable; provide clear guidance on retry strategies
- **Logging Integration**: Log all native errors with sufficient context for debugging; use `dart:developer` log function
- **Debug vs Release**: Add assertion checks in debug mode for contract validation; optimize them out in release builds
- **Documentation**: Document all possible exceptions in dartdoc with `/// Throws [ExceptionType] when...` comments

## Error Handling Patterns

**Result Type Pattern:**
```dart
sealed class Result<T, E> {
  const Result();
}
class Success<T, E> extends Result<T, E> {
  const Success(this.value);
  final T value;
}
class Failure<T, E> extends Result<T, E> {
  const Failure(this.error);
  final E error;
}
```

**FFI Guard Pattern:**
```dart
T callNative<T>(T Function() nativeCall, String operation) {
  try {
    final result = nativeCall();
    if (result == null) {
      throw StateError('$operation returned null');
    }
    return result;
  } catch (e) {
    throw NativeException('$operation failed', cause: e);
  }
}
```

**Callback Safety Pattern:**
```dart
@pragma('vm:entry-point')
void nativeCallback(Pointer<Void> data) {
  try {
    // Safe Dart code
  } catch (e, stack) {
    // Log but never throw
    print('Callback error: $e\n$stack');
  }
}
```

## References

- [Dart Error Handling](https://dart.dev/language/error-handling)
- [FFI Memory Management](https://dart.dev/guides/libraries/c-interop#managing-memory)
- [Effective Dart: Error Handling](https://dart.dev/effective-dart/usage#error-handling)
