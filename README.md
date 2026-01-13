# EmbedAnythingInDart

A high-performance Dart wrapper for the Rust-based [EmbedAnything](https://github.com/StarlightSearch/EmbedAnything) library, providing fast and efficient vector embeddings for text using state-of-the-art models from HuggingFace Hub.

## Overview

EmbedAnythingInDart brings the power of Rust's performance to Dart applications, enabling you to generate high-quality embeddings for semantic search, similarity matching, and other NLP tasks. The library leverages Dart's Native Assets system for seamless cross-platform compilation and provides an idiomatic Dart API with automatic memory management.

**Key Benefits:**
- Fast Rust-powered embedding generation
- Automatic memory management via NativeFinalizer
- Support for popular BERT and Jina models from HuggingFace
- Batch processing for optimal throughput
- Cross-platform support (macOS, Linux, Windows)
- Zero-copy FFI for maximum performance

## Features

- **Text Embedding**: Generate dense vector representations of text using BERT and Jina models
- **Batch Processing**: Efficiently process multiple texts with 5-10x speedup over sequential processing
- **Automatic Memory Management**: NativeFinalizer ensures native resources are cleaned up automatically
- **Flexible Configuration**: Customize model loading with precision (F32/F16), normalization, and batch size options
- **Semantic Similarity**: Built-in cosine similarity computation for comparing embeddings
- **Cross-Platform**: Native compilation for macOS, Linux, and Windows via Dart Native Assets
- **Type-Safe Errors**: Comprehensive sealed error hierarchy for robust error handling

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  embedanythingindart:
    git:
      url: https://github.com/yourusername/embedanythingindart.git
      ref: main
```

Then run:

```bash
dart pub get
```

**Prerequisites:**
- Dart SDK >=3.11.0
- Rust toolchain 1.90.0 or later
- Platform-specific build tools:
  - **macOS**: Xcode Command Line Tools
  - **Linux**: build-essential, pkg-config
  - **Windows**: MSVC Build Tools

## Quick Start

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void main() {
  // Load a model (first load downloads from HuggingFace, ~100-500MB)
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  // Generate a single embedding
  final result = embedder.embedText('Hello, world!');
  print('Embedding dimension: ${result.dimension}'); // 384

  // Batch processing (much faster for multiple texts)
  final texts = [
    'Machine learning is fascinating',
    'I love programming in Dart',
    'The weather is nice today',
  ];
  final embeddings = embedder.embedTextsBatch(texts);

  // Compute semantic similarity
  final similarity = embeddings[0].cosineSimilarity(embeddings[1]);
  print('Similarity: ${similarity.toStringAsFixed(4)}'); // 0.3245

  // Cleanup (automatic via finalizer, but manual is recommended)
  embedder.dispose();
}
```

## Documentation

Comprehensive documentation is available to help you get the most out of EmbedAnythingInDart. We recommend reading the guides in the following order:

1. **[Getting Started](doc/getting-started.md)** - Installation, prerequisites, and your first embedding
2. **[Core Concepts](doc/core-concepts.md)** - Architecture, key classes, and fundamental concepts
3. **[Usage Guide](doc/usage-guide.md)** - Common patterns, real-world examples, and best practices
4. **[API Reference](doc/api-reference.md)** - Complete API documentation with all classes and methods
5. **[Models and Configuration](doc/models-and-configuration.md)** - Choosing models, performance comparison, and configuration options
6. **[Error Handling](doc/error-handling.md)** - Error types, handling strategies, and troubleshooting
7. **[Advanced Topics](doc/advanced-topics.md)** - File embedding, streaming, optimization, and advanced patterns

Each guide includes working code examples extracted from the test suite and example application.

## Supported Models

| Model ID | Type | Dimensions | Speed | Quality | Best For |
|----------|------|------------|-------|---------|----------|
| `sentence-transformers/all-MiniLM-L6-v2` | BERT | 384 | Fast | Good | General purpose |
| `sentence-transformers/all-MiniLM-L12-v2` | BERT | 384 | Medium | Better | Quality-focused tasks |
| `jinaai/jina-embeddings-v2-small-en` | Jina | 512 | Fast | Good | English semantic search |
| `jinaai/jina-embeddings-v2-base-en` | Jina | 768 | Medium | Excellent | High-quality retrieval |

**Model Download:**
- Models are downloaded from HuggingFace Hub on first use
- Cached locally in `~/.cache/huggingface/hub`
- First load: 2-5 seconds (plus download time)
- Subsequent loads: <100ms (from cache)

## Usage

### Loading a Model

#### Using Predefined Configurations

```dart
// BERT all-MiniLM-L6-v2 (recommended for most use cases)
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

// Jina v2-base-en (best quality)
final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());
```

#### Using Custom Configuration

```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  revision: 'main',        // Git branch/tag/commit
  dtype: ModelDtype.f16,   // F16 for faster inference
  normalize: true,         // Normalize to unit length
  defaultBatchSize: 64,    // Batch size for processing
);

final embedder = EmbedAnything.fromConfig(config);
```

#### Legacy API (Backward Compatible)

```dart
final embedder = EmbedAnything.fromPretrainedHf(
  model: EmbeddingModel.bert,
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  revision: 'main',
);
```

### Generating Embeddings

#### Single Text

```dart
final result = embedder.embedText('The quick brown fox');
print('Dimension: ${result.dimension}');
print('First 5 values: ${result.values.take(5)}');
```

**Performance:**
- Short text (10 words): ~7-8ms
- Medium text (100 words): ~8-15ms (varies by model)
- Long text (500 words): ~15-30ms (varies by model)
- Very long text (>512 tokens): truncated automatically

See [benchmark/results.md](benchmark/results.md) for detailed performance data.

#### Batch Processing

```dart
final texts = List.generate(100, (i) => 'Text $i');
final results = embedder.embedTextsBatch(texts);

// Process results
for (var i = 0; i < results.length; i++) {
  print('Text $i: dimension ${results[i].dimension}');
}
```

**Performance:**
- Batch processing is **3-4x faster** than sequential (measured)
- Recommended batch size: 32-128 items
- BERT L6: ~775 items/sec for batch of 100
- Memory usage scales with batch size

For comprehensive benchmarks, see [benchmark/results.md](benchmark/results.md).

#### Async Batch Processing with Progress Tracking

For large batches (100+ texts), use the async API with progress tracking:

```dart
final results = await embedder.embedTextsBatchAsync(
  largeTextList,
  chunkSize: 50,  // Optional: override default (32)
  onProgress: (completed, total) {
    print('Progress: $completed / $total');
  },
);
```

**Migration Note (v0.2.0+):** `embedTextsBatchAsync()` now automatically chunks
large batches to prevent memory issues and system overload. This is a behavior
change - previous versions sent all texts to Rust at once. The chunking uses
`ModelConfig.defaultBatchSize` (default: 32). To process a specific chunk size,
pass the `chunkSize` parameter.

### Computing Similarity

```dart
final emb1 = embedder.embedText('I love machine learning');
final emb2 = embedder.embedText('Machine learning is great');
final emb3 = embedder.embedText('I enjoy cooking');

final sim12 = emb1.cosineSimilarity(emb2);
final sim13 = emb1.cosineSimilarity(emb3);

print('Related texts: ${sim12.toStringAsFixed(4)}');    // ~0.87
print('Unrelated texts: ${sim13.toStringAsFixed(4)}');  // ~0.21
```

**Interpreting Similarity Scores:**
- **0.9-1.0**: Nearly identical meaning
- **0.7-0.9**: Highly related
- **0.5-0.7**: Moderately related
- **0.3-0.5**: Somewhat related
- **0.0-0.3**: Weakly related or unrelated

### Error Handling

```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'invalid/model',
  );
} on EmbedAnythingError catch (e) {
  switch (e) {
    case ModelNotFoundError():
      print('Model not found: ${e.modelId}');
      print('Check https://huggingface.co/ for valid models');
    case InvalidConfigError():
      print('Invalid configuration: ${e.field} - ${e.reason}');
    case EmbeddingFailedError():
      print('Embedding failed: ${e.reason}');
    case MultiVectorNotSupportedError():
      print('Multi-vector embeddings not yet supported');
    case FFIError():
      print('FFI error: ${e.operation}');
  }
}
```

## Performance Characteristics

**Note:** Benchmarks below are representative values from Phase 1 testing. Actual performance depends on hardware, model, and text characteristics.

### Model Loading

| Model | Cold Start (first time) | Warm Start (cached) | Memory |
|-------|------------------------|---------------------|---------|
| BERT all-MiniLM-L6-v2 | 2-5 seconds + download | ~100ms | ~90MB |
| Jina v2-base-en | 3-6 seconds + download | ~150ms | ~280MB |

**Note:** Cold start includes model download (100-500MB depending on model).

### Single Embedding Latency

| Text Length | BERT MiniLM-L6 | Jina v2-base |
|-------------|----------------|--------------|
| Short (10 words) | ~5-10ms | ~10-15ms |
| Medium (100 words) | ~8-15ms | ~12-20ms |
| Long (500 words) | ~15-30ms | ~20-40ms |

**Platform note:** Performance varies by CPU. M1/M2 Macs show ~1.5x speedup over Intel equivalents.

### Batch Throughput

| Batch Size | Processing Time | Speedup vs Sequential |
|------------|----------------|----------------------|
| 10 items | ~20-30ms | ~3x faster |
| 100 items | ~170-250ms | ~5x faster |
| 1000 items | ~1.5-2.5s | ~8x faster |

**Recommendation:** Use batch processing for 10+ items for best performance.

### Memory Usage

- Base library overhead: ~10MB
- Per-model memory: 45-280MB (depends on model and dtype)
- Per-embedding overhead: Negligible (<1KB per embedding)
- Batch processing: Temporary memory scales linearly with batch size

## Memory Management

### Automatic Cleanup (Recommended for Most Cases)

```dart
void processTexts() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final result = embedder.embedText('test');
  // No dispose() needed - finalizer cleans up when embedder is garbage collected
}
```

### Manual Cleanup (Recommended for Long-Running Applications)

```dart
void processTexts() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  try {
    final result = embedder.embedText('test');
    // Use result...
  } finally {
    embedder.dispose(); // Immediate cleanup
  }
}
```

### Best Practices

- **Manual `dispose()`** for long-running services or apps with many embedders
- **Automatic cleanup** for short-lived scripts or infrequent usage
- **Reuse embedders** instead of creating many instances
- **Use batch processing** to minimize overhead
- **Avoid creating embedders in loops** - create once, reuse many times

## Platform Support

### Supported Platforms

| Platform | Architecture | Status |
|----------|-------------|--------|
| macOS | x64 (Intel) | Supported |
| macOS | ARM64 (Apple Silicon) | Supported |
| Linux | x64 | Supported |
| Linux | ARM64 | Supported |
| Windows | x64 | Supported |

### Platform Requirements

**macOS:**
- macOS 11.0 or later
- Xcode Command Line Tools: `xcode-select --install`

**Linux:**
- Debian/Ubuntu: `apt install build-essential pkg-config`
- Fedora/RHEL: `dnf install gcc pkg-config`
- Arch: `pacman -S base-devel`

**Windows:**
- Visual Studio 2019 or later with C++ Build Tools
- Or Windows SDK + MSVC from VS Build Tools

### First Build

The first build compiles 488 Rust crates and will take **5-15 minutes** depending on your hardware. Subsequent builds are incremental and much faster (<30 seconds).

```bash
# First build - patience required!
dart run --enable-experiment=native-assets example/embedanythingindart_example.dart
```

## Troubleshooting

For detailed troubleshooting, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

**Common issues:**

| Issue | Quick Solution |
|-------|---------------|
| First build extremely slow | Expected - compiling 488 crates takes 5-15 minutes |
| Model download fails | Check internet connection, set HF_TOKEN for private models |
| Asset not found error | Verify asset name consistency in Cargo.toml, build.dart, bindings.dart |
| Out of memory | Reduce batch size or use F16 dtype |
| Tests fail | Ensure internet connection for model downloads |

## API Reference

### Comprehensive Documentation

For detailed guides with examples and best practices, see the [Documentation](#documentation) section above, particularly:
- **[API Reference](doc/api-reference.md)** - Complete API documentation with signatures, parameters, and examples
- **[Usage Guide](doc/usage-guide.md)** - Practical usage patterns
- **[Error Handling](doc/error-handling.md)** - Error types and handling strategies

### Generated API Docs

Auto-generated dartdoc API documentation is also available:

```bash
dart doc
dart pub global activate dhttpd
dhttpd --path doc/api
```

Then open http://localhost:8080 in your browser.

**Core Classes:**
- [`EmbedAnything`](lib/src/embedder.dart) - Main embedder interface
- [`EmbeddingResult`](lib/src/embedding_result.dart) - Embedding vector result
- [`ModelConfig`](lib/src/model_config.dart) - Model configuration
- [`EmbeddingModel`](lib/src/models.dart) - Model architecture enum
- [`ModelDtype`](lib/src/models.dart) - Model data type enum
- [`EmbedAnythingError`](lib/src/errors.dart) - Error hierarchy

## Contributing

Contributions are welcome! Please follow these guidelines:

### Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/embedanythingindart.git
cd embedanythingindart

# Install dependencies
dart pub get

# Install Rust targets
cd rust && rustup show

# Run tests
dart test --enable-experiment=native-assets

# Run analyzer
dart analyze

# Format code
dart format .
```

### Testing

```bash
# Run all tests
dart test --enable-experiment=native-assets

# Run specific test file
dart test --enable-experiment=native-assets test/model_config_test.dart

# Run with coverage
dart test --enable-experiment=native-assets --coverage=coverage

# Run Phase 3 file/directory embedding tests specifically
dart test --enable-experiment=native-assets test/phase3_integration_test.dart
```

**Phase 3 Test Requirements:**
- Test fixtures are located in `test/fixtures/`
- Integration tests require internet connection on first run to download BERT model (~90MB)
- Subsequent runs use cached model from `~/.cache/huggingface/hub`
- Tests verify:
  - File embedding (.txt, .md files)
  - Directory streaming with extension filtering
  - Error handling (FileNotFoundError, UnsupportedFileFormatError)
  - Metadata parsing and ChunkEmbedding utilities
  - Memory management (no leaks)

For detailed information about Phase 3 features, see test fixture documentation in `test/fixtures/README.md`.

### Code Standards

- Follow [Effective Dart](https://dart.dev/effective-dart) guidelines
- Add dartdoc comments to all public APIs
- Ensure `dart analyze` passes with zero issues
- Ensure `cargo clippy` passes with zero warnings
- Write tests for new features
- Update CHANGELOG.md with changes

### Build System

This project uses Dart's Native Assets system. Key files:
- `hook/build.dart` - Native asset build hook
- `rust/Cargo.toml` - Rust crate configuration
- `rust-toolchain.toml` - Rust version pinning

**Asset name consistency is critical:**
- `rust/Cargo.toml`: `name = "embedanything_dart"`
- `hook/build.dart`: `assetName: 'embedanything_dart'`
- `lib/src/ffi/bindings.dart`: `assetId: 'package:embedanythingindart/embedanything_dart'`

## License

This project is licensed under the MIT License - see the LICENSE file for details.

The underlying EmbedAnything Rust library is licensed under the Apache License 2.0.

## Acknowledgments

- [EmbedAnything](https://github.com/StarlightSearch/EmbedAnything) - The Rust library this wraps
- [HuggingFace](https://huggingface.co/) - For hosting the embedding models
- [sentence-transformers](https://www.sbert.net/) - For the BERT models
- [Jina AI](https://jina.ai/) - For the Jina embedding models

## Related Projects

- [surrealdartb](https://github.com/yourusername/surrealdartb) - SurrealDB client for Dart with vector support
- [EmbedAnything](https://github.com/StarlightSearch/EmbedAnything) - Upstream Rust library
- [Candle](https://github.com/huggingface/candle) - Rust ML framework powering EmbedAnything

## Roadmap

**Phase 2: Production Readiness**
- CI/CD pipeline with multi-platform testing
- Automated release process
- Performance optimizations
- Security audit

**Phase 3: Multi-Modal Expansion**
- PDF, DOCX, Markdown file embedding
- Image embedding (CLIP, ColPali)
- Audio embedding (Whisper)

**Phase 4: Advanced Features**
- Multi-vector embedding support (ColBERT)
- GPU acceleration (CUDA, Metal)
- Model quantization (INT8, INT4)
- Custom tokenizer configuration

**Phase 5: Ecosystem Integration**
- Vector database adapters (Pinecone, Weaviate, Qdrant)
- Cloud provider embeddings (OpenAI, Cohere)
- Mobile platform support (iOS, Android)

---

**Questions or Issues?**
- Open an issue on [GitHub](https://github.com/yourusername/embedanythingindart/issues)
- Read the [comprehensive documentation](doc/getting-started.md) for guides and examples
- Check [Error Handling](doc/error-handling.md) for troubleshooting common problems
- Review the [API Reference](doc/api-reference.md) for complete API documentation
