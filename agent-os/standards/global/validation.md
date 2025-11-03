## Input validation standards for Dart plugins

- **Validate at Boundaries**: Validate all inputs at FFI boundary before passing to native code
- **Null Checks**: Validate non-null requirements early; throw `ArgumentError` for null inputs when not allowed
- **Range Validation**: Check numeric inputs are within acceptable ranges before native calls
- **String Validation**: Validate string inputs (non-empty, max length, format) before conversion to native types
- **Pointer Validation**: Always check pointers from native code are non-null before dereferencing
- **Type Validation**: Ensure data types match FFI expectations; validate before type conversions
- **Sanitize Inputs**: Sanitize user input to prevent injection or unexpected behavior in native code
- **Clear Error Messages**: Throw exceptions with clear, actionable messages explaining what's invalid
- **Document Contracts**: Document preconditions in dartdoc; specify valid ranges, formats, and constraints
- **Fail Fast**: Validate and fail immediately at API boundary; don't pass invalid data to native code
- **Platform Validation**: Validate platform-specific constraints (e.g., path formats, file permissions)
- **Buffer Size Validation**: Validate buffer sizes before allocations to prevent excessive memory usage

## Validation Patterns

**Parameter Validation:**
```dart
void processData(String input, {int maxLength = 1000}) {
  // Validate input constraints
  ArgumentError.checkNotNull(input, 'input');

  if (input.isEmpty) {
    throw ArgumentError('input cannot be empty');
  }

  if (input.length > maxLength) {
    throw ArgumentError(
      'input length ${input.length} exceeds maximum $maxLength'
    );
  }

  // Proceed with native call
  final inputPtr = input.toNativeUtf8();
  try {
    nativeProcessData(inputPtr);
  } finally {
    malloc.free(inputPtr);
  }
}
```

**Numeric Range Validation:**
```dart
void setVolume(int level) {
  if (level < 0 || level > 100) {
    throw RangeError.range(level, 0, 100, 'level');
  }

  nativeSetVolume(level);
}
```

**Pointer Validation:**
```dart
String? getNativeString(Pointer<Utf8> ptr) {
  if (ptr == nullptr) {
    return null; // or throw exception, depending on contract
  }

  return ptr.toDartString();
}
```

**File Path Validation:**
```dart
void openFile(String path) {
  ArgumentError.checkNotNull(path, 'path');

  if (path.isEmpty) {
    throw ArgumentError('path cannot be empty');
  }

  // Platform-specific validation
  if (Platform.isWindows && path.contains('*')) {
    throw ArgumentError('path contains invalid characters');
  }

  final pathPtr = path.toNativeUtf8();
  try {
    final result = nativeOpenFile(pathPtr);
    if (result != 0) {
      throw FileSystemException('Failed to open file', path);
    }
  } finally {
    malloc.free(pathPtr);
  }
}
```

## References

- [Argument Validation](https://dart.dev/effective-dart/usage#do-use-argumenterrorchecknotnull-to-verify-that-a-passed-argument-is-not-null)
- [Error Handling](https://dart.dev/language/error-handling)
