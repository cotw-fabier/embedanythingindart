# Task Breakdown: Phase 3 - File and Directory Embedding API

## Overview
Total Tasks: 4 task groups with 27 sub-tasks
Assigned roles: database-engineer (Rust FFI), api-engineer (Dart FFI bindings), ui-designer (High-level API), testing-engineer (Testing)

**Important Testing Constraints:**
- Each implementation task group (1-3) writes 2-8 focused tests maximum
- Tests cover only critical behaviors, not exhaustive coverage
- Task group 4 (testing-engineer) adds maximum 10 additional strategic tests to fill gaps
- Total expected tests: approximately 16-34 tests maximum
- Focus on integration tests over unit tests

## Task List

### Rust FFI Layer

#### Task Group 1: Rust FFI Types and Functions
**Assigned implementer:** database-engineer
**Dependencies:** None
**Complexity:** Medium-High

- [x] 1.0 Complete Rust FFI layer for file/directory embedding
  - [x] 1.1 Write 2-8 focused tests for Rust FFI functions
    - Limit to 2-8 highly focused tests maximum
    - Test only critical FFI behaviors (e.g., CEmbedData conversion, embed_file success, embed_directory_stream callback)
    - Use Rust test framework to verify FFI function contracts
    - Skip exhaustive coverage of all scenarios
  - [x] 1.2 Add C-compatible structs to rust/src/lib.rs
    - Add `CTextEmbedConfig` struct with fields: chunk_size, overlap_ratio, batch_size, buffer_size
    - Add `CEmbedData` struct with fields: embedding_values (*mut f32), embedding_len, text (*mut c_char), metadata_json (*mut c_char)
    - Add `CEmbedDataBatch` struct with fields: items (*mut CEmbedData), count
    - Use `#[repr(C)]` for all structs
    - Document struct layout and ownership semantics
  - [x] 1.3 Implement CEmbedData conversion from Rust EmbedData
    - Create `embed_data_to_c()` helper function
    - Extract Vec<f32> from EmbeddingResult::DenseVector
    - Convert Option<String> text to *mut c_char (NULL if None)
    - Serialize HashMap<String, String> metadata to JSON string using serde_json
    - Use std::mem::forget() for ownership transfer to Dart
    - Handle MultiVector case by returning error with "MULTI_VECTOR_NOT_SUPPORTED:" prefix
  - [x] 1.4 Implement embed_file() FFI function
    - Signature: `pub extern "C" fn embed_file(embedder: *const CEmbedder, file_path: *const c_char, config: *const CTextEmbedConfig) -> *mut CEmbedDataBatch`
    - Add #[no_mangle] attribute
    - Wrap in panic::catch_unwind() for safety
    - Validate pointers before dereferencing
    - Convert C strings to Rust Path
    - Build TextEmbedConfig from CTextEmbedConfig
    - Call Arc<Embedder>::embed_file() using RUNTIME.block_on()
    - Convert Vec<EmbedData> to CEmbedDataBatch
    - Return NULL and set error on failure
    - Document error prefixes: "FILE_NOT_FOUND:", "UNSUPPORTED_FORMAT:", "FILE_READ_ERROR:", "EMBEDDING_FAILED:"
  - [x] 1.5 Implement embed_directory_stream() FFI function
    - Signature: `pub extern "C" fn embed_directory_stream(embedder: *const CEmbedder, directory_path: *const c_char, extensions: *const *const c_char, extensions_count: usize, config: *const CTextEmbedConfig, callback: StreamCallback, callback_context: *mut c_void) -> i32`
    - Add StreamCallback type alias: `type StreamCallback = extern "C" fn(*mut CEmbedDataBatch, *mut c_void);`
    - Wrap in panic::catch_unwind()
    - Convert C string array to Vec<String> for extensions
    - Create adapter closure that batches EmbedData and calls callback
    - Use RUNTIME.block_on() with Arc<Embedder>::embed_directory_stream()
    - Continue processing on individual file errors (log but don't stop)
    - Return 0 on success, -1 on failure
  - [x] 1.6 Implement memory management functions
    - Implement `free_embed_data(data: *mut CEmbedData)`
    - Implement `free_embed_data_batch(batch: *mut CEmbedDataBatch)`
    - Free all owned pointers: embedding_values, text, metadata_json
    - Free items array in batch
    - Add NULL pointer checks before freeing
    - Use Box::from_raw() to reclaim ownership and drop
  - [x] 1.7 Add serde_json dependency to Cargo.toml
    - Add: `serde_json = "1.0"`
    - Required for metadata HashMap to JSON conversion
  - [x] 1.8 Update error handling for new error types
    - Add error prefix constants for file operations
    - Update set_last_error() calls to use appropriate prefixes
    - Ensure all error paths in embed_file and embed_directory_stream set errors
  - [x] 1.9 Ensure Rust FFI layer tests pass
    - Run ONLY the 2-8 tests written in 1.1
    - Verify FFI functions don't panic
    - Verify memory management works correctly
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 1.1 pass
- All C-compatible structs are properly defined with #[repr(C)]
- embed_file() returns CEmbedDataBatch with correct chunk data
- embed_directory_stream() calls callback with batches
- Memory management functions free resources without leaks
- Errors are properly set with appropriate prefixes

---

### Dart FFI Bindings Layer

#### Task Group 2: Dart FFI Bindings and Native Types
**Assigned implementer:** api-engineer
**Dependencies:** Task Group 1
**Complexity:** Medium

- [x] 2.0 Complete Dart FFI bindings layer
  - [x] 2.1 Write 2-8 focused tests for FFI bindings
    - Limit to 2-8 highly focused tests maximum
    - Test only critical binding behaviors (e.g., CTextEmbedConfig struct allocation, embedFile FFI call, callback mechanism)
    - Skip exhaustive testing of all FFI edge cases
    - Focus on verifying bindings work with real native code
  - [x] 2.2 Add native types to lib/src/ffi/native_types.dart
    - Add `CTextEmbedConfig` final class extending Struct
    - Use @Size() for usize fields (chunkSize, batchSize, bufferSize)
    - Use external Float for overlapRatio
    - Add `CEmbedData` final class extending Struct
    - Add Pointer<Float> embeddingValues, @Size() embeddingLen
    - Add Pointer<Utf8> text and metadataJson
    - Add `CEmbedDataBatch` final class extending Struct
    - Add Pointer<CEmbedData> items and @Size() count
    - Follow existing pattern from CTextEmbedding and CTextEmbeddingBatch
  - [x] 2.3 Add @Native declarations to lib/src/ffi/bindings.dart
    - Add embedFile function declaration
    - Type: `Pointer<CEmbedDataBatch> Function(Pointer<CEmbedder>, Pointer<Utf8>, Pointer<CTextEmbedConfig>)`
    - Use assetId: 'package:embedanythingindart/embedanything_dart'
    - Add embedDirectoryStream function declaration
    - Type: `Int32 Function(Pointer<CEmbedder>, Pointer<Utf8>, Pointer<Pointer<Utf8>>, Size, Pointer<CTextEmbedConfig>, Pointer<NativeFunction<StreamCallbackType>>, Pointer<Void>)`
    - Add typedef StreamCallbackType: `Void Function(Pointer<CEmbedDataBatch>, Pointer<Void>)`
    - Add freeEmbedData function declaration
    - Add freeEmbedDataBatch function declaration
    - Follow existing pattern from embedText bindings
  - [x] 2.4 Add finalizers to lib/src/ffi/finalizers.dart
    - Create embedDataFinalizer using NativeFinalizer for freeEmbedData
    - Create embedDataBatchFinalizer using NativeFinalizer for freeEmbedDataBatch
    - Follow existing pattern from textEmbeddingFinalizer
    - Document finalizer behavior and timing
  - [x] 2.5 Extend error parsing in lib/src/ffi/ffi_utils.dart
    - Update _parseError() to handle new prefixes
    - Add case for "FILE_NOT_FOUND:" → FileNotFoundError
    - Add case for "UNSUPPORTED_FORMAT:" → UnsupportedFileFormatError
    - Add case for "FILE_READ_ERROR:" → FileReadError
    - Extract file path from error message for error constructors
    - Preserve existing error prefix handling
  - [x] 2.6 Add helper functions to lib/src/ffi/ffi_utils.dart
    - Add `allocateTextEmbedConfig()` to create CTextEmbedConfig struct from Dart params
    - Add `cEmbedDataToChunkEmbedding()` to convert CEmbedData to ChunkEmbedding
    - Add `parseMetadataJson()` to parse JSON string to Map<String, String>
    - Add `allocateStringArray()` to create NULL-terminated array of Utf8 strings
    - Add `freeStringArray()` to free allocated string array
    - Use calloc for memory allocation
    - Handle null values appropriately
  - [x] 2.7 Ensure FFI bindings tests pass
    - Run ONLY the 2-8 tests written in 2.1
    - Verify struct allocation and field access work
    - Verify FFI function calls don't crash
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 2.1 pass
- All native types correctly mirror Rust structs
- @Native declarations compile and link correctly
- Finalizers are properly registered
- Error parsing handles all new error types
- Helper functions correctly convert between Dart and FFI types

---

### High-Level Dart API

#### Task Group 3: Public Dart API Implementation
**Assigned implementer:** ui-designer
**Dependencies:** Task Group 2
**Complexity:** Medium-High

- [x] 3.0 Complete high-level Dart API
  - [x] 3.1 Write 2-8 focused tests for Dart API
    - Limit to 2-8 highly focused tests maximum
    - Test only critical API behaviors (e.g., ChunkEmbedding construction, embedFile with txt file, embedDirectory stream)
    - Skip exhaustive testing of all API scenarios
    - Focus on verifying public API works end-to-end
  - [x] 3.2 Create ChunkEmbedding class in lib/src/chunk_embedding.dart
    - Add properties: embedding (EmbeddingResult), text (String?), metadata (Map<String, String>?)
    - Add constructor with required embedding, optional text and metadata
    - Add convenience getter: filePath → metadata?['file_path']
    - Add convenience getter: page → int.tryParse(metadata?['page_number'])
    - Add convenience getter: chunkIndex → int.tryParse(metadata?['chunk_index'])
    - Add cosineSimilarity(ChunkEmbedding other) → embedding.cosineSimilarity(other.embedding)
    - Add comprehensive dartdoc comments with examples
    - Add toString() for debugging
  - [x] 3.3 Add error classes to lib/src/errors.dart
    - Add FileNotFoundError extending EmbedAnythingError
    - Constructor: FileNotFoundError(String path)
    - Message: 'File or directory not found: $path'
    - Add UnsupportedFileFormatError extending EmbedAnythingError
    - Constructor: UnsupportedFileFormatError({required String path, required String extension})
    - Message: 'Unsupported file format: $extension (file: $path)'
    - Add FileReadError extending EmbedAnythingError
    - Constructor: FileReadError({required String path, required String reason})
    - Message: 'Failed to read file $path: $reason'
    - Follow existing sealed class pattern from errors.dart
  - [x] 3.4 Implement embedFile() in lib/src/embedder.dart
    - Signature: `Future<List<ChunkEmbedding>> embedFile(String filePath, {int chunkSize = 1000, double overlapRatio = 0.0, int batchSize = 32})`
    - Add _checkDisposed() guard at start
    - Allocate CTextEmbedConfig using calloc
    - Set struct fields from parameters (bufferSize = 100)
    - Convert filePath to Utf8 using stringToCString
    - Call ffi.embedFile() with embedder handle, path, config
    - Check for nullptr result and throw error
    - Convert CEmbedDataBatch to List<ChunkEmbedding>
    - Loop through batch.items, call cEmbedDataToChunkEmbedding for each
    - Free native memory in finally block: config, filePath, batch
    - Add comprehensive dartdoc with Throws documentation
    - Include code example in dartdoc
  - [x] 3.5 Implement embedDirectory() in lib/src/embedder.dart
    - Signature: `Stream<ChunkEmbedding> embedDirectory(String directoryPath, {List<String>? extensions, int chunkSize = 1000, double overlapRatio = 0.0, int batchSize = 32})`
    - Add _checkDisposed() guard at start
    - Create StreamController<ChunkEmbedding>
    - Create NativeCallable for callback with signature matching StreamCallbackType
    - Callback implementation: convert CEmbedDataBatch to List<ChunkEmbedding>, add each to controller
    - Allocate CTextEmbedConfig using calloc
    - Allocate extensions array if provided using allocateStringArray
    - Convert directoryPath to Utf8
    - Call ffi.embedDirectoryStream() with callback.nativeFunction
    - Check return code and handle errors
    - Close stream controller after completion
    - Free resources in finally block: config, directoryPath, extensions, callback
    - On error in callback: use controller.addError() not throw
    - Add comprehensive dartdoc with streaming behavior documentation
    - Include code example showing stream consumption
  - [x] 3.6 Export new classes from lib/embedanythingindart.dart
    - Add: export 'src/chunk_embedding.dart';
    - Ensure FileNotFoundError, UnsupportedFileFormatError, FileReadError are exported via errors.dart
    - Maintain existing exports
  - [x] 3.7 Ensure high-level API tests pass
    - Run ONLY the 2-8 tests written in 3.1
    - Verify ChunkEmbedding class works correctly
    - Verify embedFile and embedDirectory public APIs work
    - Do NOT run the entire test suite at this stage

**Acceptance Criteria:**
- The 2-8 tests written in 3.1 pass
- ChunkEmbedding class is complete with all getters
- Error classes provide helpful messages
- embedFile() returns List<ChunkEmbedding> with correct data
- embedDirectory() returns Stream<ChunkEmbedding> that yields results
- All new classes are exported
- Dartdoc comments are comprehensive with examples

---

### Testing & Validation

#### Task Group 4: Comprehensive Test Coverage and Gap Analysis
**Assigned implementer:** testing-engineer
**Dependencies:** Task Groups 1-3
**Complexity:** Medium

- [x] 4.0 Review existing tests and fill critical gaps only
  - [x] 4.1 Create test fixtures in test/fixtures/
    - Create test/fixtures/sample.txt with multi-paragraph text
    - Create test/fixtures/sample.md with markdown content
    - Create test/fixtures/sample_dir/ with 3-5 test files (.txt, .md)
    - Ensure fixtures are committed to git
    - Document fixture purpose in test/fixtures/README.md
  - [x] 4.2 Review tests from Task Groups 1-3
    - Review the 2-8 tests written by database-engineer (Task 1.1)
    - Review the 2-8 tests written by api-engineer (Task 2.1)
    - Review the 2-8 tests written by ui-designer (Task 3.1)
    - Total existing tests: approximately 6-24 tests
    - Document test coverage in a brief summary
  - [x] 4.3 Analyze test coverage gaps for Phase 3 feature only
    - Identify critical user workflows lacking test coverage
    - Focus ONLY on gaps related to file/directory embedding
    - Do NOT assess entire application test coverage
    - Prioritize end-to-end workflows: embedFile with real file, embedDirectory stream consumption, error scenarios
    - Skip edge cases unless business-critical
  - [x] 4.4 Write up to 10 additional strategic tests maximum
    - Maximum 10 new tests to fill identified gaps
    - Focus on integration tests in test/embedanythingindart_test.dart
    - Recommended tests (pick most critical, maximum 10 total):
      1. embedFile() with .txt file - verify chunks, metadata, embeddings
      2. embedFile() with .md file - verify text extraction works
      3. embedDirectory() with test_dir - verify streaming yields all files
      4. embedDirectory() with extension filter - verify only .txt files processed
      5. embedFile() with non-existent file - verify FileNotFoundError
      6. embedFile() with invalid extension - verify UnsupportedFileFormatError
      7. embedDirectory() with non-existent dir - verify error handling
      8. ChunkEmbedding.cosineSimilarity() - verify vector comparison works
      9. Metadata parsing - verify filePath, chunkIndex getters work
      10. Memory cleanup - verify no leaks after multiple embedFile() calls
    - Do NOT write comprehensive coverage for all scenarios
    - Skip performance tests, accessibility tests unless critical
  - [x] 4.5 Run feature-specific tests only
    - Run ONLY tests related to Phase 3 feature (tests from 1.1, 2.1, 3.1, and 4.4)
    - Expected total: approximately 16-34 tests maximum
    - Do NOT run the entire application test suite
    - Verify all critical workflows pass
    - Fix any failing tests before marking complete
  - [x] 4.6 Update test documentation
    - Add test section to README.md if not present
    - Document how to run Phase 3 tests specifically
    - Document test fixture setup requirements
    - Keep documentation brief and actionable

**Acceptance Criteria:**
- All feature-specific tests pass (approximately 16-34 tests total)
- Critical user workflows for Phase 3 are covered
- No more than 10 additional tests added by testing-engineer
- Testing focused exclusively on Phase 3 file/directory embedding
- Test fixtures are properly set up and documented
- Documentation explains how to run Phase 3 tests

---

## Execution Order

Recommended implementation sequence:
1. **Rust FFI Layer** (Task Group 1) - Foundation for native functionality
2. **Dart FFI Bindings** (Task Group 2) - Bridge between Rust and Dart
3. **High-Level Dart API** (Task Group 3) - Public API for users
4. **Testing & Validation** (Task Group 4) - Comprehensive test coverage and gap analysis

## Dependencies Graph

```
Task Group 1 (Rust FFI)
    ↓
Task Group 2 (Dart FFI Bindings)
    ↓
Task Group 3 (High-Level API)
    ↓
Task Group 4 (Testing & Validation)
```

## Important Notes

### For database-engineer (Rust FFI):
- Follow existing patterns from rust/src/lib.rs (thread-local errors, panic catching, RUNTIME usage)
- Reference EmbedAnything API documentation for embed_file and embed_directory_stream signatures
- Test FFI functions in Rust before moving to Dart integration
- Memory management is critical - document ownership transfer clearly

### For api-engineer (Dart FFI Bindings):
- Follow existing patterns from lib/src/ffi/ (native_types.dart, bindings.dart, ffi_utils.dart)
- Ensure struct memory layout matches Rust exactly (#[repr(C)])
- Test struct allocation and field access before using in API
- Callback mechanism for streaming is complex - reference dart:ffi NativeCallable documentation

### For ui-designer (High-Level API):
- Follow existing patterns from lib/src/embedder.dart (_checkDisposed, try-finally cleanup)
- embedDirectory() Stream implementation is critical - ensure proper resource cleanup
- Dartdoc comments should include code examples
- Export all new public classes from main library file

### For testing-engineer (Testing):
- Focus on integration tests over unit tests
- Use real test files for file embedding tests
- Stream tests should verify incremental yielding behavior
- Memory leak tests can use simple repetition (run embedFile 100 times, check no crash)
- Do NOT attempt to achieve >90% coverage - focus on critical paths only

### Testing Philosophy:
- **During development** (Groups 1-3): Write 2-8 focused tests per group to verify critical functionality
- **Test validation** (Group 4): Add maximum 10 strategic tests to fill gaps
- **Total expected tests**: 16-34 tests maximum for entire Phase 3 feature
- **Focus**: Integration tests validating end-to-end workflows, not exhaustive unit test coverage

### Memory Management:
- All native resources MUST be freed (use try-finally blocks)
- Rust uses std::mem::forget() for ownership transfer
- Dart copies data then calls free functions
- NativeFinalizer provides backup cleanup but should not be primary mechanism

### Error Handling:
- Rust sets thread-local errors with prefixes: "FILE_NOT_FOUND:", "UNSUPPORTED_FORMAT:", "FILE_READ_ERROR:", "EMBEDDING_FAILED:"
- Dart parses prefixes and creates specific exception types
- embedFile() throws immediately on error
- embedDirectory() adds errors to stream using controller.addError()

### Streaming Implementation:
- Rust calls Dart callback multiple times with batches
- Dart NativeCallable stays alive until stream closes
- Must handle early stream cancellation (close resources)
- Callback should NOT throw - use controller.addError() for errors

## References

**Specification:** /Users/fabier/Documents/code/embedanythingindart/specs/2025-11-03-phase-3-dart-api-file-directory-embedding/spec.md

**Requirements:** /Users/fabier/Documents/code/embedanythingindart/specs/2025-11-03-phase-3-dart-api-file-directory-embedding/planning/requirements.md

**Standards:**
- /Users/fabier/Documents/code/embedanythingindart/agent-os/standards/global/tech-stack.md
- /Users/fabier/Documents/code/embedanythingindart/agent-os/standards/global/conventions.md
- /Users/fabier/Documents/code/embedanythingindart/agent-os/standards/testing/test-writing.md
- /Users/fabier/Documents/code/embedanythingindart/agent-os/standards/backend/rust-integration.md
- /Users/fabier/Documents/code/embedanythingindart/agent-os/standards/backend/ffi-types.md

**Existing Code Patterns:**
- Rust FFI: /Users/fabier/Documents/code/embedanythingindart/rust/src/lib.rs
- Dart FFI: /Users/fabier/Documents/code/embedanythingindart/lib/src/ffi/
- High-Level API: /Users/fabier/Documents/code/embedanythingindart/lib/src/embedder.dart
- Tests: /Users/fabier/Documents/code/embedanythingindart/test/embedanythingindart_test.dart
