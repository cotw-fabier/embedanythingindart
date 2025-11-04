# Requirements - Phase 3 Dart API: File and Directory Embedding

## Overview
Create a Dart API for Phase 3 (Indexing) functionality in EmbedAnythingInDart to support file and directory embedding with chunking and metadata.

## User Responses to Clarifying Questions

### 1. API Design
- **Decision**: Keep API unified with existing `EmbedAnything` class
- **Methods**: Add `embedFile()` and `embedDirectory()` to the existing class
- **Pattern**: Mirror existing `embedText()` and `embedTextsBatch()` structure

### 2. Chunk Data Structure
- **Class Name**: `ChunkEmbedding`
- **Properties**:
  - `embedding`: `List<double>` - The embedding vector
  - `text`: `String?` - The text chunk content
  - `metadata`: `Map<String, String>?` - Metadata (file_path, chunk_index, page_number, etc.)
- **Methods**: Include `cosineSimilarity()` convenience method (mirror `EmbeddingResult`)

### 3. Configuration
- **Decision**: Use named parameters directly on methods (simpler than config object)
- **Parameters to expose**:
  - `chunkSize` (default: 1000)
  - `overlapRatio` (default: 0.0)
  - `batchSize` (default: 32)
- **Advanced options**: Deferred to roadmap (see #7)

### 4. File Format Support
- **Decision**: Handle all formats that EmbedAnything supports
- **Formats**: PDF, TXT, MD, DOCX, HTML
- **Detection**: Let EmbedAnything handle file type detection automatically
- **Dart-side validation**: Minimal or none - rely on Rust library's error responses

### 5. Directory Filtering
- **Decision**: Support filtering by file extensions
- **API**: `embedDirectory(path, extensions: ['.pdf', '.txt'])`
- **Implementation**: Pass through to Rust `embed_directory_stream()` extensions parameter

### 6. Streaming Support
- **Decision**: Implement streaming with Dart `Stream<ChunkEmbedding>`
- **Rationale**: Better for large directories, prevents memory issues
- **Complexity**: Acceptable tradeoff for better UX

### 7. Advanced Chunking Options
- **Decision**: Skip for initial implementation, add to roadmap
- **Deferred features**:
  - `late_chunking` - considers larger context during chunking
  - `use_ocr` - OCR support for scanned PDFs
  - `splitting_strategy` - Sentence vs Semantic chunking strategies
- **Action**: Add these to `@agent-os/roadmap.md`

### 8. Error Handling
- **Decision**: Add specific exceptions for file operations
- **New exceptions**:
  - `FileNotFoundError` - File/directory doesn't exist
  - `UnsupportedFileFormatError` - File format not supported
  - `FileReadError` - Permission or I/O errors
- **Existing pattern**: Continue using existing `FFIError` base pattern where appropriate

### 9. Async API
- **Decision**: All methods should be async (`Future<>` or `Stream<>`)
- **Rationale**: File I/O and processing are slow operations
- **Convention**: Consistent with "Async by Default" for Dart best practices

## Core API Signature (Draft)

```dart
class EmbedAnything {
  // Existing methods...
  EmbeddingResult embedText(String text);
  List<EmbeddingResult> embedTextsBatch(List<String> texts);

  // New Phase 3 methods
  Future<List<ChunkEmbedding>> embedFile(
    String filePath, {
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  });

  Stream<ChunkEmbedding> embedDirectory(
    String directoryPath, {
    List<String>? extensions,
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  });
}

class ChunkEmbedding {
  final EmbeddingResult embedding;
  final String? text;
  final Map<String, String>? metadata;

  // Convenience getters
  String? get filePath;
  int? get page;
  int? get chunkIndex;

  // Similarity method
  double cosineSimilarity(ChunkEmbedding other);
}
```

## Technical Requirements

### FFI Layer
1. **Rust structs**:
   - `CEmbedData` - C-compatible struct for EmbedData
   - `CEmbedDataBatch` - Array of CEmbedData
   - Add metadata string handling (JSON or key-value pairs)

2. **Rust functions**:
   - `embed_file_ffi()` - Wraps `embed_anything::embed_file()`
   - `embed_directory_stream_ffi()` - Wraps `embed_anything::embed_directory_stream()`
   - Memory management functions for new types

3. **Dart bindings**:
   - Add native types to `lib/src/ffi/native_types.dart`
   - Add @Native declarations to `lib/src/ffi/bindings.dart`
   - Update finalizers for cleanup

### Error Handling
- Add exception classes to `lib/src/errors.dart`
- Map Rust error types to appropriate Dart exceptions
- Provide helpful error messages with file paths

### Testing
- Unit tests for `ChunkEmbedding` class
- Integration tests for `embedFile()` with sample files
- Integration tests for `embedDirectory()` with test directory
- Error handling tests (missing files, unsupported formats)
- Memory leak tests (ensure cleanup works)

### Documentation
- Update README with Phase 3 examples
- Add dartdoc comments to all new public APIs
- Create example in `example/` folder showing file/directory embedding
- Update CLAUDE.md with Phase 3 architecture details

## Out of Scope (Future Work)
- Adapter/vector database streaming (deferred to later phase)
- Advanced chunking options (late_chunking, OCR, splitting strategies)
- Image/audio file embedding (separate feature)
- Cloud embedding models (separate feature)

## Success Criteria
1. Users can embed PDF, TXT, MD, DOCX, HTML files and get back chunks with metadata
2. Users can embed entire directories with optional extension filtering
3. Directory embedding returns a Stream that can be consumed incrementally
4. All file operations are async and don't block the UI
5. Proper error handling with specific exceptions for common failure modes
6. Memory is properly managed (no leaks)
7. Tests achieve >90% coverage on new code
8. Documentation is complete and examples are runnable
