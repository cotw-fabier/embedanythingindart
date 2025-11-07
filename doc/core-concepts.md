# Core Concepts

This guide explains the fundamental concepts and architecture of EmbedAnythingInDart, helping you understand how the library works and how to use it effectively.

---

## Architecture Overview

EmbedAnythingInDart is built on a multi-layer architecture that bridges Dart and Rust through FFI (Foreign Function Interface), providing high-performance vector embeddings with an idiomatic Dart API.

### The Four Layers

```
┌─────────────────────────────────────────┐
│  High-Level Dart API                    │  <- You work here
│  (EmbedAnything, EmbeddingResult, etc)  │
├─────────────────────────────────────────┤
│  FFI Utilities & Type Conversions       │
│  (String conversion, error handling)    │
├─────────────────────────────────────────┤
│  Low-Level FFI Bindings                 │
│  (@Native declarations, C types)        │
├─────────────────────────────────────────┤
│  Rust Core (EmbedAnything Library)     │
│  (ML models, embedding generation)      │
└─────────────────────────────────────────┘
```

**1. Rust Core**

The bottom layer is the EmbedAnything Rust library, which handles:
- Loading machine learning models from HuggingFace Hub
- Running transformer models (BERT, Jina) on CPU
- Generating dense vector embeddings
- Processing text and files with chunking support

This layer provides the computational power and performance.

**2. Low-Level FFI Bindings**

The FFI layer uses Dart's `@Native` annotations to declare C-compatible functions that can call into Rust. This includes:
- Function declarations matching Rust's `extern "C"` exports
- C struct definitions (opaque handles, data structures)
- Native asset integration for automatic Rust compilation

**3. FFI Utilities**

Helper functions that bridge Dart and Rust types:
- String conversion (Dart `String` ↔ C `char*`)
- Float array copying (Rust `Vec<f32>` → Dart `List<double>`)
- Error retrieval from thread-local storage

**4. High-Level Dart API**

The user-facing API provides idiomatic Dart classes:
- `EmbedAnything` - Main embedder class with factory methods
- `EmbeddingResult` - Immutable vector representation
- `ChunkEmbedding` - File embedding results with metadata
- `ModelConfig` - Type-safe configuration

### Native Assets Build System

EmbedAnythingInDart uses Dart's Native Assets feature to automatically compile the Rust code:

```
dart run/build
    ↓
hook/build.dart executes
    ↓
native_toolchain_rs invokes cargo
    ↓
Rust compiles to native library (.dylib/.so/.dll)
    ↓
Library linked into Dart application
```

This means **no manual build steps** - just run your Dart code and the Rust layer compiles automatically. The first build takes several minutes (compiling 488+ crates), but subsequent builds are incremental and fast.

**Platform Support:**
- ✅ macOS (Apple Silicon and Intel)
- ✅ Linux (x86_64)
- ✅ Windows (x86_64)
- ❌ Web (not supported - requires native binaries)
- 🚧 iOS/Android (planned for future releases)

---

## Key Classes

### EmbedAnything

The `EmbedAnything` class is your main entry point for generating embeddings. It manages the lifecycle of a machine learning model loaded in memory.

**Creating an Embedder:**

```dart
// Method 1: Using predefined configurations (recommended)
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

// Method 2: Custom configuration
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,
  normalize: true,
  defaultBatchSize: 64,
);
final embedder = EmbedAnything.fromConfig(config);

// Method 3: Direct model loading (simpler, less control)
final embedder = EmbedAnything.fromPretrainedHf(
  model: EmbeddingModel.bert,
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
);
```

**Lifecycle Pattern:**

```dart
// 1. Create - Load model into memory
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

// 2. Use - Generate embeddings
final result = embedder.embedText('Hello, world!');
final batch = embedder.embedTextsBatch(['Text 1', 'Text 2']);

// 3. Dispose - Free native resources
embedder.dispose();
```

> **⚠️ Important:** You MUST call `dispose()` when done with an embedder. Failure to dispose will cause memory leaks in the Rust layer. Use try-finally blocks to ensure cleanup:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
try {
  final result = embedder.embedText('test');
  // Use result...
} finally {
  embedder.dispose(); // Always executes, even on error
}
```

**Main Methods:**

- `embedText(String text)` → `EmbeddingResult` - Embed a single text
- `embedTextsBatch(List<String> texts)` → `List<EmbeddingResult>` - Batch embed multiple texts (5-10x faster)
- `embedFile(String filePath, ...)` → `Future<List<ChunkEmbedding>>` - Embed a file with automatic chunking
- `embedDirectory(String path, ...)` → `Stream<ChunkEmbedding>` - Stream embeddings from all files in a directory
- `dispose()` - Free native resources immediately

**Properties:**

- `config` → `ModelConfig?` - The configuration used to create this embedder

---

### EmbeddingResult

The `EmbeddingResult` class represents a single dense vector embedding. It's an immutable value object containing the embedding vector and utility methods.

**Structure:**

```dart
final result = embedder.embedText('Machine learning');

// Access the raw vector
print(result.values);  // List<double> - [0.123, -0.456, 0.789, ...]

// Get dimension
print(result.dimension);  // int - 384 for BERT, 512 for Jina-small, etc

// Preview
print(result);  // EmbeddingResult(dimension: 384, preview: [0.123, -0.456...])
```

**Cosine Similarity:**

The `cosineSimilarity()` method computes the cosine similarity between two embeddings, returning a score from -1 to 1:

```dart
final emb1 = embedder.embedText('I love machine learning');
final emb2 = embedder.embedText('Machine learning is great');
final emb3 = embedder.embedText('I enjoy cooking pasta');

final sim12 = emb1.cosineSimilarity(emb2);
// Output: 0.8742 (high similarity - related topics)

final sim13 = emb1.cosineSimilarity(emb3);
// Output: 0.2156 (low similarity - unrelated topics)
```

**Understanding the Score:**
- **1.0** - Identical embeddings (maximum similarity)
- **0.7-0.9** - Highly related (same topic, similar meaning)
- **0.4-0.7** - Moderately related (some semantic overlap)
- **0.0-0.4** - Weakly related or unrelated
- **0.0** - Orthogonal (no semantic relationship)
- **-1.0** - Opposite (rare in natural language)

In practice, most natural language similarity scores fall in the 0.0-1.0 range.

**Equality and Hashing:**

`EmbeddingResult` implements value equality with a tolerance of 1e-6 for floating-point comparison:

```dart
final emb1 = embedder.embedText('test');
final emb2 = embedder.embedText('test');

print(emb1 == emb2);  // true - semantically identical
print(emb1.hashCode == emb2.hashCode);  // true
```

---

### ChunkEmbedding

The `ChunkEmbedding` class represents a text chunk extracted from a file, along with its embedding and metadata. This is returned by `embedFile()` and `embedDirectory()`.

**Structure:**

```dart
final chunks = await embedder.embedFile('document.pdf');

for (final chunk in chunks) {
  // Access embedding
  print(chunk.embedding.dimension);  // 384

  // Access text content
  print(chunk.text);  // "Machine learning enables computers to..."

  // Access metadata
  print(chunk.metadata);  // {'file_path': '...', 'page_number': '1', ...}

  // Convenience getters
  print(chunk.filePath);    // String? - Source file path
  print(chunk.page);        // int? - Page number (PDFs)
  print(chunk.chunkIndex);  // int? - Chunk index in document
}
```

**Common Metadata Keys:**
- `file_path` - Absolute path to source file
- `page_number` - Page number (PDF files only)
- `chunk_index` - Sequential index of chunk (0, 1, 2...)
- `heading` - Section heading (structured documents)

**Similarity with Other Chunks:**

```dart
final chunks = await embedder.embedFile('document.pdf');
final query = chunks.first;

// Find most similar chunk
double maxSim = -1;
ChunkEmbedding? mostSimilar;

for (final chunk in chunks.skip(1)) {
  final sim = query.cosineSimilarity(chunk);
  if (sim > maxSim) {
    maxSim = sim;
    mostSimilar = chunk;
  }
}

print('Most similar chunk: $mostSimilar');
print('Similarity score: $maxSim');
```

**Use Cases:**
- **Document search** - Find relevant passages in long documents
- **Q&A systems** - Match questions to relevant document chunks
- **Duplicate detection** - Find similar or duplicate content
- **Content clustering** - Group related document sections

---

### ModelConfig

The `ModelConfig` class provides type-safe configuration for loading embedding models from HuggingFace Hub.

**Predefined Configurations:**

The easiest way to use `ModelConfig` is through the predefined factory methods:

```dart
// BERT all-MiniLM-L6-v2 (384-dim, fast, general purpose)
final config1 = ModelConfig.bertMiniLML6();

// BERT all-MiniLM-L12-v2 (384-dim, better quality)
final config2 = ModelConfig.bertMiniLML12();

// Jina v2-small-en (512-dim, search-optimized)
final config3 = ModelConfig.jinaV2Small();

// Jina v2-base-en (768-dim, highest quality)
final config4 = ModelConfig.jinaV2Base();
```

**Custom Configuration:**

For advanced use cases, create a custom config:

```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',  // HuggingFace model ID
  modelType: EmbeddingModel.bert,                      // Architecture
  revision: 'main',                                    // Git revision
  dtype: ModelDtype.f16,                               // F32 or F16
  normalize: true,                                     // Unit normalization
  defaultBatchSize: 64,                                // Batch size
);

// Validate before use
config.validate();  // Throws InvalidConfigError if invalid

final embedder = EmbedAnything.fromConfig(config);
```

**Configuration Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `modelId` | `String` | required | HuggingFace model identifier |
| `modelType` | `EmbeddingModel` | required | BERT or Jina architecture |
| `revision` | `String` | `'main'` | Git branch, tag, or commit hash |
| `dtype` | `ModelDtype` | `f32` | F32 (full precision) or F16 (half precision) |
| `normalize` | `bool` | `true` | Normalize embeddings to unit length |
| `defaultBatchSize` | `int` | `32` | Batch size for batch operations |

**When to Customize:**

- **Memory constraints** → Use `dtype: ModelDtype.f16` to reduce memory by ~50%
- **Custom models** → Specify your own HuggingFace model ID
- **Version pinning** → Use specific `revision` for reproducibility
- **Performance tuning** → Adjust `defaultBatchSize` based on hardware
- **Large batches** → Increase `defaultBatchSize` to 64 or 128

---

## Memory Management

### Why Manual Disposal is Critical

EmbedAnythingInDart wraps native Rust resources (machine learning models loaded in memory). Dart's garbage collector **cannot automatically reclaim these native resources** because they exist outside Dart's heap.

**Without proper disposal:**
```dart
// ❌ BAD: Memory leak!
for (var i = 0; i < 100; i++) {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  embedder.embedText('test');
  // No dispose - Rust memory leaks!
}
```

Each iteration loads a ~90MB model into memory but never frees it. After 100 iterations, you've leaked ~9GB of RAM.

**With proper disposal:**
```dart
// ✅ GOOD: Reuse and dispose
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
try {
  for (var i = 0; i < 100; i++) {
    embedder.embedText('test $i');
  }
} finally {
  embedder.dispose();  // Frees ~90MB
}
```

### The Try-Finally Pattern

**Always** use try-finally to ensure disposal, even when errors occur:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
try {
  // Your code here - may throw exceptions
  final result = embedder.embedText(userInput);
  processResult(result);
} finally {
  // ALWAYS executes, even on exception
  embedder.dispose();
}
```

This pattern guarantees cleanup regardless of:
- Exceptions thrown during embedding
- Early returns from the function
- Async/await interruptions

### Multiple Embedders

You can have multiple embedders in memory simultaneously:

```dart
final bertEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
final jinaEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

try {
  final bertResult = bertEmbedder.embedText('test');
  final jinaResult = jinaEmbedder.embedText('test');

  // Compare models
  print('BERT dimension: ${bertResult.dimension}');    // 384
  print('Jina dimension: ${jinaResult.dimension}');    // 512
} finally {
  bertEmbedder.dispose();
  jinaEmbedder.dispose();
}
```

**Memory footprint:**
- BERT all-MiniLM-L6-v2 (F32): ~90MB
- Jina v2-small-en (F32): ~150MB
- Jina v2-base-en (F32): ~280MB

With F16 dtype, memory usage is approximately halved.

### NativeFinalizer Backup

EmbedAnythingInDart includes a `NativeFinalizer` that **may** clean up resources when the Dart object is garbage collected:

```dart
void temporaryUsage() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  embedder.embedText('test');
  // No dispose - finalizer may clean up eventually
}

// When embedder goes out of scope, GC may trigger finalizer
```

**Why this is not reliable:**
1. **Non-deterministic** - GC runs when Dart decides, not immediately
2. **May never run** - If memory pressure is low, GC might not trigger
3. **Delayed cleanup** - Could take seconds, minutes, or longer

> **⚠️ Best Practice:** Manual `dispose()` is strongly recommended for predictable, immediate cleanup. Only rely on finalizers for short-lived, low-stakes usage.

### Checking Disposal State

Attempting to use a disposed embedder throws `StateError`:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
embedder.dispose();

embedder.embedText('test');  // ❌ Throws StateError
```

You can safely call `dispose()` multiple times:

```dart
embedder.dispose();
embedder.dispose();  // No error - idempotent
embedder.dispose();  // Still safe
```

---

## Vector Embeddings 101

### What Are Vector Embeddings?

Vector embeddings are **dense numerical representations** of text that capture semantic meaning. Each text is converted into a list of floating-point numbers (a vector) in high-dimensional space.

**Example:**

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

final emb1 = embedder.embedText('cat');
// → [0.12, -0.34, 0.56, -0.78, ..., 0.91]  (384 numbers)

final emb2 = embedder.embedText('dog');
// → [0.15, -0.29, 0.51, -0.82, ..., 0.87]  (384 numbers)

final emb3 = embedder.embedText('car');
// → [-0.45, 0.67, -0.12, 0.34, ..., -0.21]  (384 numbers)
```

Semantically similar words (cat/dog) have similar vectors, while unrelated words (cat/car) have different vectors.

### Why Vectors?

Converting text to vectors enables:

1. **Semantic Search** - Find similar text based on meaning, not keywords
2. **Clustering** - Group similar documents together
3. **Classification** - Train ML models on embeddings
4. **Recommendation** - Suggest similar content
5. **Duplicate Detection** - Find near-duplicate text

**Traditional keyword search:**
```
Query: "machine learning"
Matches: Documents containing "machine" AND "learning"
Misses: "artificial intelligence", "neural networks" (different words, same concept)
```

**Semantic search with embeddings:**
```
Query embedding: [0.12, -0.34, ..., 0.56]
Matches: All documents with similar embeddings, regardless of exact words
Finds: "artificial intelligence", "neural networks", "deep learning" (same meaning)
```

### Semantic Similarity

Cosine similarity measures the angle between two vectors in high-dimensional space:

```dart
final query = embedder.embedText('machine learning');
final doc1 = embedder.embedText('artificial intelligence');
final doc2 = embedder.embedText('cooking recipes');

final sim1 = query.cosineSimilarity(doc1);  // 0.78 (related)
final sim2 = query.cosineSimilarity(doc2);  // 0.15 (unrelated)
```

**Visual Intuition:**

```
                    machine learning •
                               ↗ 0.78 similarity
                              •  artificial intelligence
                             ↙ (small angle)
                            •
                           ↙ 0.15 similarity (large angle)
                          •  cooking recipes
```

Small angles → high similarity → related meaning
Large angles → low similarity → unrelated meaning

### Dimensionality

Embedding dimension is the length of the vector. Higher dimensions can capture more nuanced meaning but require more memory and computation:

| Model | Dimension | Quality | Speed | Memory (F32) |
|-------|-----------|---------|-------|--------------|
| BERT all-MiniLM-L6-v2 | 384 | Good | Fast | ~90MB |
| BERT all-MiniLM-L12-v2 | 384 | Better | Medium | ~135MB |
| Jina v2-small-en | 512 | Good | Fast | ~150MB |
| Jina v2-base-en | 768 | Excellent | Slower | ~280MB |

**Choosing Dimension:**
- **384 dimensions** - Good balance for most applications
- **512 dimensions** - Better quality for semantic search
- **768 dimensions** - Maximum quality for critical applications

All vectors from the same model have the **same dimension**. You cannot compare embeddings from different models (different dimensions).

---

## Model Types: BERT vs Jina

### BERT Models

**BERT** (Bidirectional Encoder Representations from Transformers) models are general-purpose sentence embedding models trained on diverse text corpora.

**Characteristics:**
- **Fast inference** - Optimized for speed
- **General purpose** - Works well for diverse text types
- **Widely used** - Large community, many variants available
- **384 dimensions** - Standard for MiniLM variants

**Recommended Models:**
```dart
// Fast and efficient (recommended starting point)
ModelConfig.bertMiniLML6()
// sentence-transformers/all-MiniLM-L6-v2

// Better quality, slightly slower
ModelConfig.bertMiniLML12()
// sentence-transformers/all-MiniLM-L12-v2
```

**Best For:**
- General semantic similarity tasks
- Applications requiring fast inference
- Moderate quality requirements
- Resource-constrained environments

**Typical Performance:**
- Model load (warm cache): ~100-150ms
- Single embedding (short text): ~5-10ms
- Batch of 100 texts: ~200-300ms

### Jina Models

**Jina** models are specifically optimized for semantic search and retrieval tasks, trained on search-oriented datasets.

**Characteristics:**
- **Search-optimized** - Trained for retrieval tasks
- **Higher quality** - Better semantic understanding
- **Larger dimensions** - 512 or 768 dimensions
- **Slightly slower** - More computation per embedding

**Recommended Models:**
```dart
// Balanced search model
ModelConfig.jinaV2Small()
// jinaai/jina-embeddings-v2-small-en

// Highest quality
ModelConfig.jinaV2Base()
// jinaai/jina-embeddings-v2-base-en
```

**Best For:**
- Semantic search applications
- Document retrieval systems
- High-quality similarity matching
- Information retrieval tasks

**Typical Performance:**
- Model load (warm cache): ~150-200ms
- Single embedding (short text): ~10-15ms
- Batch of 100 texts: ~400-600ms

### Comparison Matrix

| Aspect | BERT MiniLM-L6 | BERT MiniLM-L12 | Jina v2-small | Jina v2-base |
|--------|----------------|-----------------|---------------|--------------|
| **Dimension** | 384 | 384 | 512 | 768 |
| **Speed** | ⚡⚡⚡ Fast | ⚡⚡ Medium | ⚡⚡ Medium | ⚡ Slower |
| **Quality** | ★★★ Good | ★★★★ Better | ★★★★ Better | ★★★★★ Excellent |
| **Memory (F32)** | ~90MB | ~135MB | ~150MB | ~280MB |
| **Memory (F16)** | ~45MB | ~68MB | ~75MB | ~140MB |
| **Use Case** | General | Quality focus | Search | Best quality |
| **Download Size** | ~90MB | ~120MB | ~133MB | ~280MB |

### Choosing Between BERT and Jina

**Use BERT when:**
- Building general-purpose semantic similarity features
- Speed is critical (real-time applications)
- Running on limited hardware
- Working with diverse text types

**Use Jina when:**
- Building search or retrieval systems
- Quality is more important than speed
- Working with English text specifically
- Have sufficient hardware resources

**Example Decision Tree:**

```
Do you need maximum quality?
├─ Yes → Jina v2-base (768-dim)
└─ No → Is this a search/retrieval application?
    ├─ Yes → Jina v2-small (512-dim)
    └─ No → Is speed critical?
        ├─ Yes → BERT MiniLM-L6 (384-dim)
        └─ No → BERT MiniLM-L12 (384-dim)
```

### Model Loading and Caching

All models are downloaded from HuggingFace Hub on first use and cached locally:

```
First Load:
1. Check ~/.cache/huggingface/hub
2. Not found → Download from HuggingFace (slow, 90-280MB)
3. Cache locally
4. Load into memory (~100-300ms)

Subsequent Loads:
1. Check cache
2. Found → Load from disk (~100-200ms)
3. No download needed
```

**Download Times (estimated):**
- On fast connection: 30-120 seconds
- On slow connection: 2-10 minutes

**Offline Usage:**
Once downloaded, models work completely offline. The cache persists between runs, so you only download once per model.

---

## Next Steps

Now that you understand the core concepts:

- **Get Started** → See [Getting Started](getting-started.md) for installation and first example
- **Learn Patterns** → Read [Usage Guide](usage-guide.md) for common patterns and best practices
- **API Reference** → Consult [API Reference](api-reference.md) for complete method signatures
- **Error Handling** → Study [Error Handling](error-handling.md) for robust applications
- **Model Configuration** → Dive into [Models and Configuration](models-and-configuration.md) for performance tuning

---

**Questions or Issues?**

- Check [Troubleshooting](../CLAUDE.md#troubleshooting) for common problems
- Review [Memory Management Tests](../test/memory_test.dart) for advanced patterns
- Study [Example Application](../example/embedanythingindart_example.dart) for complete code
