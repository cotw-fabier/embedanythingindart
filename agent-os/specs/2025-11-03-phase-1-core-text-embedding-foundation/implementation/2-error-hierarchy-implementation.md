# Task 2: Typed Error Hierarchy

## Overview
**Task Reference:** Task #2 from `agent-os/specs/2025-11-03-phase-1-core-text-embedding-foundation/tasks.md`
**Implemented By:** api-engineer
**Date:** 2025-11-03
**Status:** ✅ Complete

### Task Description
Implement a typed error hierarchy using Dart 3.0's sealed classes to replace the generic `EmbedAnythingException` with specific error types that enable exhaustive pattern matching and provide better error context for library users.

## Implementation Summary
This implementation establishes a comprehensive typed error hierarchy for the EmbedAnythingInDart library, replacing the previous generic exception approach with specific error types that map to different failure modes. The solution uses Dart 3.0's sealed class feature to enable exhaustive pattern matching and implements a prefix-based error message parsing system to bridge the FFI boundary between Rust and Dart.

The implementation includes error type mapping logic in the FFI utils layer that parses error prefixes (MODEL_NOT_FOUND:, INVALID_CONFIG:, etc.) from Rust error messages and instantiates the appropriate typed error. Rust error messages were updated to include these type-indicating prefixes while maintaining descriptive context about the operation and failure reason. The sealed class hierarchy ensures compile-time exhaustiveness checking when handling errors with switch expressions or pattern matching.

## Files Changed/Created

### New Files
- `lib/src/errors.dart` - Sealed class error hierarchy with 5 concrete error types and comprehensive documentation
- `test/error_test.dart` - 8 focused tests validating error type behavior and pattern matching

### Modified Files
- `lib/src/ffi/ffi_utils.dart` - Added error message parsing logic and typed error throwing; maintained backward compatibility with legacy `EmbedAnythingException`
- `lib/embedanythingindart.dart` - Exported new error types from errors.dart for public API access
- `rust/src/lib.rs` - Updated error messages to include type prefixes (MODEL_NOT_FOUND:, INVALID_CONFIG:, EMBEDDING_FAILED:, MULTI_VECTOR:, FFI_ERROR:) with contextual information
- `agent-os/specs/2025-11-03-phase-1-core-text-embedding-foundation/tasks.md` - Marked all Task 2 sub-tasks as complete

### Deleted Files
None

## Key Implementation Details

### Sealed Class Error Hierarchy
**Location:** `lib/src/errors.dart`

Created a sealed class `EmbedAnythingError` that implements `Exception` with five concrete subtypes:

1. **ModelNotFoundError**: Thrown when a HuggingFace model ID doesn't exist or can't be downloaded (e.g., 404 errors)
2. **InvalidConfigError**: Thrown for configuration validation failures (empty model IDs, invalid parameters)
3. **EmbeddingFailedError**: Thrown when embedding generation fails (model inference errors, processing failures)
4. **MultiVectorNotSupportedError**: Thrown when encountering multi-vector embeddings from late-interaction models
5. **FFIError**: Generic FFI operation failures with operation context and optional native error message

Each error type includes:
- Descriptive message fields relevant to the error type
- Custom `toString()` implementation for developer-friendly output
- Comprehensive dartdoc with examples showing when the error is thrown
- Preservation of error context (model IDs, field names, operation names, etc.)

**Rationale:** Sealed classes provide compile-time exhaustiveness checking for pattern matching, ensuring developers handle all error cases. Specific error types enable targeted error recovery strategies (e.g., retry on network errors vs. fail fast on invalid config).

### FFI Error Message Parsing
**Location:** `lib/src/ffi/ffi_utils.dart`

Implemented `_parseError()` function that parses error message prefixes from Rust:

```dart
if (errorMessage.startsWith('MODEL_NOT_FOUND:')) {
  final modelId = errorMessage.substring('MODEL_NOT_FOUND:'.length).trim();
  return ModelNotFoundError(modelId);
} else if (errorMessage.startsWith('INVALID_CONFIG:')) {
  // Parse field:reason format
  final parts = errorMessage.substring('INVALID_CONFIG:'.length).trim();
  final colonIndex = parts.indexOf(':');
  if (colonIndex != -1) {
    final field = parts.substring(0, colonIndex).trim();
    final reason = parts.substring(colonIndex + 1).trim();
    return InvalidConfigError(field: field, reason: reason);
  }
  // Fallback for simple format
  return InvalidConfigError(field: 'unknown', reason: parts);
}
// ... other error types
else {
  // Fallback: treat unprefixed errors as FFIError
  return FFIError(operation: operation, nativeError: errorMessage);
}
```

Updated `throwLastError()` to take an operation description parameter and use `_parseError()` to determine the correct error type before throwing.

**Rationale:** Prefix-based parsing enables the FFI layer to remain type-agnostic while still providing rich error types to Dart. The fallback to FFIError ensures all errors are caught even if Rust sends an unexpected format.

### Rust Error Message Formatting
**Location:** `rust/src/lib.rs`

Updated all error paths in Rust FFI functions to use prefixed error messages:

- **Model loading (404 detection)**: `"MODEL_NOT_FOUND: {model_id}"` when error string contains "404"
- **Config validation**: `"INVALID_CONFIG: field: reason"` for null/invalid inputs
- **Embedding failures**: `"EMBEDDING_FAILED: {descriptive message}"` for processing errors
- **Multi-vector detection**: `"MULTI_VECTOR: {message}"` when encountering unsupported embedding types
- **FFI errors**: `"FFI_ERROR: {message}"` for pointer/runtime failures

Example from model loading:
```rust
Err(e) => {
    let error_str = e.to_string().to_lowercase();
    // Check if error indicates model not found (404 status code)
    if error_str.contains("404") {
        set_last_error(&format!("MODEL_NOT_FOUND: {}", model_id_str));
    } else {
        set_last_error(&format!("EMBEDDING_FAILED: Failed to load model '{}': {}", model_id_str, e));
    }
    std::ptr::null_mut()
}
```

**Rationale:** Prefixing error messages at the source ensures consistent formatting and makes the Dart parsing logic straightforward. The `.to_lowercase()` check for "404" handles various HTTP error message formats from the upstream library.

## Database Changes (if applicable)
Not applicable - this is an FFI library without database components.

## Dependencies (if applicable)

### New Dependencies Added
None - implementation uses only standard Dart features (sealed classes, pattern matching).

### Configuration Changes
None

## Testing

### Test Files Created/Updated
- `test/error_test.dart` - Created with 8 focused tests covering all error types

### Test Coverage
- Unit tests: ✅ Complete
  - All 5 error types instantiate correctly
  - Error messages contain expected content
  - Pattern matching works with sealed class
  - Model not found errors thrown for invalid models
  - toString() provides developer-friendly output
- Integration tests: ✅ Complete
  - FFI layer correctly maps Rust error prefixes to Dart types
  - ModelNotFoundError thrown for 404 errors from HuggingFace
- Edge cases covered:
  - Error pattern matching with switch expressions
  - All errors implement Exception
  - All errors extend EmbedAnythingError base class

### Manual Testing Performed
1. Attempted to load invalid model ID `invalid/model/that/does/not/exist/xyz123`
2. Verified ModelNotFoundError is thrown (not generic FFIError)
3. Confirmed error message includes the invalid model ID
4. Tested pattern matching on error types in catch blocks
5. Verified cache clearing was necessary for Rust changes to take effect (noted for future development)

**Key Discovery:** Native assets system caches compiled binaries aggressively. After updating Rust code, tests continued failing until cache was cleared with `rm -rf .dart_tool/native_assets_builder && cargo clean`. This will be documented in troubleshooting guide.

## User Standards & Preferences Compliance

### agent-os/standards/global/error-handling.md
**File Reference:** `agent-os/standards/global/error-handling.md`

**How Implementation Complies:**
The implementation follows the FFI error handling standards by creating a custom exception hierarchy (`EmbedAnythingError` and its subtypes) instead of using generic exceptions. Error messages from Rust are mapped to meaningful Dart exception types with descriptive context. The sealed class pattern enables Result-type-like exhaustive error handling through pattern matching. Stack traces are preserved because Dart's exception system automatically captures them when errors are thrown. Native error codes/messages are included in error types (e.g., `FFIError.nativeError` field).

**Deviations (if any):**
Minor deviation: We use exception throwing rather than a Result<T, E> type as suggested in the standards. This was chosen to maintain consistency with existing Dart patterns in the library and because sealed classes provide similar exhaustiveness guarantees through pattern matching.

### agent-os/standards/global/conventions.md
**File Reference:** `agent-os/standards/global/conventions.md`

**How Implementation Complies:**
The error hierarchy is placed in `lib/src/errors.dart` following the standard package structure for implementation details. All error classes use PascalCase naming (ModelNotFoundError, InvalidConfigError, etc.). Public exports are added to `lib/embedanythingindart.dart` to provide clean API surface. Comprehensive dartdoc comments document when each error is thrown with runnable examples. The `EmbedAnythingException` class is marked deprecated but maintained for backward compatibility.

**Deviations (if any):**
None

### agent-os/standards/testing/test-writing.md
**File Reference:** `agent-os/standards/testing/test-writing.md`

**How Implementation Complies:**
Error tests follow AAA (Arrange-Act-Assert) pattern with clear test structure. Test names are descriptive ("ModelNotFoundError is thrown for invalid model ID"). Tests are independent with no shared state. The test file (`test/error_test.dart`) is separate from main integration tests, focusing specifically on error behavior. Tests verify both unit behavior (error instantiation, message formatting) and integration behavior (FFI layer mapping). The tests use `expect` with `throwsA` matchers to verify correct error types are thrown.

**Deviations (if any):**
None

## Integration Points (if applicable)

### APIs/Endpoints
Not applicable - internal library error handling.

### External Services
- Interacts with HuggingFace Hub during model loading (generates ModelNotFoundError on 404 responses)

### Internal Dependencies
- `lib/src/ffi/ffi_utils.dart` depends on `lib/src/errors.dart` for error types
- `lib/src/embedder.dart` calls `throwLastError()` which returns typed errors
- Rust FFI layer (`rust/src/lib.rs`) sets error messages read by Dart FFI utils

## Known Issues & Limitations

### Issues
None identified

### Limitations
1. **Error Message Parsing Robustness**
   - Description: Current implementation relies on string prefix matching. If Rust error messages change format, parsing may fail silently (fall back to FFIError).
   - Impact: Low - fallback to FFIError ensures no errors are lost, just less specific
   - Workaround: None needed - fallback behavior is acceptable
   - Future Consideration: Could implement versioned error protocol or structured error serialization across FFI boundary

2. **Limited Error Context**
   - Description: Some errors (like EmbeddingFailedError) have only a reason string, not structured fields
   - Reason: Rust errors from upstream library are often opaque strings
   - Future Consideration: Add more structured error types as upstream library improves

## Performance Considerations
Error parsing adds minimal overhead (simple string prefix checks and substring operations). Error paths are not on the hot path since they only execute on failures. The sealed class approach has zero runtime overhead compared to regular classes - exhaustiveness checking is purely compile-time.

## Security Considerations
Error messages intentionally include contextual information (model IDs, field names, operations) to aid debugging. This is acceptable since the library runs locally and error messages don't expose sensitive data. If future errors might contain sensitive information (e.g., authentication tokens), those fields should be sanitized before inclusion in error messages.

## Dependencies for Other Tasks
- Task Group 3 (ModelConfig) depends on InvalidConfigError for validation
- Task Group 4 (Test Coverage) will expand error test coverage
- Task Group 5 (Documentation) will document error handling patterns for users

## Notes

### Cache Clearing Discovery
During implementation, discovered that native assets system aggressively caches compiled Rust binaries. After updating Rust error message formatting, tests continued to fail with old error formats until cache was manually cleared:

```bash
rm -rf .dart_tool/native_assets_builder && cargo clean
```

This is important for future development - Rust changes may not be reflected in tests without cache clearing. Will be added to TROUBLESHOOTING.md in Task Group 5.

### Pattern Matching Examples
The sealed class enables elegant error handling:

```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(...);
} on EmbedAnythingError catch (e) {
  switch (e) {
    case ModelNotFoundError():
      print('Model ${e.modelId} not found - check model ID');
    case InvalidConfigError():
      print('Config error: ${e.field} - ${e.reason}');
    case EmbeddingFailedError():
      print('Embedding failed: ${e.reason}');
    case MultiVectorNotSupportedError():
      print('Multi-vector embeddings not supported');
    case FFIError():
      print('FFI error in ${e.operation}: ${e.nativeError}');
  }
}
```

Dart compiler ensures all cases are covered (exhaustiveness checking).

### Backward Compatibility
The legacy `EmbedAnythingException` class is maintained but marked deprecated to provide migration path for existing users. New code should use typed errors, but old code continues to work.
