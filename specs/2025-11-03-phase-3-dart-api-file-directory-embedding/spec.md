# Specification: Phase 3 - File and Directory Embedding API

## Goal
Extend the EmbedAnything Dart API to support file and directory embedding with automatic chunking, metadata extraction, and streaming for large directory operations. This enables users to embed document collections (PDF, TXT, MD, DOCX, HTML) and retrieve structured embeddings with associated text chunks and metadata.

## User Stories
- As a developer, I want to embed a single file (PDF, TXT, MD, DOCX, HTML) and receive back all text chunks with their embeddings and metadata, so I can build a searchable document index
- As a developer, I want to embed an entire directory of documents with optional filtering by extension, so I can process document collections efficiently
- As a developer, I want directory embedding to return a Stream that yields results incrementally, so I can process large directories without loading everything into memory at once
- As a developer, I want chunk metadata to include file path, chunk index, and page numbers (when applicable), so I can reference source documents when displaying search results
- As a developer, I want clear error messages for file not found, unsupported formats, and I/O errors, so I can handle failures gracefully

## Core Requirements

### Functional Requirements
- Add `embedFile()` method to EmbedAnything class that accepts a file path and returns `Future<List<ChunkEmbedding>>`
- Add `embedDirectory()` method to EmbedAnything class that accepts a directory path and returns `Stream<ChunkEmbedding>`
- Support all file formats handled by EmbedAnything Rust library: PDF, TXT, MD, DOCX, HTML
- Expose chunking configuration: `chunkSize` (default 1000), `overlapRatio` (default 0.0), `batchSize` (default 32)
- Support optional file extension filtering for directory operations (e.g., `['.pdf', '.txt']`)
- Extract and include metadata: file path (required), chunk index, page number (for PDFs)
- Ensure all file operations are async and non-blocking

### Non-Functional Requirements
- Memory efficient: Stream directory results to avoid loading all embeddings at once
- Performance: Leverage Rust-side parallel processing for batch operations
- Error resilience: Continue processing directory even if individual files fail (log errors but don't stop stream)
- Memory safety: Ensure proper cleanup of native resources using NativeFinalizer pattern
- API consistency: Mirror existing text embedding API design patterns

## Visual Design
No UI components - this is a pure API feature.

## Reusable Components

### Existing Code to Leverage
**Rust FFI Layer (rust/src/lib.rs):**
- Thread-local error storage pattern: `set_last_error()`, `get_last_error()`, `clear_last_error()`
- Tokio runtime initialization: `RUNTIME` static, `init_runtime()`
- Opaque handle pattern: `CEmbedder` wrapper around `Arc<Embedder>`
- Memory management pattern: `std::mem::forget()` for ownership transfer, paired free functions
- Panic safety pattern: `panic::catch_unwind()` wrapping all FFI functions

**Dart FFI Layer (lib/src/ffi/):**
- `native_types.dart`: Opaque types and C-compatible structs
- `bindings.dart`: @Native function declarations with assetId
- `ffi_utils.dart`: String conversion utilities (`withCString`, `stringToCString`, `freeCString`)
- `finalizers.dart`: NativeFinalizer registration for automatic cleanup
- `ffi_utils.dart`: Error parsing and typed exception throwing (`throwLastError`, `_parseError`)

**Error Handling (lib/src/errors.dart):**
- Sealed class hierarchy: `EmbedAnythingError` base class
- Existing errors: `ModelNotFoundError`, `InvalidConfigError`, `EmbeddingFailedError`, `MultiVectorNotSupportedError`, `FFIError`
- Error prefix parsing: "MODEL_NOT_FOUND:", "INVALID_CONFIG:", "EMBEDDING_FAILED:", "FFI_ERROR:"

**High-Level API (lib/src/embedder.dart):**
- Embedder lifecycle: Factory constructors, dispose pattern, `_checkDisposed()` guard
- FFI memory copying: `_copyFloatArray()` for safe transfer from Rust to Dart
- Batch processing pattern: String array allocation, cleanup in try-finally

**Result Types (lib/src/embedding_result.dart):**
- `EmbeddingResult` class with `values: List<double>`, `dimension` getter
- `cosineSimilarity()` implementation for vector comparison

### New Components Required
**Dart Side:**
- `ChunkEmbedding` class: Wrapper that includes embedding, text chunk, and metadata
- File operation error classes: `FileNotFoundError`, `UnsupportedFileFormatError`, `FileReadError`
- Stream adapter for directory embedding: Convert Rust callback-based streaming to Dart Stream
- Extension methods or utilities for metadata access (e.g., `filePath`, `page`, `chunkIndex` getters)

**Rust Side:**
- `CEmbedData` struct: C-compatible representation of EmbedData (embedding + text + metadata)
- `CEmbedDataBatch` struct: C-compatible array of CEmbedData
- `CTextEmbedConfig` struct: C-compatible representation of TextEmbedConfig
- `embed_file_ffi()`: FFI wrapper for `Embedder::embed_file()`
- `embed_directory_stream_ffi()`: FFI wrapper for `Embedder::embed_directory_stream()` with callback
- Stream callback mechanism: Rust calls Dart callback with batches of embeddings
- Memory management functions: `free_embed_data()`, `free_embed_data_batch()`, `free_text_embed_config()`
- Metadata serialization: Convert `HashMap<String, String>` to C-compatible key-value pairs or JSON string

**Why New Code is Needed:**
- Current FFI only handles simple text embeddings without metadata or chunk information
- No existing mechanism for streaming results from Rust to Dart via callbacks
- TextEmbedConfig requires complex struct with multiple optional fields
- EmbedData struct requires metadata HashMap conversion across FFI boundary

## Technical Approach

### Database
Not applicable - this is a pure embedding library without persistence.

### API Design

#### Dart Public API
```dart
// Add to existing EmbedAnything class in lib/src/embedder.dart
class EmbedAnything {
  // Existing methods unchanged...

  /// Embed a single file with chunking
  ///
  /// Returns all chunks with embeddings and metadata.
  /// Supported formats: PDF, TXT, MD, DOCX, HTML
  ///
  /// Parameters:
  /// - filePath: Path to file to embed
  /// - chunkSize: Maximum characters per chunk (default: 1000)
  /// - overlapRatio: Overlap between chunks 0.0-1.0 (default: 0.0)
  /// - batchSize: Batch size for embedding generation (default: 32)
  ///
  /// Throws:
  /// - FileNotFoundError: File does not exist
  /// - UnsupportedFileFormatError: File format not supported
  /// - FileReadError: Permission or I/O error reading file
  /// - EmbeddingFailedError: Embedding generation failed
  Future<List<ChunkEmbedding>> embedFile(
    String filePath, {
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  });

  /// Embed all files in a directory (streaming)
  ///
  /// Returns a stream that yields ChunkEmbeddings as they are generated.
  /// Files that fail to process will emit stream errors but won't stop processing.
  ///
  /// Parameters:
  /// - directoryPath: Path to directory to embed
  /// - extensions: Optional list of file extensions to include (e.g., ['.pdf', '.txt'])
  /// - chunkSize: Maximum characters per chunk (default: 1000)
  /// - overlapRatio: Overlap between chunks 0.0-1.0 (default: 0.0)
  /// - batchSize: Batch size for embedding generation (default: 32)
  ///
  /// Throws:
  /// - FileNotFoundError: Directory does not exist
  /// - FileReadError: Permission error accessing directory
  Stream<ChunkEmbedding> embedDirectory(
    String directoryPath, {
    List<String>? extensions,
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  });
}

/// Result of embedding a text chunk from a file
///
/// Contains the embedding vector, the original text chunk,
/// and metadata about the source (file path, page, chunk index).
class ChunkEmbedding {
  /// The embedding vector
  final EmbeddingResult embedding;

  /// The text content of this chunk (optional - may be null)
  final String? text;

  /// Metadata dictionary with file path, chunk index, page number, etc.
  final Map<String, String>? metadata;

  ChunkEmbedding({
    required this.embedding,
    this.text,
    this.metadata,
  });

  /// Convenience getter for file path from metadata
  String? get filePath => metadata?['file_path'];

  /// Convenience getter for page number from metadata (PDFs)
  int? get page {
    final pageStr = metadata?['page_number'];
    return pageStr != null ? int.tryParse(pageStr) : null;
  }

  /// Convenience getter for chunk index from metadata
  int? get chunkIndex {
    final idxStr = metadata?['chunk_index'];
    return idxStr != null ? int.tryParse(idxStr) : null;
  }

  /// Compute cosine similarity with another chunk's embedding
  double cosineSimilarity(ChunkEmbedding other) {
    return embedding.cosineSimilarity(other.embedding);
  }
}
```

#### New Error Classes (lib/src/errors.dart)
```dart
/// File or directory not found
class FileNotFoundError extends EmbedAnythingError {
  final String path;
  FileNotFoundError(this.path);

  @override
  String get message => 'File or directory not found: $path';
}

/// Unsupported file format
class UnsupportedFileFormatError extends EmbedAnythingError {
  final String path;
  final String extension;
  UnsupportedFileFormatError({required this.path, required this.extension});

  @override
  String get message => 'Unsupported file format: $extension (file: $path)';
}

/// File I/O error (permissions, read errors, etc.)
class FileReadError extends EmbedAnythingError {
  final String path;
  final String reason;
  FileReadError({required this.path, required this.reason});

  @override
  String get message => 'Failed to read file $path: $reason';
}
```

### FFI Layer Design

#### Rust FFI Types (rust/src/lib.rs)
```rust
/// C-compatible configuration for text embedding
#[repr(C)]
pub struct CTextEmbedConfig {
    pub chunk_size: usize,
    pub overlap_ratio: f32,
    pub batch_size: usize,
    pub buffer_size: usize,
    // Advanced options (Phase 3.1 - defer to roadmap)
    // pub use_ocr: bool,
    // pub late_chunking: bool,
    // pub splitting_strategy: u8,  // 0=Sentence, 1=Semantic
}

/// C-compatible representation of EmbedData
#[repr(C)]
pub struct CEmbedData {
    pub embedding_values: *mut f32,
    pub embedding_len: usize,
    pub text: *mut c_char,           // NULL if no text
    pub metadata_json: *mut c_char,  // JSON string or NULL
}

/// Batch of CEmbedData
#[repr(C)]
pub struct CEmbedDataBatch {
    pub items: *mut CEmbedData,
    pub count: usize,
}

/// Type alias for streaming callback
/// Called from Rust with batches of embeddings
type StreamCallback = extern "C" fn(*mut CEmbedDataBatch, *mut c_void);
```

#### Rust FFI Functions (rust/src/lib.rs)
```rust
/// Embed a single file
///
/// Returns a batch of CEmbedData, one per chunk.
///
/// Parameters:
/// - embedder: Embedder handle
/// - file_path: Path to file (C string)
/// - config: Pointer to CTextEmbedConfig
///
/// Returns:
/// - Pointer to CEmbedDataBatch on success
/// - NULL on failure (check get_last_error)
#[no_mangle]
pub extern "C" fn embed_file(
    embedder: *const CEmbedder,
    file_path: *const c_char,
    config: *const CTextEmbedConfig,
) -> *mut CEmbedDataBatch;

/// Embed directory with streaming callback
///
/// Calls callback multiple times with batches of embeddings.
/// Returns 0 on success, -1 on failure.
///
/// Parameters:
/// - embedder: Embedder handle
/// - directory_path: Path to directory (C string)
/// - extensions: NULL-terminated array of extension strings, or NULL for all files
/// - extensions_count: Number of extensions (0 if extensions is NULL)
/// - config: Pointer to CTextEmbedConfig
/// - callback: Function to call with each batch
/// - callback_context: User data passed to callback
///
/// Returns:
/// - 0 on success
/// - -1 on failure (check get_last_error)
#[no_mangle]
pub extern "C" fn embed_directory_stream(
    embedder: *const CEmbedder,
    directory_path: *const c_char,
    extensions: *const *const c_char,
    extensions_count: usize,
    config: *const CTextEmbedConfig,
    callback: StreamCallback,
    callback_context: *mut c_void,
) -> i32;

/// Free a CEmbedData instance
#[no_mangle]
pub extern "C" fn free_embed_data(data: *mut CEmbedData);

/// Free a CEmbedDataBatch instance
#[no_mangle]
pub extern "C" fn free_embed_data_batch(batch: *mut CEmbedDataBatch);
```

#### Dart FFI Bindings (lib/src/ffi/native_types.dart)
```dart
/// C representation of text embedding configuration
final class CTextEmbedConfig extends Struct {
  @Size()
  external int chunkSize;

  external Float overlapRatio;

  @Size()
  external int batchSize;

  @Size()
  external int bufferSize;
}

/// C representation of embedded chunk data
final class CEmbedData extends Struct {
  external Pointer<Float> embeddingValues;

  @Size()
  external int embeddingLen;

  external Pointer<Utf8> text;

  external Pointer<Utf8> metadataJson;
}

/// C representation of a batch of embedded data
final class CEmbedDataBatch extends Struct {
  external Pointer<CEmbedData> items;

  @Size()
  external int count;
}
```

#### Dart FFI Function Declarations (lib/src/ffi/bindings.dart)
```dart
@Native<Pointer<CEmbedDataBatch> Function(
  Pointer<CEmbedder>,
  Pointer<Utf8>,
  Pointer<CTextEmbedConfig>,
)>(assetId: 'package:embedanythingindart/embedanything_dart', symbol: 'embed_file')
external Pointer<CEmbedDataBatch> embedFile(
  Pointer<CEmbedder> embedder,
  Pointer<Utf8> filePath,
  Pointer<CTextEmbedConfig> config,
);

@Native<Int32 Function(
  Pointer<CEmbedder>,
  Pointer<Utf8>,
  Pointer<Pointer<Utf8>>,
  Size,
  Pointer<CTextEmbedConfig>,
  Pointer<NativeFunction<StreamCallbackType>>,
  Pointer<Void>,
)>(assetId: 'package:embedanythingindart/embedanything_dart', symbol: 'embed_directory_stream')
external int embedDirectoryStream(
  Pointer<CEmbedder> embedder,
  Pointer<Utf8> directoryPath,
  Pointer<Pointer<Utf8>> extensions,
  int extensionsCount,
  Pointer<CTextEmbedConfig> config,
  Pointer<NativeFunction<StreamCallbackType>> callback,
  Pointer<Void> callbackContext,
);

@Native<Void Function(Pointer<CEmbedData>)>(
  assetId: 'package:embedanythingindart/embedanything_dart',
  symbol: 'free_embed_data',
)
external void freeEmbedData(Pointer<CEmbedData> data);

@Native<Void Function(Pointer<CEmbedDataBatch>)>(
  assetId: 'package:embedanythingindart/embedanything_dart',
  symbol: 'free_embed_data_batch',
)
external void freeEmbedDataBatch(Pointer<CEmbedDataBatch> batch);

// Callback typedef for directory streaming
typedef StreamCallbackType = Void Function(Pointer<CEmbedDataBatch>, Pointer<Void>);
```

### Implementation Approach

#### Phase 1: Rust FFI Implementation
1. Add CTextEmbedConfig, CEmbedData, CEmbedDataBatch structs
2. Implement conversion from Rust EmbedData to CEmbedData:
   - Extract Vec<f32> from EmbeddingResult::DenseVector
   - Convert Option<String> text to *mut c_char
   - Serialize HashMap<String, String> metadata to JSON string
3. Implement embed_file_ffi():
   - Convert C strings to Rust types
   - Build TextEmbedConfig from CTextEmbedConfig
   - Call Arc<Embedder>::embed_file() with await
   - Convert Vec<EmbedData> to CEmbedDataBatch
   - Use std::mem::forget() for ownership transfer
4. Implement embed_directory_stream_ffi():
   - Convert C strings and extension array to Rust types
   - Create adapter closure that calls the callback function
   - Pass adapter to Arc<Embedder>::embed_directory_stream()
   - Handle async execution with RUNTIME.block_on()
5. Implement free_embed_data() and free_embed_data_batch()
6. Update error handling to include new error prefixes:
   - "FILE_NOT_FOUND:", "UNSUPPORTED_FORMAT:", "FILE_READ_ERROR:"

#### Phase 2: Dart FFI Bindings
1. Add native types to native_types.dart
2. Add @Native declarations to bindings.dart
3. Add NativeFinalizer registrations to finalizers.dart
4. Update ffi_utils.dart with new error parsing for file errors
5. Create helper functions for:
   - Building CTextEmbedConfig from Dart parameters
   - Converting CEmbedData to ChunkEmbedding
   - Parsing JSON metadata strings
   - Setting up NativeCallable for stream callback

#### Phase 3: High-Level Dart API
1. Add ChunkEmbedding class to lib/src/chunk_embedding.dart
2. Add error classes to lib/src/errors.dart
3. Implement embedFile() in EmbedAnything class:
   - Allocate CTextEmbedConfig struct
   - Call ffi.embedFile()
   - Convert CEmbedDataBatch to List<ChunkEmbedding>
   - Free native memory in finally block
4. Implement embedDirectory() in EmbedAnything class:
   - Create StreamController<ChunkEmbedding>
   - Create NativeCallable for callback that adds to stream
   - Allocate extension array if provided
   - Call ffi.embedDirectoryStream()
   - Clean up resources when stream closes
5. Add comprehensive dartdoc comments
6. Export new classes from lib/embedanythingindart.dart

#### Phase 4: Testing
1. Create test files: sample.txt, sample.pdf, sample.md
2. Unit tests for ChunkEmbedding class
3. Integration test: embedFile() with txt file
4. Integration test: embedFile() with pdf file
5. Integration test: embedDirectory() with test directory
6. Integration test: embedDirectory() with extension filtering
7. Error handling tests:
   - File not found
   - Unsupported file format
   - Invalid directory path
8. Memory leak test: Verify finalizers clean up resources
9. Performance test: Measure streaming vs loading all into memory

#### Phase 5: Documentation
1. Update README.md with Phase 3 examples
2. Add example to example/ folder: file_embedding_example.dart
3. Update CLAUDE.md with Phase 3 architecture details
4. Add dartdoc comments to all new public APIs
5. Document supported file formats and limitations

### Error Handling Strategy

#### Rust Side
- Use existing thread-local error storage pattern
- Add new error prefixes:
  - "FILE_NOT_FOUND:" when file/directory doesn't exist
  - "UNSUPPORTED_FORMAT:" when file extension not supported
  - "FILE_READ_ERROR:" for I/O and permission errors
- Wrap all FFI functions in panic::catch_unwind()
- For directory streaming: Log individual file errors but continue processing

#### Dart Side
- Extend _parseError() in ffi_utils.dart to handle new prefixes
- Add FileNotFoundError, UnsupportedFileFormatError, FileReadError to errors.dart
- For embedFile(): Throw errors immediately on failure
- For embedDirectory(): Add errors to stream using StreamController.addError()
- Document all exceptions in dartdoc comments

#### Error Recovery
- File not found: Not recoverable - user must provide valid path
- Unsupported format: Not recoverable - file format not supported
- File read error: Potentially recoverable with retry if transient I/O issue
- Embedding failed: Potentially recoverable by skipping problematic chunks

## Testing Requirements

### Unit Tests
- ChunkEmbedding class: Constructor, getters, cosineSimilarity()
- Error class constructors and messages
- CTextEmbedConfig struct allocation and field access
- CEmbedData to ChunkEmbedding conversion
- Metadata JSON parsing

### Integration Tests
- embedFile() with .txt file: Verify chunks, metadata, embeddings
- embedFile() with .pdf file: Verify page numbers in metadata
- embedFile() with .md file: Verify text extraction
- embedDirectory() with 3 test files: Verify streaming, correct count
- embedDirectory() with extension filter: Verify only matching files processed
- embedFile() with non-existent file: Verify FileNotFoundError thrown
- embedFile() with unsupported format: Verify UnsupportedFileFormatError thrown
- embedDirectory() with read-protected directory: Verify FileReadError in stream

### Performance Tests
- embedFile() with large PDF (100+ pages): Measure time and memory
- embedDirectory() with 100 files: Compare streaming vs batch memory usage
- Verify streaming yields first results quickly (< 1 second for first batch)

### Memory Leak Tests
- Run embedFile() 1000 times: Monitor memory growth
- Run embedDirectory() stream without consuming: Verify no leak
- Manually dispose embedder during directory streaming: Verify cleanup

### Coverage Requirements
- Target: >90% code coverage on new Dart code
- All error paths must have tests
- All FFI functions must have integration tests

## Documentation Requirements

### Code Documentation
- Dartdoc comments on all public APIs (classes, methods, parameters)
- Document all thrown exceptions with `/// Throws [ExceptionType] when...`
- Include code examples in dartdoc for main methods
- Document supported file formats in embedFile() dartdoc
- Document streaming behavior and error handling in embedDirectory() dartdoc

### README Updates
- Add "File Embedding" section after existing text embedding examples
- Show embedFile() example with PDF
- Show embedDirectory() example with Stream usage
- List supported file formats
- Document configuration parameters
- Show error handling example

### Example Code
- Create example/file_embedding_example.dart
- Demonstrate embedFile() with sample files
- Demonstrate embedDirectory() with stream consumption
- Show error handling patterns
- Show similarity search across chunks

### Architecture Documentation
- Update CLAUDE.md with Phase 3 section
- Document new FFI structs and functions
- Document streaming callback mechanism
- Document metadata format (JSON schema)
- Document memory management for new types

## Success Criteria
1. Users can embed PDF, TXT, MD, DOCX, HTML files with embedFile() and receive List<ChunkEmbedding>
2. Users can embed directories with embedDirectory() and receive Stream<ChunkEmbedding> that yields results incrementally
3. ChunkEmbedding includes working embedding vector, text content, and metadata with file path
4. Directory streaming processes large directories without loading all results into memory
5. Extension filtering correctly limits which files are processed
6. All file operations are async (Future/Stream) and don't block the event loop
7. Error handling provides specific exceptions (FileNotFoundError, etc.) with helpful messages
8. Memory management uses NativeFinalizer for automatic cleanup with no leaks
9. Tests achieve >90% coverage on new code with all major scenarios covered
10. Documentation is complete with README examples, dartdoc comments, and example app
11. Integration with existing EmbedAnything API is seamless (unified class, consistent patterns)

## Out of Scope
The following items are explicitly deferred to future work:

### Advanced Chunking Options (Roadmap)
- `late_chunking`: Considers larger context during chunking
- `use_ocr`: OCR support for scanned PDFs
- `splitting_strategy`: Sentence vs Semantic chunking strategies
- `pdf_backend`: Choice of PDF parsing backend (LoPdf vs Poppler)
- These require additional FFI complexity and testing

### Adapter/Vector Database Integration (Future Phase)
- Direct streaming to vector databases (Qdrant, Milvus, Pinecone)
- Adapter pattern for custom processing pipelines
- Requires separate design for database-specific adapters

### Image/Audio Embedding (Separate Feature)
- Image embedding (CLIP, ColPali models)
- Audio embedding (Whisper models)
- Requires different model types and processing pipelines

### Cloud Embedding Providers (Separate Feature)
- OpenAI embeddings
- Cohere embeddings
- Google Gemini embeddings
- Requires different API integration patterns

### Mobile Platform Support (Future Work)
- iOS and Android builds
- Requires platform-specific native toolchain setup
- May need ARM-specific optimizations

### Concurrent Directory Processing (Optimization)
- Parallel processing of multiple directories
- Requires complex isolate management
- Current single-threaded streaming is sufficient for MVP
