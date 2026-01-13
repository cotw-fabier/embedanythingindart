# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

EmbedAnythingInDart is a Dart wrapper for the Rust-based EmbedAnything library, which provides high-performance vector embeddings for multimedia content. This project uses `native_toolchain_rust` to create FFI bindings between Dart and Rust, leveraging the Native Assets system for automatic cross-platform compilation.

**Key Architecture:**
- **FFI Layer**: C-compatible functions in Rust (rust/src/lib.rs) expose EmbedAnything functionality
- **Dart Bindings**: Low-level @Native bindings (lib/src/ffi/) map to Rust functions
- **High-Level API**: Idiomatic Dart wrapper (lib/src/embedder.dart) with automatic memory management
- **Native Assets**: Automatic Rust compilation via hook/build.dart during dart/flutter run

## Current Implementation Status

**✅ Completed:**
- Rust workspace with proper crate configuration (staticlib + cdylib for iOS/other platforms)
- Native Assets build hook integration
- Complete Dart FFI bindings with NativeFinalizer for automatic cleanup
- High-level EmbedAnything Dart API with embedText() and embedTextsBatch()
- EmbeddingResult with cosineSimilarity() utility
- Comprehensive test suite (9 test groups)
- Working example demonstrating text embedding and similarity

**🔧 In Progress:**
- Rust FFI API compatibility with EmbedAnything's actual function signatures
- The embed() and embed_query() return types need adjustment to properly extract vectors from EmbedData

**Current Scope:**
- Text embedding only (BERT, Jina models from HuggingFace)
- Dense vector embeddings (not multi-vector/late-interaction)
- Desktop platforms (macOS, Linux, Windows)

## Development Commands

### Install Rust Targets
```bash
cd rust && rustup show
```
This reads rust-toolchain.toml and installs all required targets.

### Get Dependencies
```bash
dart pub get
```

### Build and Run (with Native Assets)
```bash
# Run example (first build will be SLOW - compiling Rust dependencies)
dart run --enable-experiment=native-assets example/embedanythingindart_example.dart

# Run tests
dart test --enable-experiment=native-assets
```

### Analyze Code
```bash
dart analyze
```

### Manual Rust Build (for debugging)
```bash
cargo build --release
cargo clippy  # Rust linter
```

### Clean Build
```bash
# Clean Dart artifacts
dart clean

# Clean Rust artifacts
cargo clean

# Rebuild from scratch
dart run --enable-experiment=native-assets
```

## Architecture Details

### FFI Layer Structure

**Rust Side (rust/src/lib.rs):**
```
Thread-local error storage → get_last_error(), free_error_string()
Tokio runtime (once_cell) → init_runtime()
Opaque handle CEmbedder → wraps Arc<Embedder>
C-compatible types → CTextEmbedding, CTextEmbeddingBatch
Model loading → embedder_from_pretrained_hf()
Embedding operations → embed_text(), embed_texts_batch()
Memory management → embedder_free(), free_embedding(), free_embedding_batch()
```

**Dart Side (lib/src/ffi/):**
```
native_types.dart → Opaque types (CEmbedder) and Structs (CTextEmbedding)
bindings.dart → @Native function declarations with assetId
ffi_utils.dart → String conversion, error retrieval utilities
finalizers.dart → NativeFinalizer for automatic cleanup
```

**High-Level Dart API (lib/src/):**
```
embedder.dart → EmbedAnything class (main user-facing API)
embedding_result.dart → EmbeddingResult with cosineSimilarity()
models.dart → EmbeddingModel enum (BERT, Jina)
```

### Memory Management Pattern

**Rust → Dart ownership transfer:**
1. Rust allocates Vec<f32> embedding on heap
2. Converts to Box<[f32]>, extracts raw pointer
3. Uses std::mem::forget() to prevent Rust from freeing
4. Returns pointer to Dart
5. Dart copies to List<double> in embedder.dart:_copyFloatArray()
6. Dart calls free_embedding() to reclaim Rust memory

**Automatic cleanup:**
- NativeFinalizer attached to Dart wrapper objects
- When Dart object is GC'd, finalizer calls Rust free function
- Manual dispose() available for eager cleanup

### Asset Name Consistency

These three MUST match exactly:

1. **rust/Cargo.toml**: `name = "embedanything_dart"`
2. **hook/build.dart**: `assetName: 'embedanything_dart'`
3. **lib/src/ffi/bindings.dart**: `assetId: 'package:embedanythingindart/embedanything_dart'`
   (Format: package:<pubspec_name>/<cargo_name>)

### Critical Implementation Notes

**Rust FFI Best Practices:**
- ALL FFI functions use `#[no_mangle]` and `extern "C"`
- ALL operations wrapped in `panic::catch_unwind()` to prevent UB
- Errors stored in thread-local storage, never throw across FFI boundary
- Input validation before unsafe operations
- Tokio runtime initialized once via Lazy static
- Async operations use `RUNTIME.spawn()` (Tokio tasks) NOT `thread::spawn` (OS threads)

**Thread Pool Configuration:**
- Rayon is used by Candle (ML framework) for parallel matrix operations
- By default, Rayon creates num_cpus threads which can be excessive
- Call `configure_thread_pool(n)` BEFORE any embedding to limit threads
- Once the pool is initialized, it cannot be reconfigured

**EmbedAnything API Specifics:**
- `Embedder::from_pretrained_hf()` is **synchronous** (not async)
- Takes 4 args: model, model_id, revision, dtype
- `embed_query()` requires `Arc<Embedder>` (hence CEmbedder wraps Arc)
- `embed()` takes `&[&str]`, batch_size: Option<usize>, normalize: Option<bool>
- Returns `Vec<EmbedData>` where each has `.embedding: EmbeddingResult`
- `EmbeddingResult` is enum: DenseVector(Vec<f32>) | MultiVector(Vec<Vec<f32>>)

**Current Bug to Fix:**
In `rust/src/lib.rs`:
- Line ~237: `embed_query()` returns `Vec<f32>` directly, not EmbedData
- Line ~338: `embed()` returns `Vec<EmbedData>`, need to access `.embedding` field

**How to Debug:**
1. Check actual return types in EmbedAnything source:
   `/Users/fabier/.cargo/git/checkouts/embedanything-*/rust/src/embeddings/embed.rs`
2. Look for `pub async fn embed_query` and `pub async fn embed` signatures
3. Adjust Rust FFI code to match actual return types
4. May need to call `.await` if functions are actually async

## Upstream EmbedAnything Reference

**Location:** https://github.com/StarlightSearch/EmbedAnything

**Key Documentation:**
- docs/index.md - Main docs with supported models
- docs/guides/adapters.md - Vector database integration
- Python bindings at python/src/lib.rs - Reference for FFI patterns

**Supported Models (current integration):**
- BERT: sentence-transformers/all-MiniLM-L6-v2 (384-dim)
- BERT: sentence-transformers/all-MiniLM-L12-v2 (384-dim)
- Jina: jinaai/jina-embeddings-v2-small-en (512-dim)
- Jina: jinaai/jina-embeddings-v2-base-en (768-dim)

**Model Loading:**
- Downloads from HuggingFace Hub on first use
- Cached locally in ~/.cache/huggingface/hub
- First model load is slow (100-500MB download)
- Subsequent loads are fast

## Future Expansion

**Planned Features (not yet implemented):**
- File embedding (PDF, DOCX, Markdown)
- Image embedding (CLIP, ColPali)
- Audio embedding (Whisper)
- ONNX backend support
- Cloud embeddings (OpenAI, Cohere)
- Mobile platform support (iOS, Android)
- Streaming/adapter patterns for vector databases

**To Add New Model Type:**
1. Add enum value to lib/src/models.dart
2. Add case to Rust match in embedder_from_pretrained_hf()
3. Update Dart factory to accept new model type
4. Add tests for new model

**To Add New Platform:**
1. Add target to rust/rust-toolchain.toml
2. Run `rustup show` to install
3. Test with `dart run --enable-experiment=native-assets`
4. May need platform-specific feature flags in Cargo.toml

## Performance & Memory Management

**Large Batch Processing:**
- `embedTextsBatchAsync()` auto-chunks large batches (default: 32 items per chunk)
- Use `chunkSize` parameter to override chunk size
- Use `onProgress` callback for progress tracking
- Memory stays bounded during processing (~300MB for 3000 embeddings)

**Thread Pool Best Practices:**
```dart
// MUST be called BEFORE loading any models
EmbedAnything.configureThreadPool(4);  // Limit to 4 threads

// Then load model and embed
final embedder = await EmbedAnything.fromPretrainedHfAsync(...);
final results = await embedder.embedTextsBatchAsync(
  texts,
  chunkSize: 32,
  onProgress: (done, total) => print('$done/$total'),
);
```

**Memory Benchmarks (3000 embeddings, 4 threads):**
- Model load: ~240 MB
- Peak during embedding: ~320 MB
- After dispose: ~240 MB
- Throughput: ~156 items/sec

**Memory Stress Test:**
```bash
dart test --enable-experiment=native-assets test/memory_stress_test.dart -r expanded
dart run --enable-experiment=native-assets example/memory_stress_example.dart
```

## Troubleshooting

**"Asset not found" error:**
- Verify asset name consistency (see Asset Name Consistency above)
- Run `dart clean` and rebuild

**"Symbol not found" error:**
- Check `#[no_mangle]` on Rust function
- Verify function name matches Dart @Native symbol

**Rust compilation errors:**
- Check actual EmbedAnything API in .cargo/git/checkouts/
- EmbedAnything API may have changed since implementation
- Consult docs at https://docs.rs/embed_anything/latest/embed_anything/

**First build extremely slow:**
- Expected - compiling 488 Rust crates including Candle ML framework
- Subsequent builds are incremental (much faster)
- Use `cargo clean` only when necessary

**Model download issues:**
- Ensure internet connectivity
- Check HuggingFace Hub status
- Models cached in ~/.cache/huggingface/hub
- Can set HF_TOKEN environment variable for private models

**High memory usage or too many threads:**
- Call `EmbedAnything.configureThreadPool(4)` BEFORE loading models
- Use async API (`embedTextsBatchAsync`) with chunking for large batches
- Default Rayon thread pool uses num_cpus threads (can be 16+ on modern machines)
- Run `test/memory_stress_test.dart` to verify memory behavior

## Testing Strategy

**Unit Tests (test/embedanythingindart_test.dart):**
- Model loading and error handling
- Single text embedding
- Batch embedding
- EmbeddingResult utilities (cosineSimilarity)
- Memory management (dispose, finalizers)
- Semantic similarity validation

**Memory Stress Test (test/memory_stress_test.dart):**
- Embeds 3000 items with memory tracking
- Verifies thread pool configuration works
- Checks memory stays bounded during large batches
- Validates proper cleanup after dispose

**Run specific test:**
```bash
dart test --enable-experiment=native-assets -n "test name pattern"
```

**Run memory stress test:**
```bash
dart test --enable-experiment=native-assets test/memory_stress_test.dart -r expanded
```

**Run with verbose output:**
```bash
dart test --enable-experiment=native-assets -r expanded
```

## Dependencies

**Dart:**
- ffi: ^2.1.0 - FFI interop
- hooks: ^1.0.0 - Native Assets hooks
- native_toolchain_rust: ^1.0.0 - Rust build automation

**Rust:**
- embed_anything: Git from StarlightSearch/EmbedAnything
- tokio: Async runtime
- once_cell: Lazy static initialization
- anyhow: Error handling
- rayon: Thread pool for parallel computation (configurable)
- num_cpus: CPU count detection for thread pool defaults

**System Requirements:**
- Rust toolchain 1.90.0 (pinned via rust-toolchain.toml)
- Dart SDK ^3.9.0
- Platform-specific build tools (Xcode on macOS, MSVC on Windows, build-essential on Linux)
