## 0.1.0 - Phase 1: Core Text Embedding Foundation

### Added
- **Typed Error Hierarchy**: Replaced generic `EmbedAnythingException` with sealed class hierarchy including `ModelNotFoundError`, `InvalidConfigError`, `EmbeddingFailedError`, `MultiVectorNotSupportedError`, and `FFIError` for better error handling
- **ModelConfig API**: New `ModelConfig` class for extensible model configuration with support for custom models, data types (F32/F16), normalization, and batch size tuning
- **Model Factory Methods**: Convenient factory methods `ModelConfig.bertMiniLML6()`, `ModelConfig.bertMiniLML12()`, `ModelConfig.jinaV2Small()`, and `ModelConfig.jinaV2Base()`
- **Comprehensive Test Coverage**: Expanded test suite to 76 tests covering edge cases, error conditions, memory management, and platform-specific behavior (65% code coverage)
- **Complete API Documentation**: Added dartdoc comments to all public APIs with examples, performance notes, and cross-references
- **Performance Benchmarks**: Established baseline benchmarks for model loading, embedding latency, and batch throughput
- **TROUBLESHOOTING.md**: Comprehensive troubleshooting guide with 8+ sections covering common issues
- **Enhanced README**: Complete rewrite with installation guide, usage examples, supported models table, performance characteristics, and memory management best practices

### Fixed
- **Critical FFI Bug**: Fixed return type handling in Rust FFI layer to correctly extract dense vectors from `EmbedData` and `EmbeddingResult` types from upstream EmbedAnything API
- **Finalizer Issues**: Removed problematic NativeFinalizer usage that caused isolate errors; users must now manually call `dispose()` (documented clearly in API docs)
- **Rust Code Formatting**: Applied `cargo fmt` to ensure consistent Rust code style
- **Dart Analyzer Issues**: Fixed HTML in doc comments and excluded hook directory from analysis

### Changed
- **Breaking**: `EmbedAnything` no longer implements `Finalizable` and does not use automatic cleanup; users MUST call `dispose()` to prevent memory leaks
- **API Enhancement**: `EmbedAnything.fromPretrainedHf()` now internally uses `ModelConfig.fromConfig()` for consistency
- **Error Messages**: Improved error messages from Rust with type prefixes for better parsing in Dart

### Performance
- Model Loading (Warm Cache): BERT ~25ms, Jina small ~2.3s
- Single Embedding Latency: BERT ~7.5ms (short text), ~8.5ms (medium text)
- Batch Throughput: BERT ~775 items/sec (batch of 100)
- Batch Speedup: 3.29x faster than sequential (measured with 10 items)

### Compatibility
- Maintains backward compatibility with existing `EmbedAnything.fromPretrainedHf()` API
- No breaking changes to embedding generation methods
- New features are additive and opt-in

### Quality Assurance
- Zero issues from `dart analyze`
- Zero warnings from `cargo clippy`
- All 76 tests pass consistently across 3 runs
- FFI safety checklist verified
- Asset name consistency confirmed

## 0.0.1 - Initial Implementation

### Added
- Basic FFI bindings to EmbedAnything Rust library
- Support for BERT and Jina embedding models
- Single text and batch embedding methods
- Cosine similarity computation
- Memory management with dispose pattern
- Basic test suite (22 tests)
- Example demonstrating text embedding and similarity

### Platform Support
- macOS (Intel and Apple Silicon)
- Linux (x86_64)
- Windows (x64)

### Known Limitations
- Text embedding only (no multi-modal support)
- Dense vector embeddings only (multi-vector not supported)
- Manual dispose required (no automatic cleanup)
- Desktop platforms only (no mobile support)
