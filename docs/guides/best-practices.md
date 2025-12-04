# Best Practices Guide

A comprehensive guide to working with **EmbedAnythingInDart** - from initial setup to production-ready embedding workflows.

## Introduction

EmbedAnythingInDart provides high-performance vector embeddings for Dart applications by wrapping the Rust-based [EmbedAnything](https://github.com/StarlightSearch/EmbedAnything) library. This combination delivers:

- **Rust Performance**: Native ML inference via the Candle framework
- **Dart Ergonomics**: Idiomatic API with automatic memory management
- **Zero Config**: Models download automatically from HuggingFace Hub
- **Type Safety**: Sealed error classes enable exhaustive pattern matching

---

## Initial Setup

### 1. Add Dependency

Add to your `pubspec.yaml`:

```yaml
dependencies:
  embedanythingindart:
    git:
      url: https://github.com/YourOrg/embedanythingindart.git
      ref: main

environment:
  sdk: ^3.11.0-36.0.dev
```

### 2. Install Rust Toolchain

The library requires Rust 1.90.0 or later. Install via [rustup](https://rustup.rs/):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then navigate to the package and install required targets:

```bash
cd rust && rustup show
```

### 3. Get Dependencies

```bash
dart pub get
```

### 4. Run with Native Assets

All `dart run` and `dart test` commands require the experimental flag:

```bash
dart run --enable-experiment=native-assets your_app.dart
dart test --enable-experiment=native-assets
```

### First Build Expectations

The first build compiles ~488 Rust crates including the Candle ML framework. **Expect 2-5 minutes on first run.** Subsequent builds are incremental and much faster.

---

## Model Selection & Configuration

### Supported Models

| Model | Type | Dimensions | Best For |
|-------|------|------------|----------|
| `sentence-transformers/all-MiniLM-L6-v2` | BERT | 384 | General purpose, fast |
| `sentence-transformers/all-MiniLM-L12-v2` | BERT | 384 | Higher quality, slower |
| `jinaai/jina-embeddings-v2-small-en` | Jina | 512 | Semantic search, English |
| `jinaai/jina-embeddings-v2-base-en` | Jina | 768 | High quality semantic search |

### Using Predefined Configurations

The simplest approach uses predefined factory methods:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

// Fast, general-purpose (recommended starting point)
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

// Higher quality BERT
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML12());

// Semantic search optimized
final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

// Highest quality
final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());
```

### Custom Configuration

For fine-grained control, create a custom `ModelConfig`:

```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  revision: 'main',           // Pin to specific version if needed
  dtype: ModelDtype.f16,      // Half precision for speed/memory
  normalize: true,            // Normalize to unit vectors
  defaultBatchSize: 64,       // Larger batches for throughput
);

final embedder = EmbedAnything.fromConfig(config);
```

### Alternative Factory Method

Load directly from HuggingFace without a config object:

```dart
final embedder = EmbedAnything.fromPretrainedHf(
  model: EmbeddingModel.bert,
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  revision: 'main',
);
```

### Choosing the Right Model

| Use Case | Recommended Model | Why |
|----------|-------------------|-----|
| Prototype / Testing | `bertMiniLML6()` | Fastest, smallest |
| Production search | `jinaV2Small()` | Optimized for retrieval |
| Maximum accuracy | `jinaV2Base()` | Highest quality |
| Memory constrained | `bertMiniLML6()` + F16 | Smallest footprint |

---

## Embedder Lifecycle Management

### The Critical dispose() Pattern

**Native resources are not automatically freed.** Always use `try-finally`:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
try {
  final result = embedder.embedText('Hello, world!');
  print('Embedding dimension: ${result.dimension}');
} finally {
  embedder.dispose(); // ALWAYS call dispose
}
```

### Why Manual Disposal Matters

- The embedder holds a Rust `Arc<Embedder>` with loaded model weights
- Model weights consume 50-400MB of memory depending on the model
- Without `dispose()`, memory leaks accumulate
- Finalizers exist but are not guaranteed to run promptly

### Singleton Pattern (Recommended)

For applications that embed frequently, reuse a single embedder:

```dart
class EmbeddingService {
  static EmbedAnything? _instance;

  static EmbedAnything get embedder {
    _instance ??= EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
    return _instance!;
  }

  static void shutdown() {
    _instance?.dispose();
    _instance = null;
  }
}

// Usage
void main() {
  try {
    final result = EmbeddingService.embedder.embedText('query');
    // Use throughout application lifecycle
  } finally {
    EmbeddingService.shutdown();
  }
}
```

### Multiple Models

When you need different embedding dimensions or models:

```dart
final bertEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
final jinaEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());

try {
  // 384-dimensional embeddings
  final bertResult = bertEmbedder.embedText('semantic search query');

  // 768-dimensional embeddings
  final jinaResult = jinaEmbedder.embedText('semantic search query');
} finally {
  bertEmbedder.dispose();
  jinaEmbedder.dispose();
}
```

---

## Text Embedding Patterns

### Single Text Embedding

For one-off embeddings:

```dart
final result = embedder.embedText('The quick brown fox');

print('Dimensions: ${result.dimension}');  // 384 for BERT
print('First 5 values: ${result.values.take(5)}');
```

### Batch Embedding (5-10x Faster)

Always prefer batch processing for multiple texts:

```dart
final texts = [
  'First document about machine learning',
  'Second document about data science',
  'Third document about neural networks',
];

// Much faster than calling embedText() three times
final results = embedder.embedTextsBatch(texts);

for (var i = 0; i < texts.length; i++) {
  print('Text ${i + 1}: ${results[i].dimension} dimensions');
}
```

### When to Use Each

| Scenario | Method | Reason |
|----------|--------|--------|
| Single query | `embedText()` | Simpler API |
| 2+ texts | `embedTextsBatch()` | Significant speedup |
| Real-time user input | `embedText()` | Immediate response |
| Indexing corpus | `embedTextsBatch()` | Throughput critical |

---

## Semantic Similarity

### Computing Cosine Similarity

`EmbeddingResult` includes a built-in similarity method:

```dart
final emb1 = embedder.embedText('I love programming');
final emb2 = embedder.embedText('Programming is my passion');
final emb3 = embedder.embedText('The weather is nice today');

final sim12 = emb1.cosineSimilarity(emb2);  // ~0.87 (high similarity)
final sim13 = emb1.cosineSimilarity(emb3);  // ~0.15 (low similarity)

print('Programming similarity: ${sim12.toStringAsFixed(4)}');
print('Unrelated similarity: ${sim13.toStringAsFixed(4)}');
```

### Finding the Most Similar Item

```dart
EmbeddingResult findMostSimilar(
  EmbeddingResult query,
  List<EmbeddingResult> candidates,
) {
  var bestMatch = candidates.first;
  var bestScore = query.cosineSimilarity(bestMatch);

  for (final candidate in candidates.skip(1)) {
    final score = query.cosineSimilarity(candidate);
    if (score > bestScore) {
      bestScore = score;
      bestMatch = candidate;
    }
  }

  return bestMatch;
}
```

### Ranking by Similarity

```dart
List<(String, double)> rankBySimilarity(
  String query,
  List<String> documents,
  EmbedAnything embedder,
) {
  final queryEmb = embedder.embedText(query);
  final docEmbs = embedder.embedTextsBatch(documents);

  final scored = <(String, double)>[];
  for (var i = 0; i < documents.length; i++) {
    final score = queryEmb.cosineSimilarity(docEmbs[i]);
    scored.add((documents[i], score));
  }

  // Sort descending by similarity
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored;
}

// Usage
final ranked = rankBySimilarity(
  'machine learning tutorials',
  ['ML basics guide', 'Cooking recipes', 'Deep learning course'],
  embedder,
);

for (final (doc, score) in ranked) {
  print('${score.toStringAsFixed(3)}: $doc');
}
// Output:
// 0.847: Deep learning course
// 0.812: ML basics guide
// 0.134: Cooking recipes
```

---

## File & Directory Embedding

### Embedding a Single File

Embed documents with automatic chunking:

```dart
final chunks = await embedder.embedFile(
  '/path/to/document.pdf',
  chunkSize: 500,        // Characters per chunk
  overlapRatio: 0.1,     // 10% overlap between chunks
  batchSize: 32,         // Process 32 chunks at a time
);

for (final chunk in chunks) {
  print('File: ${chunk.filePath}');
  print('Page: ${chunk.page}');
  print('Chunk: ${chunk.chunkIndex}');
  print('Text preview: ${chunk.text?.substring(0, 100)}...');
  print('Embedding dim: ${chunk.embedding.dimension}');
}
```

### Supported File Formats

- PDF (`.pdf`)
- Plain text (`.txt`)
- Markdown (`.md`)
- Word documents (`.docx`)
- HTML (`.html`)

### Streaming Directory Embedding

For large directories, use streaming to avoid loading all embeddings into memory:

```dart
await for (final chunk in embedder.embedDirectory(
  '/path/to/documents/',
  extensions: ['.pdf', '.txt', '.md'],  // Filter by extension
  chunkSize: 300,
  overlapRatio: 0.05,
)) {
  // Process each chunk individually
  await saveToVectorDatabase(chunk);
  print('Processed: ${chunk.filePath}');
}
```

### Chunk Configuration Guidelines

| Content Type | Chunk Size | Overlap | Rationale |
|--------------|------------|---------|-----------|
| Technical docs | 500-1000 | 10-20% | Preserve code blocks |
| Articles | 300-500 | 5-10% | Paragraph boundaries |
| Legal/contracts | 200-400 | 15-25% | Context critical |
| Chat logs | 100-200 | 0% | Natural message boundaries |

### Accessing Chunk Metadata

`ChunkEmbedding` provides convenient getters:

```dart
final chunk = chunks.first;

// Direct property access
chunk.embedding;     // EmbeddingResult
chunk.text;          // Original text (optional)
chunk.metadata;      // Full metadata map

// Convenience getters
chunk.filePath;      // Source file path
chunk.page;          // Page number (PDFs)
chunk.chunkIndex;    // Chunk position in document

// Compare chunks
final similarity = chunks[0].cosineSimilarity(chunks[1]);
```

---

## Error Handling

### Sealed Error Hierarchy

All errors extend the sealed `EmbedAnythingError` class, enabling exhaustive pattern matching:

```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'invalid/nonexistent-model',
  );
} on EmbedAnythingError catch (e) {
  switch (e) {
    case ModelNotFoundError(:final modelId):
      print('Model "$modelId" not found on HuggingFace Hub');

    case InvalidConfigError(:final field, :final reason):
      print('Invalid configuration for "$field": $reason');

    case EmbeddingFailedError(:final reason):
      print('Embedding generation failed: $reason');

    case MultiVectorNotSupportedError():
      print('Multi-vector models not supported, use dense embedding models');

    case FFIError(:final operation, :final nativeError):
      print('Native error during $operation: $nativeError');

    case FileNotFoundError(:final path):
      print('File not found: $path');

    case UnsupportedFileFormatError(:final path, :final extension):
      print('Unsupported format "$extension" for file: $path');

    case FileReadError(:final path, :final reason):
      print('Cannot read "$path": $reason');
  }
}
```

### Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `ModelNotFoundError` | Typo in model ID | Verify model exists on HuggingFace Hub |
| `InvalidConfigError` | Bad configuration | Check `modelType` matches `modelId` |
| `FFIError` | Native crash | Check Rust logs, ensure deps installed |
| `FileNotFoundError` | Missing file | Verify path exists |
| `UnsupportedFileFormatError` | Bad extension | Use supported formats only |

### Graceful Degradation

```dart
EmbeddingResult? tryEmbed(String text, EmbedAnything embedder) {
  try {
    return embedder.embedText(text);
  } on EmbeddingFailedError catch (e) {
    print('Warning: Embedding failed for text, skipping: ${e.reason}');
    return null;
  }
}
```

---

## Performance Tips

### Model Caching

Models are cached locally after first download:

- **Location**: `~/.cache/huggingface/hub/`
- **First load**: Downloads model (100-500MB)
- **Subsequent loads**: Loads from cache (fast)

To pre-warm the cache:

```dart
void warmupModels() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  embedder.embedText('warmup'); // Triggers download if needed
  embedder.dispose();
}
```

### Batch Size Optimization

| Batch Size | Memory | Throughput | Use Case |
|------------|--------|------------|----------|
| 8-16 | Low | Moderate | Memory constrained |
| 32 (default) | Medium | Good | Balanced |
| 64-128 | High | Maximum | High-memory servers |

```dart
// Adjust via ModelConfig
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  defaultBatchSize: 64,  // Increase for throughput
);
```

### F16 vs F32 Precision

| Dtype | Memory | Speed | Quality |
|-------|--------|-------|---------|
| `ModelDtype.f32` | Higher | Baseline | Full precision |
| `ModelDtype.f16` | ~50% less | ~1.3x faster | Negligible loss |

```dart
// Use F16 for production when memory/speed matter
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,  // Recommended for production
);
```

### Memory Management Tips

1. **Reuse embedders**: Create once, use many times
2. **Dispose eagerly**: Call `dispose()` as soon as done
3. **Stream large directories**: Use `embedDirectory()` instead of loading all files
4. **Batch wisely**: Larger batches trade memory for speed

---

## Complete Example: Semantic Search

A production-ready semantic search implementation:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

/// A simple in-memory semantic search engine
class SemanticSearch {
  final EmbedAnything _embedder;
  final List<String> _documents = [];
  final List<EmbeddingResult> _embeddings = [];

  SemanticSearch._(this._embedder);

  /// Create a search engine with the specified model
  static SemanticSearch create({ModelConfig? config}) {
    final embedder = EmbedAnything.fromConfig(
      config ?? ModelConfig.bertMiniLML6(),
    );
    return SemanticSearch._(embedder);
  }

  /// Index documents for searching
  void indexDocuments(List<String> documents) {
    _documents.addAll(documents);
    _embeddings.addAll(_embedder.embedTextsBatch(documents));
  }

  /// Search for the top-k most relevant documents
  List<SearchResult> search(String query, {int topK = 5}) {
    final queryEmb = _embedder.embedText(query);

    final results = <SearchResult>[];
    for (var i = 0; i < _documents.length; i++) {
      final score = queryEmb.cosineSimilarity(_embeddings[i]);
      results.add(SearchResult(
        document: _documents[i],
        score: score,
        index: i,
      ));
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  /// Release native resources
  void dispose() {
    _embedder.dispose();
  }
}

class SearchResult {
  final String document;
  final double score;
  final int index;

  SearchResult({
    required this.document,
    required this.score,
    required this.index,
  });

  @override
  String toString() => '[$index] (${score.toStringAsFixed(3)}) $document';
}

// Usage
void main() {
  final search = SemanticSearch.create();

  try {
    // Index your corpus
    search.indexDocuments([
      'Introduction to machine learning with Python',
      'Advanced deep learning techniques',
      'Web development with Dart and Flutter',
      'Building REST APIs with Node.js',
      'Natural language processing fundamentals',
      'Computer vision and image recognition',
    ]);

    // Perform semantic search
    final results = search.search('AI and neural networks', topK: 3);

    print('Search results for "AI and neural networks":');
    for (final result in results) {
      print('  ${result}');
    }
    // Output:
    // [1] (0.847) Advanced deep learning techniques
    // [0] (0.812) Introduction to machine learning with Python
    // [4] (0.798) Natural language processing fundamentals

  } finally {
    search.dispose();
  }
}
```

---

## Summary

| Pattern | Best Practice |
|---------|---------------|
| Model selection | Start with `bertMiniLML6()`, upgrade as needed |
| Lifecycle | Always use `try-finally` with `dispose()` |
| Performance | Batch operations, reuse embedders |
| Memory | Use F16, stream large directories |
| Errors | Pattern match on sealed error types |
| Production | Singleton embedder, pre-warm cache |

For issues or questions, see the [GitHub repository](https://github.com/StarlightSearch/EmbedAnything).
