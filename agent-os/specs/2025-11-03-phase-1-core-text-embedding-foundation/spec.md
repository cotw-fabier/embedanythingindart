# Specification: Phase 1 - Core Text Embedding Foundation

## Goal

Establish a production-ready foundation for the EmbedAnythingInDart library by fixing critical FFI bugs, implementing comprehensive test coverage, creating complete API documentation, establishing performance benchmarks, and adding extensible model configuration support.

## User Stories

- As a developer integrating EmbedAnythingInDart, I want the library to work correctly with the upstream EmbedAnything API so that I can reliably generate text embeddings
- As a library user, I want comprehensive documentation and examples so that I can quickly understand how to use the API effectively
- As a developer maintaining production systems, I want extensive test coverage so that I can trust the library's stability and correctness
- As a performance-conscious developer, I want clear performance benchmarks so that I can make informed decisions about batch sizes and model selection
- As an advanced user, I want to configure custom HuggingFace models so that I can use domain-specific embedding models beyond the predefined options

## Core Requirements

### Functional Requirements

#### Item 1: Fix Rust FFI Return Type Compatibility (CRITICAL - Must Complete First)

**Current Issues:**
- Line ~237 in `rust/src/lib.rs`: `embed_text()` function assumes `embed_query()` returns `Vec<f32>` directly
- Line ~338 in `rust/src/lib.rs`: `embed_texts_batch()` correctly handles `Vec<EmbedData>` but needs verification
- Actual EmbedAnything API returns `EmbedData` struct with `.embedding` field of type `EmbeddingResult` enum

**Required Changes:**
- Verify actual function signatures by inspecting upstream source at `~/.cargo/git/checkouts/embedanything-*/rust/src/embeddings/embed.rs`
- Confirm whether `embed_query()` and `embed()` are async (require `.await`)
- Update `embed_text()` to:
  - Handle `EmbedData` return type from `embed_query()`
  - Extract `.embedding` field of type `EmbeddingResult`
  - Pattern match on `EmbeddingResult::DenseVector(vec)` to extract `Vec<f32>`
  - Return error via thread-local storage if `EmbeddingResult::MultiVector` is encountered
- Validate `embed_texts_batch()` implementation correctly handles the same pattern
- Ensure all error cases use `set_last_error()` with descriptive messages
- Maintain FFI safety with proper `panic::catch_unwind()` guards
- Add validation that extracted vectors are non-empty

**Success Criteria:**
- All existing tests pass without modification to test code
- FFI functions correctly extract dense vectors from EmbedAnything API responses
- Clear error message returned when MultiVector embeddings are encountered
- No memory leaks or undefined behavior from type mismatches

#### Item 2: Comprehensive Test Coverage

**Edge Case Coverage:**
- Empty strings (verify expected behavior: non-zero embedding or error)
- Unicode text: emoji, Chinese characters, Arabic script
- Special characters: newlines, tabs, quotes, HTML entities
- Very long texts exceeding tokenizer limits (>512 tokens for BERT models)
- Whitespace-only strings
- Extremely large batches (1000+ items) to test memory limits
- Mixed-length batches (empty + short + long texts together)

**Error Condition Coverage:**
- Invalid model identifiers that don't exist on HuggingFace Hub
- Network failures during model download (simulate offline mode)
- Corrupted model cache (delete/modify cached files)
- Out-of-memory scenarios (generate embeddings for extremely large batch)
- Concurrent access patterns (multiple embedders, parallel operations)
- Null pointer scenarios (though API shouldn't allow this)
- Malformed UTF-8 from native side (edge case testing)

**Memory Management Coverage:**
- Load/dispose cycles: create and dispose 100+ embedders sequentially
- Verify NativeFinalizer cleanup: create embedders without manual dispose, force GC
- Large batch stress test: embed 10,000 texts and verify memory is released
- Verify finalizer doesn't double-free after manual dispose
- Test dispose-after-use error handling
- Multiple dispose calls on same instance

**Platform-Specific Coverage:**
- Run test suite on macOS (Intel and Apple Silicon)
- Run test suite on Linux (x86_64 and ARM64 if available)
- Run test suite on Windows (x64)
- Verify asset loading works consistently across platforms
- Confirm model caching behavior is consistent

**Test Organization:**
- Separate test files by concern: `ffi_test.dart`, `memory_test.dart`, `edge_cases_test.dart`, `platform_test.dart`
- Use test groups for logical organization
- Add `@Tags()` for slow tests, platform-specific tests
- Target: 90% code coverage minimum across Dart codebase

#### Item 3: API Documentation

**dartdoc Comments Required:**
- All public classes: purpose, usage examples, lifecycle
- All public methods: parameters, return values, exceptions, examples
- All public properties: meaning, constraints, default values
- Code examples demonstrating:
  - Basic single text embedding
  - Batch embedding with performance comparison
  - Model loading and configuration
  - Memory management best practices
  - Error handling patterns
  - Semantic similarity computation

**README.md Structure:**
```markdown
# EmbedAnythingInDart

## Overview
[1-2 paragraph description]

## Features
- Text embedding with BERT and Jina models
- Batch processing for efficiency
- Automatic memory management
- Cross-platform support

## Installation
[pubspec.yaml snippet]

## Quick Start
[Complete working example]

## Supported Models
[Table of models with dimensions, use cases]

## Usage

### Loading a Model
[Example with explanation]

### Generating Embeddings
[Single and batch examples]

### Computing Similarity
[Semantic similarity example]

### Model Configuration
[Custom model example with ModelConfig]

## Performance Characteristics
[Table from benchmarks: load times, embedding latency, throughput]

## Memory Management
[Best practices: dispose vs finalizer]

## Platform Support
[Supported platforms and requirements]

## Troubleshooting
[Common issues and solutions]

## API Reference
[Link to generated dartdoc]

## Contributing
[Build instructions, testing, standards]

## License
[License information]
```

**TROUBLESHOOTING.md Required:**
- Model download failures (HF_TOKEN, network issues)
- First build extremely slow (expected - 488 crates)
- Asset not found errors (name consistency check)
- Symbol not found errors (Rust function signatures)
- Out of memory errors (batch size recommendations)
- Platform-specific build issues (toolchain requirements)

**Inline Documentation Standards:**
- Use triple-slash comments: `/// Description`
- Include `@param` style descriptions for parameters
- Document exceptions: `/// Throws [EmbedAnythingException] when...`
- Add `/// Example:` sections with runnable code
- Cross-reference related APIs: `/// See also [embedTextsBatch]`
- Document performance characteristics: `/// This operation takes 2-5 seconds on first call`

#### Item 4: Performance Benchmarking

**Benchmark Suite Structure:**
Create `benchmark/benchmark.dart` separate from tests:

**Metrics to Measure:**

Model Loading Performance:
- Cold start (no cache): time to load model first time
- Warm start (cached): time to load previously downloaded model
- Memory footprint of loaded model
- Test with both BERT (all-MiniLM-L6-v2) and Jina (jina-embeddings-v2-base-en)

Single Embedding Latency:
- Short text (10 words): latency in milliseconds
- Medium text (100 words): latency in milliseconds
- Long text (500 words): latency in milliseconds
- Very long text (2000 words, will be truncated): latency in milliseconds
- Run 100 iterations each, report mean/p50/p95/p99

Batch Embedding Throughput:
- Batch size 10: items/second, total time
- Batch size 100: items/second, total time
- Batch size 1000: items/second, total time
- Compare batch vs sequential single embedding efficiency
- Measure memory usage during batch processing

Model Comparison:
- BERT all-MiniLM-L6-v2 (384-dim) vs all-MiniLM-L12-v2 (384-dim)
- Jina jina-embeddings-v2-small-en (512-dim) vs jina-embeddings-v2-base-en (768-dim)
- Compare speed vs quality trade-offs

**Output Format:**
Generate markdown tables in `benchmark/results.md`:

```markdown
## Benchmark Results

**Platform:** macOS 14.0, M1 Pro, 16GB RAM
**Date:** 2025-11-03
**Library Version:** 0.1.0

### Model Loading Performance

| Model | Cold Start (s) | Warm Start (ms) | Memory (MB) |
|-------|----------------|-----------------|-------------|
| BERT MiniLM-L6-v2 | 4.2 | 85 | 90 |
| Jina v2-base-en | 6.8 | 120 | 280 |

### Single Embedding Latency (ms)

| Text Length | BERT MiniLM | Jina v2-base |
|-------------|-------------|--------------|
| 10 words (p50) | 3.2 | 4.8 |
| 100 words (p50) | 8.5 | 12.1 |
| 500 words (p50) | 15.3 | 22.7 |

### Batch Throughput

| Batch Size | BERT (items/sec) | Jina (items/sec) |
|------------|------------------|------------------|
| 10 | 312 | 208 |
| 100 | 588 | 412 |
| 1000 | 625 | 445 |

### Batch vs Sequential Efficiency

| Operation | Time (s) | Speedup |
|-----------|----------|---------|
| 100 sequential | 0.85 | 1x |
| 100 batch | 0.17 | 5x |
```

**Benchmark Execution:**
- Run with `dart run benchmark/benchmark.dart`
- Not part of regular test suite
- Update results in documentation after each major version

#### Item 5: Model Configuration API

**ModelConfig Class Design:**

```dart
/// Configuration for loading embedding models from HuggingFace Hub
class ModelConfig {
  /// HuggingFace model identifier (e.g., 'sentence-transformers/all-MiniLM-L6-v2')
  final String modelId;

  /// Model architecture type
  final EmbeddingModel modelType;

  /// Git revision (branch, tag, or commit hash). Defaults to 'main'
  final String revision;

  /// Data type for model weights (F32 or F16). Defaults to F32
  final ModelDtype dtype;

  /// Whether to normalize embeddings to unit length. Defaults to true
  final bool normalize;

  /// Default batch size for batch operations. Defaults to 32
  final int defaultBatchSize;

  const ModelConfig({
    required this.modelId,
    required this.modelType,
    this.revision = 'main',
    this.dtype = ModelDtype.f32,
    this.normalize = true,
    this.defaultBatchSize = 32,
  });

  /// Predefined configuration for BERT all-MiniLM-L6-v2
  factory ModelConfig.bertMiniLML6() => ModelConfig(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    modelType: EmbeddingModel.bert,
  );

  /// Predefined configuration for Jina v2-base-en
  factory ModelConfig.jinaV2Base() => ModelConfig(
    modelId: 'jinaai/jina-embeddings-v2-base-en',
    modelType: EmbeddingModel.jina,
  );

  /// Validate configuration parameters
  void validate() {
    if (modelId.isEmpty) {
      throw InvalidConfigError('modelId cannot be empty');
    }
    if (defaultBatchSize <= 0) {
      throw InvalidConfigError('defaultBatchSize must be positive');
    }
    // Additional validation rules
  }
}

/// Model data type options
enum ModelDtype {
  f32(0),
  f16(1);

  const ModelDtype(this.value);
  final int value;
}
```

**Updated EmbedAnything API:**

```dart
class EmbedAnything {
  // Existing factory - maintain backward compatibility
  factory EmbedAnything.fromPretrainedHf({
    required EmbeddingModel model,
    required String modelId,
    String revision = 'main',
  }) => EmbedAnything.fromConfig(ModelConfig(
    modelId: modelId,
    modelType: model,
    revision: revision,
  ));

  /// Create embedder from configuration object
  factory EmbedAnything.fromConfig(ModelConfig config) {
    config.validate();

    // Pass additional parameters to Rust FFI
    final handle = embedderFromPretrainedHfExtended(
      config.modelType.value,
      config.modelId,
      config.revision,
      config.dtype.value,
    );

    if (handle == nullptr) {
      throwLastError('Failed to load model: ${config.modelId}');
    }

    return EmbedAnything._(handle, config);
  }

  // Store config for reference
  final ModelConfig? _config;

  // Use config's defaultBatchSize in batch operations
}
```

**Rust FFI Extension:**

Update `embedder_from_pretrained_hf()` to accept `dtype` parameter (currently passes `None`):

```rust
#[no_mangle]
pub extern "C" fn embedder_from_pretrained_hf(
    model_type: u8,
    model_id: *const c_char,
    revision: *const c_char,
    dtype: i32, // 0=F32, 1=F16, -1=default
) -> *mut CEmbedder {
    // Map dtype to EmbedAnything's Dtype enum
    // Pass to Embedder::from_pretrained_hf()
}
```

### Non-Functional Requirements

**Error Handling:**
- Replace `EmbedAnythingException` with sealed class hierarchy
- Typed errors enable better error handling and documentation
- Preserve stack traces and error context

**Performance:**
- Single embedding latency <20ms for short texts (warm cache)
- Batch processing 5x faster than sequential for 100+ items
- Model loading <100ms for warm cache
- Memory usage proportional to model size, no leaks

**Compatibility:**
- Maintain backward compatibility with existing API
- New features additive only, no breaking changes
- Support Dart SDK >=3.11.0

**Code Quality:**
- All code passes `dart analyze` with zero issues
- Follows project coding standards from `agent-os/standards/`
- FFI layer adheres to safety best practices
- Clear separation of concerns: FFI layer, high-level API, utilities

## Visual Design

Not applicable - this is a library project without visual UI.

## Reusable Components

### Existing Code to Leverage

**FFI Infrastructure (lib/src/ffi/):**
- `native_types.dart`: Opaque pointer types and C struct definitions
- `bindings.dart`: @Native function declarations with assetId
- `ffi_utils.dart`: String conversion utilities, error retrieval
- `finalizers.dart`: NativeFinalizer for automatic cleanup
- These components work correctly and should not be modified

**High-Level API Structure:**
- `embedder.dart`: Main API class structure with factory pattern
- `embedding_result.dart`: Result type with similarity computation
- `models.dart`: Enum pattern for model types
- These provide good patterns to extend for new features

**Test Infrastructure:**
- Existing test setup with proper async handling
- Test group organization by feature area
- Use of `setUpAll/tearDownAll` for expensive model loading
- These patterns should be replicated in new test files

**Build System:**
- `hook/build.dart`: Native Assets integration working correctly
- `rust-toolchain.toml`: Proper Rust version pinning
- `Cargo.toml`: Correct crate-type configuration
- No changes needed to build infrastructure

### New Components Required

**Sealed Error Class Hierarchy:**
- Current `EmbedAnythingException` is too generic
- Need typed errors for: model not found, invalid config, FFI errors, embedding failures, multi-vector unsupported
- Enables better error handling and clearer documentation
- Required by error handling standards

**ModelConfig Class:**
- No existing configuration abstraction
- Current API uses direct parameters, not extensible
- Needed to support dtype, normalization, batch size tuning
- Enables future additions without breaking API

**Benchmark Suite:**
- No existing performance benchmarking infrastructure
- Tests verify correctness but not performance
- Need separate benchmark suite with timing and memory measurements
- Required for performance documentation

**Extended FFI Bindings:**
- Current `embedder_from_pretrained_hf()` passes `None` for dtype
- Need to expose dtype parameter through FFI
- Potentially need to expose normalization and batch size hints
- Required for ModelConfig feature

**Extended Test Coverage:**
- Current tests cover happy path well
- Missing edge cases, error conditions, memory stress tests
- Need platform-specific test configuration
- Required to reach 90% coverage target

## Technical Approach

### Architecture Overview

The library maintains a three-layer architecture:

**Layer 1: Rust FFI (rust/src/lib.rs)**
- Exposes C-compatible API using `#[no_mangle]` and `extern "C"`
- Manages thread-local error storage for FFI-safe error handling
- Wraps EmbedAnything library in opaque CEmbedder handles
- Provides memory management functions for Dart to call
- Uses Tokio runtime for async operations

**Layer 2: Dart FFI Bindings (lib/src/ffi/)**
- Low-level @Native function declarations mapped to Rust functions
- Utility functions for string conversion and error retrieval
- NativeFinalizer attachments for automatic cleanup
- No business logic, pure FFI interop

**Layer 3: High-Level Dart API (lib/src/)**
- User-facing classes: EmbedAnything, EmbeddingResult, ModelConfig
- Idiomatic Dart API with proper error handling
- Automatic resource management via finalizers and dispose()
- Business logic: batch processing, similarity computation

### Database

Not applicable - no database required for this library.

### API Design

**Core Classes:**

```dart
// Error hierarchy
sealed class EmbedAnythingError implements Exception {
  String get message;
  String toString() => 'EmbedAnythingError: $message';
}

class ModelNotFoundError extends EmbedAnythingError {
  final String modelId;
  String get message => 'Model not found: $modelId';
}

class InvalidConfigError extends EmbedAnythingError {
  final String field;
  final String reason;
  String get message => 'Invalid configuration for $field: $reason';
}

class EmbeddingFailedError extends EmbedAnythingError {
  final String reason;
  String get message => 'Embedding generation failed: $reason';
}

class MultiVectorNotSupportedError extends EmbedAnythingError {
  String get message => 'Multi-vector embeddings not supported in this version';
}

class FFIError extends EmbedAnythingError {
  final String operation;
  final String? nativeError;
  String get message => 'FFI operation failed: $operation${nativeError != null ? " - $nativeError" : ""}';
}
```

**FFI Layer Updates:**

```rust
// Add dtype parameter to model loading
#[no_mangle]
pub extern "C" fn embedder_from_pretrained_hf_extended(
    model_type: u8,
    model_id: *const c_char,
    revision: *const c_char,
    dtype: i32,
) -> *mut CEmbedder {
    // Implementation with dtype handling
}

// Update embed_text to handle EmbedData return type
#[no_mangle]
pub extern "C" fn embed_text(
    embedder: *const CEmbedder,
    text: *const c_char,
) -> *mut CTextEmbedding {
    // Updated implementation:
    // 1. Call embed_query() which returns EmbedData
    // 2. Extract .embedding field (EmbeddingResult enum)
    // 3. Pattern match on DenseVector variant
    // 4. Return error for MultiVector variant
}
```

### Frontend

Not applicable - this is a backend library without frontend components.

### Testing Strategy

**Unit Tests (test/):**
- Test each public method in isolation
- Mock/stub expensive operations where possible
- Fast execution (<5 seconds total)
- Run on every commit via CI

**Integration Tests (test/):**
- Test FFI boundary with real Rust code
- Test with real models (cached for speed)
- Verify end-to-end embedding generation
- Include in CI but may be slower

**Edge Case Tests (test/edge_cases_test.dart):**
- Unicode, special characters, extreme lengths
- Boundary conditions (empty, null-like inputs)
- Should run quickly, no external dependencies

**Error Condition Tests (test/error_test.dart):**
- Simulate failures: invalid models, network issues
- Verify error types and messages
- Test error recovery patterns

**Memory Tests (test/memory_test.dart):**
- Load/dispose cycles
- Large batch stress tests
- Finalizer behavior verification
- May require manual inspection of memory profiler

**Platform Tests (test/platform_test.dart):**
- Use conditional imports or @TestOn() annotations
- Verify platform-specific behavior
- Run in platform-specific CI jobs

**Benchmarks (benchmark/):**
- Not run automatically, manual execution
- Generate performance reports
- Track regression over time
- Document results in README

**Coverage Target:**
- 90% line coverage minimum
- 85% branch coverage
- Focus on happy path and error handling
- FFI layer covered by integration tests

### Implementation Phases

**Phase 1a: Fix FFI Bug (CRITICAL - Day 1)**
1. Inspect upstream EmbedAnything source to confirm API
2. Update `embed_text()` to handle EmbedData return type
3. Add pattern matching for DenseVector extraction
4. Add error path for MultiVector
5. Verify existing tests still pass
6. Manual testing with debug output

**Phase 1b: Error Handling (Day 1-2)**
1. Define sealed class hierarchy
2. Update FFI utils to throw typed errors
3. Update Rust error messages for clarity
4. Refactor existing tests to use typed errors
5. Add error-specific tests

**Phase 1c: Model Configuration (Day 2-3)**
1. Create ModelConfig class with validation
2. Add ModelDtype enum
3. Extend Rust FFI to accept dtype parameter
4. Update EmbedAnything to accept ModelConfig
5. Add tests for configuration validation
6. Add tests for custom models

**Phase 1d: Test Coverage Expansion (Day 3-5)**
1. Create edge_cases_test.dart
2. Create error_test.dart
3. Create memory_test.dart
4. Create platform_test.dart
5. Run coverage report, identify gaps
6. Add tests to reach 90% coverage

**Phase 1e: Documentation (Day 5-7)**
1. Add dartdoc comments to all public APIs
2. Include code examples in comments
3. Rewrite README.md with comprehensive guide
4. Create TROUBLESHOOTING.md
5. Generate dartdoc HTML
6. Review for clarity and completeness

**Phase 1f: Benchmarking (Day 7-9)**
1. Create benchmark suite structure
2. Implement model loading benchmarks
3. Implement latency benchmarks
4. Implement throughput benchmarks
5. Run on multiple platforms
6. Document results in markdown tables
7. Add performance section to README

**Phase 1g: Code Review & Polish (Day 9-10)**
1. Run dart analyze, fix all issues
2. Self-review all changes
3. Update CHANGELOG.md
4. Verify all acceptance criteria met
5. Tag for peer review

## Out of Scope

### Explicitly Excluded from Phase 1

**Multi-Vector Embeddings:**
- EmbeddingResult::MultiVector variant not supported
- Required for late-interaction models like ColBERT
- Will return clear error message if encountered
- Future phase: Add MultiVectorResult type and handling

**Custom Tokenizer Configuration:**
- Cannot override tokenizer settings
- Use model's default tokenizer configuration
- Future phase: Expose tokenizer config API

**GPU Acceleration:**
- CPU-only inference in Phase 1
- No CUDA or Metal backend configuration
- Future phase: Add GPU backend selection

**Model Quantization:**
- Full precision models only (F32/F16)
- No INT8 or INT4 quantization support
- Future phase: Add quantization options to ModelConfig

**Streaming/Chunked APIs:**
- All operations load full input before processing
- No streaming for large documents
- Future phase: Add stream-based embedding APIs

**Multi-Modal Features:**
- Text embedding only in Phase 1
- No image, audio, or file embedding
- Phase 2 and 3: Add multi-modal support

**Mobile Platforms:**
- Desktop platforms only (macOS, Linux, Windows)
- iOS and Android support requires additional work
- Future phase: Add mobile platform targets

**Vector Database Adapters:**
- No built-in integration with Pinecone, Weaviate, etc.
- Users must implement their own storage
- Future phase: Provide adapter packages

**Cloud Provider Embeddings:**
- No OpenAI, Cohere, or cloud provider integration
- Local models only
- Future phase: Add cloud provider adapters

### Future Roadmap

**Phase 2: Production Readiness**
- CI/CD setup with multi-platform testing
- Automated release process
- Example applications demonstrating real-world usage
- Performance optimization based on benchmarks
- Security audit of FFI layer

**Phase 3: Multi-Modal Expansion**
- PDF, DOCX, Markdown file embedding
- Image embedding with CLIP/ColPali
- Audio embedding with Whisper
- Video embedding support

**Phase 4: Advanced Features**
- Multi-vector embedding support
- Custom tokenizer configuration
- GPU acceleration (CUDA, Metal, ROCm)
- Model quantization options
- Streaming APIs for large documents

**Phase 5: Ecosystem Integration**
- Vector database adapters (Pinecone, Weaviate, Qdrant)
- Cloud provider embeddings (OpenAI, Cohere)
- Mobile platform support (iOS, Android)
- Web platform support (WASM)

## Success Criteria

### Completion Criteria

**Item 1: FFI Bug Fix**
- [ ] Rust code correctly handles EmbedData return type from embed_query()
- [ ] Rust code correctly extracts DenseVector from EmbeddingResult enum
- [ ] Clear error returned for MultiVector embeddings
- [ ] All existing tests pass without modification
- [ ] Manual verification with debug logging confirms correct vector extraction

**Item 2: Test Coverage**
- [ ] 90% code coverage or higher across Dart codebase
- [ ] Edge case tests cover: empty, unicode, special chars, long texts
- [ ] Error condition tests cover: invalid models, network failures, OOM
- [ ] Memory tests verify: load/dispose cycles, finalizer cleanup, no leaks
- [ ] Platform tests pass on macOS, Linux, Windows
- [ ] All tests pass consistently (no flaky tests)

**Item 3: Documentation**
- [ ] All public APIs have comprehensive dartdoc comments
- [ ] All dartdoc includes example code
- [ ] README.md rewritten with complete guide
- [ ] TROUBLESHOOTING.md created with common issues
- [ ] Generated dartdoc HTML reviewed for clarity
- [ ] Documentation reviewed by someone unfamiliar with codebase
- [ ] No broken links or missing references

**Item 4: Benchmarking**
- [ ] Benchmark suite runs independently from tests
- [ ] Metrics collected for: model loading, single latency, batch throughput
- [ ] Benchmarks run for both BERT and Jina models
- [ ] Results documented in markdown tables
- [ ] Performance characteristics added to README
- [ ] Baseline metrics established for tracking regression

**Item 5: Model Configuration**
- [ ] ModelConfig class implemented with validation
- [ ] EmbedAnything.fromConfig() factory method works
- [ ] Backward compatibility maintained with existing API
- [ ] Rust FFI extended to accept dtype parameter
- [ ] Tests verify custom model loading
- [ ] Tests verify configuration validation
- [ ] Documentation includes ModelConfig examples

**Error Handling:**
- [ ] Sealed class hierarchy implemented
- [ ] All error types properly categorized
- [ ] Error messages are clear and actionable
- [ ] Stack traces preserved in error context
- [ ] Tests verify correct error types thrown

**Code Quality:**
- [ ] Zero issues from `dart analyze`
- [ ] All standards from `agent-os/standards/` followed
- [ ] FFI safety best practices adhered to
- [ ] No compiler warnings in Rust code
- [ ] Code formatting consistent throughout

### Acceptance for Production Ready

All of the following must be completed:

1. **Code Complete:** All 5 items fully implemented and working
2. **Tests Passing:** All tests pass on all platforms (macOS, Linux, Windows)
3. **Coverage Target:** 90% code coverage achieved
4. **Code Review:** Peer review completed with all feedback addressed
5. **Documentation Review:** Documentation reviewed by unfamiliar developer, confirmed clear and accurate
6. **Benchmarks Established:** Performance baseline documented and reasonable
7. **No Critical Bugs:** No known memory leaks, crashes, or data corruption issues
8. **Standards Compliance:** All code follows project standards and conventions

### Performance Targets

**Model Loading (Warm Cache):**
- BERT models: <100ms
- Jina models: <150ms

**Single Embedding Latency (P50, Short Text):**
- BERT: <10ms
- Jina: <15ms

**Batch Throughput:**
- At least 5x faster than sequential for 100+ items
- BERT: >500 items/second
- Jina: >350 items/second

**Memory Usage:**
- No leaks detectable in load/dispose cycles
- Peak memory proportional to batch size
- Embedder instances independent (no shared state leaks)

### Quality Gates

**Before Peer Review:**
- All tests passing
- Coverage >90%
- Documentation complete
- Zero analyze issues

**Before Tagging Release:**
- Peer review approved
- Documentation review approved
- Benchmarks documented
- CHANGELOG updated
- No known critical bugs

**Long-term Maintenance:**
- Update benchmarks quarterly
- Monitor for upstream API changes
- Track performance regression
- Keep documentation current

---

## Implementation Notes

### Critical Dependencies

**Upstream API Stability:**
- EmbedAnything library may change APIs between versions
- Pin to specific git commit or tag in Cargo.toml
- Monitor upstream releases for breaking changes
- Test with new versions before updating

**Asset Name Consistency:**
Must maintain exact match across:
- `rust/Cargo.toml`: `name = "embedanything_dart"`
- `hook/build.dart`: `assetName: 'embedanything_dart'`
- `lib/src/ffi/bindings.dart`: `assetId: 'package:embedanythingindart/embedanything_dart'`

**FFI Safety Checklist:**
- All functions: `#[no_mangle]` and `extern "C"`
- All operations: wrapped in `panic::catch_unwind()`
- All errors: stored in thread-local, never thrown across boundary
- All pointers: validated non-null before dereferencing
- All memory: clear ownership transfer pattern
- All strings: proper CString/CStr conversion

### Development Workflow

**Local Testing:**
```bash
# Run tests with native assets
dart test --enable-experiment=native-assets

# Run specific test file
dart test --enable-experiment=native-assets test/edge_cases_test.dart

# Run with coverage
dart test --enable-experiment=native-assets --coverage=coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib

# Run benchmarks
dart run benchmark/benchmark.dart
```

**Build Commands:**
```bash
# Clean everything
dart clean && cargo clean

# Rebuild from scratch
dart run --enable-experiment=native-assets example/embedanythingindart_example.dart

# Check Rust code
cargo clippy -- -D warnings
cargo fmt --check
```

**Documentation:**
```bash
# Generate dartdoc
dart doc

# Serve locally
dart pub global activate dhttpd
dhttpd --path doc/api

# Open browser to http://localhost:8080
```

### Troubleshooting Development Issues

**Rust Compilation Errors:**
- Check actual EmbedAnything API in `~/.cargo/git/checkouts/embedanything-*/`
- Consult docs at https://docs.rs/embed_anything/latest/
- May need to update to newer/older commit of EmbedAnything

**Test Failures:**
- First build downloads models (100-500MB), expect delays
- Verify internet connectivity for model downloads
- Check HuggingFace Hub status if downloads fail
- Clear model cache: `rm -rf ~/.cache/huggingface/hub`

**Memory Issues:**
- Use Dart DevTools memory profiler for leak detection
- Verify finalizers registered correctly
- Check Rust memory safety with valgrind or miri
- Reduce batch sizes if OOM occurs

**Platform-Specific Issues:**
- Ensure correct Rust targets installed: `rustup show`
- Verify platform build tools installed (Xcode, MSVC, GCC)
- Check Native Assets documentation for platform requirements
- Test on actual hardware, not just emulators/VMs

### Migration Path for Users

**No Breaking Changes:**
Current users can upgrade without code changes:
- Existing `EmbedAnything.fromPretrainedHf()` continues to work
- Error messages improved but exception type compatible
- Behavior unchanged for existing use cases

**Opting Into New Features:**
Users can adopt new features incrementally:
- Use `EmbedAnything.fromConfig()` for advanced configuration
- Catch typed errors for better error handling
- Reference benchmarks for optimization opportunities

**Future Deprecations:**
Plan to deprecate in future major version:
- Generic `EmbedAnythingException` in favor of typed errors
- Direct parameter passing in favor of ModelConfig

