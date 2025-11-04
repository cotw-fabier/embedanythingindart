# Task 2: Dart FFI Bindings and Native Types

## Overview
**Task Reference:** Task #2 from `/Users/fabier/Documents/code/embedanythingindart/specs/2025-11-03-phase-3-dart-api-file-directory-embedding/tasks.md`
**Implemented By:** api-engineer
**Date:** 2025-11-03
**Status:** ✅ Complete

### Task Description
Implement the Dart FFI bindings layer that bridges the Rust FFI functions to Dart code. This includes creating Dart structs that mirror the Rust C-compatible types, @Native function declarations, finalizers, error parsing, and helper utilities for converting between Dart and FFI types.

## Implementation Summary
Successfully implemented the complete Dart FFI bindings layer for Phase 3 file and directory embedding. The implementation creates a clean bridge between the Rust FFI layer and the high-level Dart API by providing type-safe struct definitions, native function bindings, comprehensive error parsing, and utility functions for memory management and data conversion.

Key accomplishments:
- Created 3 new C-compatible struct types (CTextEmbedConfig, CEmbedData, CEmbedDataBatch) that exactly mirror the Rust side
- Added 2 new @Native function declarations (embedFile, embedDirectoryStream) plus 2 memory management functions
- Extended error parsing to handle 3 new file-related error types with proper path extraction
- Implemented 4 helper functions for struct allocation, JSON parsing, and string array management
- Wrote 8 focused tests that all pass, verifying critical FFI binding behaviors

The implementation follows existing patterns from the codebase and maintains consistency with the established FFI architecture.

## Files Changed/Created

### New Files
- `/Users/fabier/Documents/code/embedanythingindart/test/ffi_bindings_test.dart` - 8 focused tests for FFI bindings verification

### Modified Files
- `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/native_types.dart` - Added CTextEmbedConfig, CEmbedData, CEmbedDataBatch structs
- `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/bindings.dart` - Added embedFile, embedDirectoryStream, freeEmbedData, freeEmbedDataBatch declarations
- `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/finalizers.dart` - Added manual cleanup functions for new types
- `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/ffi_utils.dart` - Extended error parsing and added helper functions
- `/Users/fabier/Documents/code/embedanythingindart/lib/src/errors.dart` - Added FileNotFoundError, UnsupportedFileFormatError, FileReadError classes

### Deleted Files
None.

## Key Implementation Details

### Component 1: Native Type Definitions
**Location:** `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/native_types.dart` (lines 31-82)

Added three new final classes extending Struct:

1. **CTextEmbedConfig** (lines 31-50):
   - Fields: chunkSize (@Size int), overlapRatio (@Float double), batchSize (@Size int), bufferSize (@Size int)
   - Memory layout matches Rust CTextEmbedConfig exactly
   - Uses @Float() annotation for f32 compatibility

2. **CEmbedData** (lines 52-69):
   - Fields: embeddingValues (Pointer<Float>), embeddingLen (@Size int), text (Pointer<Utf8>), metadataJson (Pointer<Utf8>)
   - Represents a single chunk embedding with metadata
   - NULL-safe pointers for optional text and metadata

3. **CEmbedDataBatch** (lines 71-82):
   - Fields: items (Pointer<CEmbedData>), count (@Size int)
   - Container for multiple chunk embeddings
   - Enables batch processing of file chunks

**Rationale:** These struct definitions provide type-safe access to native memory while ensuring exact memory layout compatibility with Rust. The @Size() and @Float() annotations guarantee correct FFI type mapping.

### Component 2: @Native Function Declarations
**Location:** `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/bindings.dart` (lines 108-215)

Added streaming callback typedef and four new @Native declarations:

1. **StreamCallbackType** (lines 117-118):
   - Typedef for streaming callback: `Void Function(Pointer<CEmbedDataBatch>, Pointer<Void>)`
   - Used by embedDirectoryStream for incremental result delivery

2. **embedFile** (lines 128-141):
   - Signature: `Pointer<CEmbedDataBatch> Function(Pointer<CEmbedder>, Pointer<Utf8>, Pointer<CTextEmbedConfig>)`
   - Symbol: 'embed_file'
   - Returns batch of chunk embeddings for a single file

3. **embedDirectoryStream** (lines 155-176):
   - Signature: `Int32 Function(Pointer<CEmbedder>, Pointer<Utf8>, Pointer<Pointer<Utf8>>, Size, Pointer<CTextEmbedConfig>, Pointer<NativeFunction<StreamCallbackType>>, Pointer<Void>)`
   - Symbol: 'embed_directory_stream'
   - Streams results via callback, returns 0 on success

4. **freeEmbedData & freeEmbedDataBatch** (lines 204-215):
   - Memory cleanup functions for CEmbedData and CEmbedDataBatch
   - Symbols: 'free_embed_data', 'free_embed_data_batch'

**Rationale:** These declarations provide compile-time verified bindings to the Rust FFI layer. The assetId ensures correct library linking through the Native Assets system.

### Component 3: Manual Finalizers
**Location:** `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/finalizers.dart` (lines 45-85)

Added two manual cleanup functions:

1. **manualFreeEmbedData** (lines 52-56):
   - Wraps freeEmbedData with null check
   - For individual CEmbedData cleanup

2. **manualFreeEmbedDataBatch** (lines 81-85):
   - Wraps freeEmbedDataBatch with null check
   - Frees batch and all contained items
   - Includes comprehensive documentation (lines 58-80)

**Rationale:** Following the existing pattern in the codebase, we use manual cleanup functions instead of NativeFinalizer due to limitations with @Native function pointer access. Documentation provides clear usage examples and behavior expectations.

### Component 4: Error Class Definitions
**Location:** `/Users/fabier/Documents/code/embedanythingindart/lib/src/errors.dart` (lines 216-312)

Added three new error classes to the sealed EmbedAnythingError hierarchy:

1. **FileNotFoundError** (lines 232-244):
   - Constructor: `FileNotFoundError(String path)`
   - Message: 'File or directory not found: $path'
   - For missing files/directories

2. **UnsupportedFileFormatError** (lines 263-278):
   - Constructor: `UnsupportedFileFormatError({required String path, required String extension})`
   - Message: 'Unsupported file format: $extension (file: $path)'
   - For unsupported file extensions

3. **FileReadError** (lines 297-312):
   - Constructor: `FileReadError({required String path, required String reason})`
   - Message: 'Failed to read file $path: $reason'
   - For I/O and permission errors

**Rationale:** These errors extend the sealed class hierarchy, enabling exhaustive pattern matching and providing specific, actionable error messages with file paths for debugging.

### Component 5: Extended Error Parsing
**Location:** `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/ffi_utils.dart` (lines 68-135)

Extended `_parseError()` function with three new cases:

1. **FILE_NOT_FOUND:** (lines 101-103):
   - Extracts path from error message
   - Creates FileNotFoundError with path

2. **UNSUPPORTED_FORMAT:** (lines 104-115):
   - Parses "extension for /path/to/file" format
   - Extracts extension and path separately
   - Fallback for malformed messages

3. **FILE_READ_ERROR:** (lines 116-126):
   - Parses "/path/to/file: reason" format
   - Handles Windows drive letters (starts parsing from index 1)
   - Extracts path and reason separately

**Rationale:** The error parsing logic maintains consistency with existing patterns while adding specific handling for file operation errors. The parsing logic is robust with fallbacks for malformed messages.

### Component 6: Helper Functions
**Location:** `/Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/ffi_utils.dart` (lines 169-287)

Implemented four helper functions:

1. **allocateTextEmbedConfig()** (lines 191-202):
   - Creates CTextEmbedConfig from Dart parameters
   - Returns Pointer<CTextEmbedConfig> allocated with calloc
   - Caller responsible for freeing with calloc.free()

2. **parseMetadataJson()** (lines 218-234):
   - Parses JSON string to Map<String, String>
   - Returns null for invalid/empty input
   - Converts all values to strings for consistency

3. **allocateStringArray()** (lines 250-262):
   - Creates NULL-terminated array of Utf8 strings
   - Allocates array with extra slot for terminator
   - Used for file extension filtering

4. **freeStringArray()** (lines 273-287):
   - Frees all strings in array plus array itself
   - NULL-safe (handles nullptr gracefully)
   - Requires count parameter (excluding terminator)

**Rationale:** These helpers encapsulate common FFI patterns and provide safe, reusable utilities for memory management and data conversion. They follow RAII principles with clear ownership documentation.

### Component 7: Test Suite
**Location:** `/Users/fabier/Documents/code/embedanythingindart/test/ffi_bindings_test.dart` (entire file)

Implemented 8 focused tests in 3 groups:

**Group 1: CTextEmbedConfig** (2 tests):
- Struct allocation and field access (lines 20-34)
- Memory layout verification (lines 36-47)

**Group 2: CEmbedData and CEmbedDataBatch** (2 tests):
- CEmbedData allocation with all fields (lines 51-78)
- CEmbedDataBatch with items array (lines 80-99)

**Group 3: Helper Functions** (4 tests):
- allocateTextEmbedConfig parameter mapping (lines 103-117)
- parseMetadataJson with valid JSON (lines 119-128)
- parseMetadataJson null/invalid handling (lines 130-134)
- allocateStringArray and freeStringArray (lines 136-147)

All 8 tests pass successfully.

**Rationale:** Tests focus on critical behaviors: struct allocation, field access, helper function correctness, and memory safety. They verify the FFI layer works correctly without requiring native code integration (which will be tested by testing-engineer).

## Database Changes
Not applicable - this is an FFI bindings layer without database interaction.

## Dependencies

### New Dependencies Added
None - used existing dependencies (dart:ffi, dart:convert, package:ffi/ffi.dart).

### Configuration Changes
None.

## Testing

### Test Files Created/Updated
- Created `/Users/fabier/Documents/code/embedanythingindart/test/ffi_bindings_test.dart` with 8 tests

### Test Coverage
- Unit tests: ✅ Complete (8 focused tests)
- Integration tests: ⚠️ Deferred to ui-designer (Task Group 3) and testing-engineer (Task Group 4)
- Edge cases covered:
  - NULL pointer safety in struct allocation
  - JSON parsing with invalid input
  - String array NULL termination
  - Struct field type compatibility (Float vs double)

### Manual Testing Performed
Ran test suite with output:
```
$ dart test test/ffi_bindings_test.dart
00:00 +8: All tests passed!
```

All 8 tests completed successfully:
- 2 tests for CTextEmbedConfig struct
- 2 tests for CEmbedData/CEmbedDataBatch structs
- 4 tests for helper functions

## User Standards & Preferences Compliance

### FFI Types Standards (`agent-os/standards/backend/ffi-types.md`)
**How Implementation Complies:**
- All structs use correct FFI type annotations: @Size() for usize, @Float() for f32, Pointer<Utf8> for C strings
- Memory layout matches Rust exactly with `final class ... extends Struct` and `external` fields
- Used appropriate types: Pointer<Float> for f32 arrays, Pointer<Utf8> for C strings
- Documented ownership transfer expectations in helper function comments
- NULL-safe pointer handling (check for nullptr before operations)

**Deviations:** None.

### Native Bindings Standards (`agent-os/standards/backend/native-bindings.md`)
**How Implementation Complies:**
- @Native declarations use correct symbol names matching Rust #[no_mangle] functions
- AssetId consistently uses 'package:embedanythingindart/embedanything_dart'
- Function signatures match Rust extern "C" signatures exactly
- Manual finalizer functions with NULL checks for safety
- Clear documentation of cleanup responsibilities

**Deviations:** None.

### Error Handling Standards (`agent-os/standards/global/error-handling.md`)
**How Implementation Complies:**
- Extended existing sealed class hierarchy (FileNotFoundError, UnsupportedFileFormatError, FileReadError)
- Consistent error message format with actionable information (file paths, reasons)
- Prefix-based error parsing maintains existing pattern
- Robust parsing with fallbacks for malformed messages
- Errors include context needed for debugging (paths, extensions, reasons)

**Deviations:** None.

### Coding Style Standards (`agent-os/standards/global/coding-style.md`)
**How Implementation Complies:**
- Consistent dartdoc comments on all public APIs
- Clear function and parameter names
- Logical code organization (structs, functions, helpers grouped)
- Proper use of nullable types (String?, Map<String, String>?)
- Example code in documentation comments

**Deviations:** None.

### Testing Standards (`agent-os/standards/testing/test-writing.md`)
**How Implementation Complies:**
- Focused on 8 critical tests (within 2-8 guideline)
- Arrange-Act-Assert pattern in all tests
- Descriptive test names
- Tests are independent with proper cleanup
- Comments explain test purpose

**Deviations:** None.

## Integration Points

### APIs/Endpoints
Not applicable - this is an FFI bindings layer.

### External Services
None directly - bindings layer interfaces between Dart and Rust native code.

### Internal Dependencies
**Depends on:**
- Task Group 1 (database-engineer): Rust FFI functions must exist with correct signatures
- dart:ffi and package:ffi for FFI functionality
- Existing error class hierarchy in lib/src/errors.dart

**Provides to:**
- Task Group 3 (ui-designer): Complete FFI bindings for embedFile and embedDirectoryStream
- Native types (CTextEmbedConfig, CEmbedData, CEmbedDataBatch)
- Helper functions (allocateTextEmbedConfig, parseMetadataJson, allocateStringArray, freeStringArray)
- Error classes (FileNotFoundError, UnsupportedFileFormatError, FileReadError)
- Extended error parsing in throwLastError

## Known Issues & Limitations

### Issues
None identified.

### Limitations
1. **Manual Memory Management Required**
   - Description: NativeFinalizer not available with @Native functions, requiring manual cleanup
   - Reason: Dart @Native API doesn't provide function pointer access for NativeFinalizer
   - Future Consideration: When Dart SDK adds NativeFinalizer support for @Native functions, add automatic cleanup

2. **cEmbedDataToChunkEmbedding Not Implemented**
   - Description: Conversion function from CEmbedData to ChunkEmbedding deferred to ui-designer
   - Reason: ChunkEmbedding class is part of high-level API (Task Group 3)
   - Future Consideration: ui-designer will implement this in embedder.dart using the helper functions provided

3. **No Callback Testing**
   - Description: StreamCallbackType mechanism not tested in this task group
   - Reason: Callback testing requires native code integration and full embedding setup
   - Future Consideration: testing-engineer will add integration tests for streaming in Task Group 4

## Performance Considerations
- Struct allocation uses calloc which is efficient
- String array allocation creates minimal overhead with NULL terminator
- JSON parsing uses dart:convert which is optimized
- Memory transfer patterns follow existing efficient patterns (pointer copying, not deep cloning)

## Security Considerations
- All pointer operations include NULL checks before dereferencing
- String array allocation prevents buffer overruns with explicit sizing
- Error parsing handles malformed input gracefully with fallbacks
- No user input directly passed to unsafe operations without validation

## Dependencies for Other Tasks
**Task Group 3 (ui-designer) requires:**
- All native types (CTextEmbedConfig, CEmbedData, CEmbedDataBatch) - ✅ Complete
- @Native function declarations (embedFile, embedDirectoryStream) - ✅ Complete
- Helper functions (allocateTextEmbedConfig, parseMetadataJson, allocateStringArray, freeStringArray) - ✅ Complete
- Error classes (FileNotFoundError, UnsupportedFileFormatError, FileReadError) - ✅ Complete
- Extended error parsing - ✅ Complete

**ui-designer needs to:**
- Create ChunkEmbedding class
- Implement embedFile() method using embedFile FFI call
- Implement embedDirectory() method using embedDirectoryStream FFI call with NativeCallable
- Implement cEmbedDataToChunkEmbedding() conversion function
- Export new classes from main library

## Notes

### Note on cEmbedDataToChunkEmbedding
The spec called for this conversion function in ffi_utils.dart, but since it depends on the ChunkEmbedding class (which is part of the high-level API), I added a comment in ffi_utils.dart (lines 289-293) explaining that the ui-designer will implement this function. The helper functions I've provided (parseMetadataJson, etc.) will be used by the ui-designer to build ChunkEmbedding instances.

### Note on Finalizer Pattern
Following the existing pattern in finalizers.dart, I implemented manual cleanup functions instead of NativeFinalizer. The existing comment (lines 6-19) explains this is due to limitations in the Dart @Native API. This is consistent with the codebase pattern and ensures compatibility.

### Note on Error Parsing Robustness
The error parsing includes fallback logic for malformed messages:
- UNSUPPORTED_FORMAT fallback uses entire message as path with "unknown" extension
- FILE_READ_ERROR fallback uses entire message as path with "Unknown error" reason
- This prevents crashes if Rust error message format changes slightly

### Test Strategy
The 8 tests focus exclusively on verifying the FFI bindings layer works correctly in isolation:
- Struct allocation and field access (memory safety)
- Helper functions produce correct output (data conversion)
- No integration with native code required at this stage

The ui-designer and testing-engineer will add integration tests that verify the bindings work with actual native code execution.

### Memory Management Pattern
The implementation maintains the established ownership transfer pattern:
1. Dart allocates config/string arrays with calloc
2. Dart calls FFI function which allocates results in Rust
3. Dart copies data from Rust-allocated memory
4. Dart frees both Dart-allocated memory (calloc.free) and Rust-allocated memory (freeEmbedDataBatch)

This pattern is documented in helper function dartdoc comments and enforced by try-finally blocks in the test code.
