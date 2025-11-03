# Spec Requirements: Phase 1: Core Text Embedding Foundation

## Initial Description

This phase establishes the production-ready foundation for text embedding functionality. It includes 5 critical items:

1. **Fix Rust FFI Return Type Compatibility** - Update `embed_query()` and `embed()` to properly extract vectors from EmbedData/EmbeddingResult enum returned by EmbedAnything (Size: S)

2. **Comprehensive Test Coverage** - Expand test suite to cover edge cases, error conditions, and memory leak detection with realistic workloads (Size: S)

3. **API Documentation** - Generate dartdoc with comprehensive API documentation, usage examples, and troubleshooting guides for all public APIs (Size: S)

4. **Performance Benchmarking** - Establish baseline performance metrics for single/batch embedding operations across different model sizes and text lengths (Size: M)

5. **Model Configuration API** - Add support for custom HuggingFace models with configurable parameters (dtype, revision, normalization options) (Size: M)

This is the foundational phase that must be completed before moving to production readiness (Phase 2) and multi-modal expansion (Phase 3).

## Requirements Discussion

### First Round Questions

**Q1: Priority and Sequencing** - I assume we need to fix the FFI bug (Item 1) before proceeding with other items, since the tests, benchmarks, and documentation would be testing/documenting broken code. Should we sequence this as: (1) Fix FFI bug first, then (2-5) can proceed in any order?

**Answer:** Confirmed - Item 1 (FFI bug fix) first, then Items 2-5 can proceed in any order.

**Q2: FFI Bug Fix Scope** - The current implementation needs to handle the EmbeddingResult enum (DenseVector vs MultiVector). I'm assuming for Phase 1 we only need DenseVector support and can return an error or unsupported message for MultiVector results. Is that correct, or should we fully implement MultiVector handling now?

**Answer:** MultiVector support can be added later - focus on dense embeddings only for Phase 1.

**Q3: Test Coverage Targets** - For comprehensive test coverage, I'm thinking we should add:
- Edge cases: empty strings, very long texts (>512 tokens), special characters, Unicode
- Error conditions: invalid model names, network failures, out-of-memory scenarios
- Memory leak detection: repeated embed/dispose cycles
- Platform-specific tests (if behavior differs across macOS/Linux/Windows)

Does this align with your vision, or are there specific test scenarios you want prioritized?

**Answer:** All proposed test categories sound great (edge cases, error conditions, memory leaks, platform-specific). Target 90% code coverage.

**Q4: Documentation Standards** - For API documentation, I assume we should:
- Add comprehensive dartdoc comments to all public classes/methods
- Include code examples in doc comments
- Create a detailed README with quick start, installation, usage patterns
- Add a TROUBLESHOOTING.md with common issues
- Document memory management best practices

Should we follow any specific documentation template or style guide?

**Answer:** Yes to all proposed documentation. Replace the current README with a real comprehensive one. Include basic performance benchmarks in the documentation.

**Q5: Performance Benchmarking Metrics** - I'm thinking we should measure:
- Latency: Time per embedding (single and batch)
- Throughput: Embeddings per second
- Memory usage: Peak RAM during operations
- Model loading time
- Comparison across model sizes (MiniLM vs Jina-base)
- Text length impact (short vs long texts)

Should we create a separate benchmark suite that can be run independently?

**Answer:** All proposed metrics sound fabulous - create separate benchmark suite with markdown table output for tracking over time.

**Q6: Model Configuration API Design** - For custom HuggingFace models, should we:
- Option A: Add parameters to the existing factory method (gets messy with many params)
- Option B: Create a ModelConfig class with builder pattern for better extensibility
- Option C: Use named optional parameters with sensible defaults

Which approach would you prefer for API ergonomics?

**Answer:** Use a ModelConfig class (better for extensibility given the complexity).

**Q7: Acceptance Criteria for "Production Ready"** - What does production ready mean for this phase? Does it require:
- A. All 5 items code complete and passing local tests
- B. Above + peer code review completed
- C. Above + documentation reviewed by someone unfamiliar with the code
- D. Above + performance benchmarks meeting specific thresholds
- E. All of the above

**Answer:** Production ready means E.) all of the above (code complete + tests passing + code review + documentation updated + benchmarks established). May not reach this in one run, but try to get there if possible.

**Q8: Error Handling Strategy** - For the FFI layer and Dart API, should we use:
- Option A: Simple String error messages (current implementation)
- Option B: Typed exception classes (e.g., ModelNotFoundException, EmbeddingException)
- Option C: Result/Either types with sealed error classes

What's your preference for error handling consistency?

**Answer:** Use sealed class error types (e.g., `sealed class EmbedAnythingError` with subtypes like `ModelNotFoundError`, `InvalidConfigError`, etc.).

**Q9: Exclusions and Future Considerations** - Are there any features explicitly OUT OF SCOPE for Phase 1? For example:
- Custom tokenizer configuration
- GPU acceleration setup
- Model quantization options
- Streaming/chunked embedding APIs

**Answer:** None of the listed items (custom tokenizer, GPU acceleration, model quantization, streaming) are needed now. But might be worth adding to the roadmap as wishlist items for future phases.

### Existing Code to Reference

No similar existing features identified for reference. This is a library/FFI project without existing code patterns to reference from other parts of the codebase.

### Follow-up Questions

No follow-up questions needed. The answers provided comprehensive clarity on all requirements.

## Visual Assets

### Files Provided:
No visual assets provided (not applicable for FFI library project).

### Visual Insights:
N/A - No visual assets required for this type of technical infrastructure project.

## Requirements Summary

### Functional Requirements

**Item 1: Fix Rust FFI Return Type Compatibility**
- Update `embed_query()` in `rust/src/lib.rs` to properly handle the return type (currently returns `Vec<f32>` directly, not `EmbedData`)
- Update `embed()` in `rust/src/lib.rs` to extract the `.embedding` field from `Vec<EmbedData>`
- Handle `EmbeddingResult` enum by extracting `DenseVector(Vec<f32>)`
- Return an error for `MultiVector` results (not supported in Phase 1)
- Verify actual EmbedAnything API signatures in `.cargo/git/checkouts/embedanything-*/rust/src/embeddings/embed.rs`
- Determine if functions are async (require `.await`) or synchronous
- Ensure all changes maintain FFI safety with proper error handling

**Item 2: Comprehensive Test Coverage**
- Target: 90% code coverage
- Edge cases:
  - Empty strings
  - Very long texts (>512 tokens that require truncation)
  - Special characters and punctuation
  - Unicode and multilingual text
  - Null/invalid inputs
- Error conditions:
  - Invalid model names
  - Network failures during model download
  - Out-of-memory scenarios
  - Malformed configurations
- Memory leak detection:
  - Repeated embed/dispose cycles
  - Large batch operations
  - Finalizer behavior verification
- Platform-specific tests:
  - Validate behavior consistency across macOS/Linux/Windows
  - Test asset loading on each platform

**Item 3: API Documentation**
- Add comprehensive dartdoc comments to all public classes and methods
- Include code examples in doc comments showing common usage patterns
- Replace current README with comprehensive documentation including:
  - Quick start guide
  - Installation instructions
  - Detailed usage examples
  - Memory management best practices
  - Basic performance benchmarks
- Create TROUBLESHOOTING.md with common issues and solutions
- Document all public API methods with:
  - Purpose and behavior
  - Parameter descriptions
  - Return value details
  - Example usage
  - Error conditions

**Item 4: Performance Benchmarking**
- Create separate benchmark suite (independent from tests)
- Measure and track metrics:
  - Latency: Time per embedding (single and batch operations)
  - Throughput: Embeddings per second
  - Memory usage: Peak RAM during operations
  - Model loading time (first load vs cached)
  - Comparison across model sizes:
    - MiniLM models (384-dim)
    - Jina models (512-dim, 768-dim)
  - Text length impact:
    - Short texts (10-50 words)
    - Medium texts (100-200 words)
    - Long texts (500+ words)
- Output results as markdown tables for tracking over time
- Include baseline metrics in documentation

**Item 5: Model Configuration API**
- Design and implement `ModelConfig` class with:
  - Model identifier (HuggingFace model ID)
  - Model revision (branch/tag/commit hash)
  - Data type (dtype) options
  - Normalization options (enable/disable)
  - Sensible defaults for all parameters
- Update `EmbedAnything` factory method to accept `ModelConfig`
- Maintain backward compatibility with existing enum-based model selection
- Validate configuration parameters before passing to Rust FFI
- Support custom HuggingFace models beyond the predefined enum values

**Error Handling Implementation**
- Create sealed class hierarchy for typed errors:
  - `sealed class EmbedAnythingError`
  - Subtypes: `ModelNotFoundError`, `InvalidConfigError`, `EmbeddingFailedError`, `FFIError`, etc.
- Replace string-based error messages with typed errors throughout
- Ensure FFI layer properly maps Rust errors to Dart error types
- Maintain thread-local error storage pattern in Rust
- Provide helpful error messages with context for debugging

### Reusability Opportunities

No components identified for reuse from existing codebase. This is foundational FFI library infrastructure.

### Scope Boundaries

**In Scope:**
- Fixing FFI return type handling for dense vector embeddings
- Comprehensive test suite covering edge cases, errors, memory, and platforms
- Full API documentation with examples and troubleshooting guide
- Performance benchmarking suite with baseline metrics
- ModelConfig API for custom HuggingFace models
- Typed error handling with sealed classes
- Dense vector embedding support only (DenseVector variant)

**Out of Scope:**
- MultiVector/late-interaction embedding support (future phase)
- Custom tokenizer configuration
- GPU acceleration setup
- Model quantization options
- Streaming/chunked embedding APIs
- File embedding (PDF, DOCX, Markdown)
- Image embedding (CLIP, ColPali)
- Audio embedding (Whisper)
- ONNX backend support
- Cloud embeddings (OpenAI, Cohere)
- Mobile platform support (iOS, Android)
- Vector database adapter patterns

**Roadmap Wishlist (Future Phases):**
- Custom tokenizer configuration
- GPU acceleration support
- Model quantization options
- Streaming/chunked embedding APIs

### Technical Considerations

**FFI Layer:**
- Must maintain C ABI compatibility with `#[no_mangle]` and `extern "C"`
- All operations wrapped in `panic::catch_unwind()` to prevent undefined behavior
- Thread-local error storage for FFI-safe error handling
- Proper memory ownership transfer between Rust and Dart
- NativeFinalizer for automatic cleanup
- Input validation before unsafe operations

**EmbedAnything API Integration:**
- Verify actual function signatures in upstream source code
- Handle `EmbedData` struct with `.embedding` field
- Extract vectors from `EmbeddingResult::DenseVector(Vec<f32>)`
- Check if functions are async (require Tokio runtime and `.await`)
- Use `Arc<Embedder>` for thread-safe sharing

**Asset Name Consistency:**
- Must maintain consistency across:
  - `rust/Cargo.toml`: `name = "embedanything_dart"`
  - `hook/build.dart`: `assetName: 'embedanything_dart'`
  - `lib/src/ffi/bindings.dart`: `assetId: 'package:embedanythingindart/embedanything_dart'`

**Platform Support:**
- Target platforms: macOS, Linux, Windows (desktop only for Phase 1)
- Cross-platform native asset compilation via Native Assets
- Platform-specific testing required

**Performance Considerations:**
- First model load is slow (100-500MB download from HuggingFace Hub)
- Subsequent loads are fast (cached in `~/.cache/huggingface/hub`)
- Batch operations should be more efficient than sequential single embeds
- Memory management critical for large batch operations

**Testing Strategy:**
- Unit tests for all public APIs
- Integration tests for FFI layer
- Memory leak detection tests
- Platform-specific validation
- Separate benchmark suite (not part of regular test runs)
- Target: 90% code coverage

**Documentation Strategy:**
- Dartdoc for API reference
- README for quick start and usage guide
- TROUBLESHOOTING.md for common issues
- Inline code examples in doc comments
- Performance benchmarks included in docs
- Memory management best practices documented

**Acceptance Criteria for Production Ready:**
1. All 5 items code complete
2. All tests passing (90% coverage target)
3. Peer code review completed
4. Documentation reviewed by unfamiliar reviewer
5. Performance benchmarks established and meeting reasonable thresholds
6. No known critical bugs or memory leaks

**Sequencing Requirements:**
- Item 1 (FFI bug fix) MUST be completed first
- Items 2-5 can proceed in any order after Item 1
- Final acceptance requires all items complete
