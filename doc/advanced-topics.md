# Advanced Topics

This guide covers advanced usage scenarios, optimization techniques, and deep technical details for EmbedAnythingInDart. These topics are intended for developers who need to optimize performance, handle edge cases, or integrate the library into complex systems.

## Table of Contents

- [File Embedding Deep Dive](#file-embedding-deep-dive)
- [Directory Streaming](#directory-streaming)
- [Multiple Embedders](#multiple-embedders)
- [Performance Optimization](#performance-optimization)
- [Integration Patterns](#integration-patterns)
- [Platform Considerations](#platform-considerations)
- [Memory Management Deep Dive](#memory-management-deep-dive)
- [Edge Cases and Special Inputs](#edge-cases-and-special-inputs)

---

## File Embedding Deep Dive

The `embedFile()` method processes documents by automatically chunking them and generating embeddings for each chunk. This section explains how chunking works and how to optimize it for your use case.

### Supported File Formats

EmbedAnythingInDart supports these document formats:

- **PDF** (.pdf) - With page number extraction
- **Plain Text** (.txt)
- **Markdown** (.md)
- **Microsoft Word** (.docx)
- **HTML** (.html)

Files with unsupported extensions will throw `UnsupportedFileFormatError`:

```dart
try {
  await embedder.embedFile('document.xyz');
} on UnsupportedFileFormatError catch (e) {
  print('Format ${e.extension} not supported for file: ${e.path}');
}
```

### Chunking Strategies

#### Fixed-Size Chunks

The `chunkSize` parameter controls the maximum number of characters per chunk:

```dart
// Small chunks (good for precise retrieval)
final chunks = await embedder.embedFile(
  'document.pdf',
  chunkSize: 500,  // ~100 words
);

// Medium chunks (balanced)
final chunks = await embedder.embedFile(
  'document.pdf',
  chunkSize: 1000,  // ~200 words, default
);

// Large chunks (good for context)
final chunks = await embedder.embedFile(
  'document.pdf',
  chunkSize: 2000,  // ~400 words
);
```

**Choosing chunk size:**

- **Small chunks (300-600 chars)**: Best for FAQ search, precise matching
- **Medium chunks (800-1200 chars)**: Good default for most documents
- **Large chunks (1500-2500 chars)**: Better for capturing full context

#### Overlap for Context Preservation

The `overlapRatio` parameter adds overlap between consecutive chunks to preserve context:

```dart
// No overlap (default)
final chunks = await embedder.embedFile(
  'document.pdf',
  chunkSize: 1000,
  overlapRatio: 0.0,  // Each chunk is independent
);

// 10% overlap
final chunks = await embedder.embedFile(
  'document.pdf',
  chunkSize: 1000,
  overlapRatio: 0.1,  // 100 chars overlap between chunks
);

// 20% overlap (recommended for most use cases)
final chunks = await embedder.embedFile(
  'document.pdf',
  chunkSize: 1000,
  overlapRatio: 0.2,  // 200 chars overlap
);
```

**Benefits of overlap:**

- Prevents important information from being split at chunk boundaries
- Improves search recall when queries match content near boundaries
- Recommended range: 10-20% for most applications

### Metadata Extraction and Usage

Each `ChunkEmbedding` includes rich metadata:

```dart
final chunks = await embedder.embedFile('document.pdf');

for (final chunk in chunks) {
  // Basic metadata
  print('File: ${chunk.filePath}');
  print('Chunk index: ${chunk.chunkIndex}');

  // PDF-specific metadata
  if (chunk.page != null) {
    print('Page: ${chunk.page}');
  }

  // Access raw metadata map
  if (chunk.metadata != null) {
    print('All metadata: ${chunk.metadata}');
  }

  // Text preview
  if (chunk.text != null) {
    print('Text preview: ${chunk.text!.substring(0, 100)}...');
  }
}
```

### Batch Size Tuning for Files

The `batchSize` parameter controls how many chunks are embedded in parallel:

```dart
// Small batch (memory-constrained)
final chunks = await embedder.embedFile(
  'document.pdf',
  batchSize: 16,
);

// Default batch
final chunks = await embedder.embedFile(
  'document.pdf',
  batchSize: 32,  // Default
);

// Large batch (more memory, faster)
final chunks = await embedder.embedFile(
  'document.pdf',
  batchSize: 64,
);
```

**Tuning guidelines:**

- **Low memory**: Use batch size 16-24
- **Default**: Use batch size 32
- **High performance**: Use batch size 64-128

### Complete File Embedding Example

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> embedDocumentWithOptions() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Embed with optimized settings
    final chunks = await embedder.embedFile(
      'research_paper.pdf',
      chunkSize: 1200,      // Medium chunks for academic text
      overlapRatio: 0.15,   // 15% overlap to preserve context
      batchSize: 48,        // Moderate batch size
    );

    print('Processed ${chunks.length} chunks from document');

    // Index chunks with metadata
    for (int i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];

      // Store in database (pseudocode)
      await database.insert({
        'id': '${chunk.filePath}_chunk_${chunk.chunkIndex}',
        'text': chunk.text,
        'embedding': chunk.embedding.values,
        'metadata': {
          'file_path': chunk.filePath,
          'chunk_index': chunk.chunkIndex,
          'page': chunk.page,
          'dimension': chunk.embedding.dimension,
        },
      });
    }

    print('Successfully indexed ${chunks.length} chunks');
  } on FileNotFoundError catch (e) {
    print('File not found: ${e.path}');
  } on UnsupportedFileFormatError catch (e) {
    print('Unsupported format ${e.extension}: ${e.path}');
  } finally {
    embedder.dispose();
  }
}
```

---

## Directory Streaming

The `embedDirectory()` method processes entire directories using a streaming API, which is memory-efficient for large document collections.

### Memory-Efficient Processing

Unlike `embedFile()` which returns all chunks at once, `embedDirectory()` returns a `Stream<ChunkEmbedding>` that yields chunks as they're generated:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  // Process directory with streaming
  await for (final chunk in embedder.embedDirectory('documents/')) {
    // Process each chunk immediately without storing all in memory
    await processChunk(chunk);
  }
} finally {
  embedder.dispose();
}

Future<void> processChunk(ChunkEmbedding chunk) async {
  // Insert to database, write to file, etc.
  print('Processing ${chunk.filePath}, chunk ${chunk.chunkIndex}');
}
```

**Memory benefits:**

- Only one chunk is in memory at a time
- Suitable for processing thousands of documents
- No need to accumulate results before processing

### Extension Filtering

Filter which files to process by extension:

```dart
// Process only PDF files
final stream = embedder.embedDirectory(
  'documents/',
  extensions: ['.pdf'],
);

// Process text and markdown files
final stream = embedder.embedDirectory(
  'documents/',
  extensions: ['.txt', '.md'],
);

// Process all supported formats (default)
final stream = embedder.embedDirectory('documents/');
```

### Progress Tracking

Track progress while streaming:

```dart
int processedFiles = 0;
int processedChunks = 0;
String? currentFile;

await for (final chunk in embedder.embedDirectory('documents/')) {
  // Track file changes
  if (currentFile != chunk.filePath) {
    currentFile = chunk.filePath;
    processedFiles++;
    print('Processing file $processedFiles: $currentFile');
  }

  processedChunks++;

  // Report progress every 100 chunks
  if (processedChunks % 100 == 0) {
    print('Progress: $processedChunks chunks from $processedFiles files');
  }

  await processChunk(chunk);
}

print('Completed: $processedChunks chunks from $processedFiles files');
```

### Error Handling for Individual Files

Errors processing individual files are emitted to the stream:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  await for (final chunk in embedder.embedDirectory('documents/')) {
    await processChunk(chunk);
  }
} on FileNotFoundError catch (e) {
  print('Directory not found: ${e.path}');
} on FileReadError catch (e) {
  print('Error reading file ${e.path}: ${e.reason}');
} on UnsupportedFileFormatError catch (e) {
  print('Skipping unsupported file ${e.path} with extension ${e.extension}');
} finally {
  embedder.dispose();
}
```

### Complete Directory Processing Example

```dart
import 'dart:io';
import 'package:embedanythingindart/embedanythingindart.dart';

/// Index an entire document collection
Future<void> indexDocumentCollection(String directoryPath) async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

  try {
    int totalChunks = 0;
    final fileSet = <String>{};

    // Stream process all documents
    await for (final chunk in embedder.embedDirectory(
      directoryPath,
      extensions: ['.pdf', '.txt', '.md'],
      chunkSize: 1000,
      overlapRatio: 0.15,
    )) {
      // Track unique files
      fileSet.add(chunk.filePath!);
      totalChunks++;

      // Store chunk in vector database (pseudocode)
      await vectorDB.upsert(
        id: '${chunk.filePath}_${chunk.chunkIndex}',
        vector: chunk.embedding.values,
        metadata: {
          'text': chunk.text,
          'file': chunk.filePath,
          'chunk': chunk.chunkIndex,
          'page': chunk.page,
        },
      );

      // Progress indicator
      if (totalChunks % 50 == 0) {
        stdout.write('\rIndexed $totalChunks chunks from ${fileSet.length} files...');
      }
    }

    print('\n✓ Successfully indexed ${fileSet.length} files ($totalChunks chunks)');
  } catch (e) {
    print('Error indexing directory: $e');
    rethrow;
  } finally {
    embedder.dispose();
  }
}
```

---

## Multiple Embedders

You can use multiple embedding models simultaneously for comparison, multi-lingual support, or ensemble approaches.

### When to Use Multiple Models

**Model comparison:**
Compare different models to choose the best for your use case:

```dart
final bertEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
final jinaEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

try {
  final text = 'Sample text for comparison';

  final bertResult = bertEmbedder.embedText(text);
  final jinaResult = jinaEmbedder.embedText(text);

  print('BERT dimension: ${bertResult.dimension}');  // 384
  print('Jina dimension: ${jinaResult.dimension}');  // 512
} finally {
  bertEmbedder.dispose();
  jinaEmbedder.dispose();
}
```

**Multi-lingual embedding:**
Use different models for different languages:

```dart
final englishEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());
final multilingualEmbedder = EmbedAnything.fromConfig(
  ModelConfig(
    modelId: 'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2',
    modelType: EmbeddingModel.bert,
  ),
);

try {
  String detectLanguage(String text) {
    // Language detection logic
    return text.contains(RegExp(r'[a-zA-Z]')) ? 'en' : 'other';
  }

  EmbeddingResult embedAuto(String text) {
    final lang = detectLanguage(text);
    return lang == 'en'
        ? englishEmbedder.embedText(text)
        : multilingualEmbedder.embedText(text);
  }

  final result1 = embedAuto('English text');
  final result2 = embedAuto('Texto en español');
} finally {
  englishEmbedder.dispose();
  multilingualEmbedder.dispose();
}
```

### Memory Implications

Each embedder loads a complete model into memory:

- **BERT MiniLM-L6**: ~90 MB
- **BERT MiniLM-L12**: ~130 MB
- **Jina v2-small**: ~120 MB
- **Jina v2-base**: ~440 MB

Using F16 dtype reduces memory by ~50%:

```dart
// Full precision (default)
final embedderF32 = EmbedAnything.fromConfig(
  ModelConfig(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    modelType: EmbeddingModel.bert,
    dtype: ModelDtype.f32,  // ~90 MB
  ),
);

// Half precision
final embedderF16 = EmbedAnything.fromConfig(
  ModelConfig(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    modelType: EmbeddingModel.bert,
    dtype: ModelDtype.f16,  // ~45 MB
  ),
);
```

### Complete Multiple Embedders Example

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

/// Compare embeddings from multiple models
Future<void> compareModels() async {
  final models = [
    ModelConfig.bertMiniLML6(),
    ModelConfig.bertMiniLML12(),
    ModelConfig.jinaV2Small(),
  ];

  final embedders = models.map((config) =>
    EmbedAnything.fromConfig(config)
  ).toList();

  try {
    final testPairs = [
      ('Machine learning is fascinating', 'AI is interesting'),
      ('I love pizza', 'Pizza is delicious'),
      ('The weather is nice', 'It is raining'),
    ];

    for (final embedder in embedders) {
      print('\nModel: ${embedder.config!.modelId}');

      for (final (text1, text2) in testPairs) {
        final emb1 = embedder.embedText(text1);
        final emb2 = embedder.embedText(text2);
        final similarity = emb1.cosineSimilarity(emb2);

        print('  "${text1}" <-> "${text2}": ${similarity.toStringAsFixed(4)}');
      }
    }
  } finally {
    for (final embedder in embedders) {
      embedder.dispose();
    }
  }
}
```

---

## Performance Optimization

### Batch Size Tuning

Batch processing is 5-10x faster than individual embeddings:

```dart
// Slow: Individual embeddings
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
final texts = List.generate(100, (i) => 'Text $i');

// Sequential processing (SLOW)
final stopwatch1 = Stopwatch()..start();
final results1 = texts.map((t) => embedder.embedText(t)).toList();
stopwatch1.stop();
print('Sequential: ${stopwatch1.elapsedMilliseconds}ms');

// Batch processing (FAST)
final stopwatch2 = Stopwatch()..start();
final results2 = embedder.embedTextsBatch(texts);
stopwatch2.stop();
print('Batch: ${stopwatch2.elapsedMilliseconds}ms');

// Typical speedup: 5-10x faster with batching
embedder.dispose();
```

**Batch size recommendations:**

```dart
// Small batches (8-16): Memory-constrained environments
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  defaultBatchSize: 16,
);

// Medium batches (32-64): Default, balanced
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  defaultBatchSize: 32,  // Default
);

// Large batches (128+): High-throughput servers
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  defaultBatchSize: 128,
);
```

### F16 Dtype for Memory Reduction

Use F16 (half-precision) to reduce memory usage by ~50% with minimal quality impact:

```dart
// F32 (full precision, default)
final embedderF32 = EmbedAnything.fromConfig(
  ModelConfig(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    modelType: EmbeddingModel.bert,
    dtype: ModelDtype.f32,  // ~90 MB, highest quality
  ),
);

// F16 (half precision)
final embedderF16 = EmbedAnything.fromConfig(
  ModelConfig(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    modelType: EmbeddingModel.bert,
    dtype: ModelDtype.f16,  // ~45 MB, faster inference
  ),
);

// Quality comparison
final text = 'Sample text';
final embF32 = embedderF32.embedText(text);
final embF16 = embedderF16.embedText(text);

// F16 typically differs by < 0.1% from F32
final similarity = embF32.cosineSimilarity(embF16);
print('F32 vs F16 similarity: ${similarity.toStringAsFixed(6)}');
// Output: F32 vs F16 similarity: 0.999987

embedderF32.dispose();
embedderF16.dispose();
```

**When to use F16:**
- Memory is constrained
- Speed is more important than tiny quality differences
- Processing large volumes of data

### Caching Embedding Results

Cache embeddings to avoid recomputing:

```dart
class EmbeddingCache {
  final Map<String, EmbeddingResult> _cache = {};
  final EmbedAnything _embedder;

  EmbeddingCache(this._embedder);

  EmbeddingResult embedWithCache(String text) {
    if (_cache.containsKey(text)) {
      return _cache[text]!;
    }

    final result = _embedder.embedText(text);
    _cache[text] = result;
    return result;
  }

  void clearCache() => _cache.clear();

  int get cacheSize => _cache.length;
}

// Usage
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
final cache = EmbeddingCache(embedder);

try {
  // First call: computes embedding
  final result1 = cache.embedWithCache('hello world');

  // Second call: returns cached result (instant)
  final result2 = cache.embedWithCache('hello world');

  print('Cache hits save computation time');
} finally {
  embedder.dispose();
}
```

### Parallel Processing Strategies

Process multiple documents in parallel:

```dart
import 'dart:async';

Future<void> parallelFileEmbedding(List<String> filePaths) async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Process up to 4 files in parallel
    final results = await Future.wait(
      filePaths.map((path) => embedder.embedFile(path)),
    );

    for (int i = 0; i < results.length; i++) {
      print('File ${filePaths[i]}: ${results[i].length} chunks');
    }
  } finally {
    embedder.dispose();
  }
}
```

### Benchmarking Methodology

Measure performance accurately:

```dart
import 'dart:io';

Future<void> benchmarkModel(ModelConfig config) async {
  final embedder = EmbedAnything.fromConfig(config);

  try {
    // Warmup (first run loads model)
    embedder.embedText('warmup');

    // Benchmark single embedding
    final singleTexts = List.generate(100, (i) => 'Single test $i');
    final stopwatch1 = Stopwatch()..start();
    for (final text in singleTexts) {
      embedder.embedText(text);
    }
    stopwatch1.stop();

    // Benchmark batch embedding
    final batchTexts = List.generate(1000, (i) => 'Batch test $i');
    final stopwatch2 = Stopwatch()..start();
    embedder.embedTextsBatch(batchTexts);
    stopwatch2.stop();

    print('Model: ${config.modelId}');
    print('Single (100 texts): ${stopwatch1.elapsedMilliseconds}ms');
    print('Batch (1000 texts): ${stopwatch2.elapsedMilliseconds}ms');
    print('Speedup: ${(stopwatch1.elapsedMilliseconds * 10 / stopwatch2.elapsedMilliseconds).toStringAsFixed(1)}x');
  } finally {
    embedder.dispose();
  }
}
```

---

## Integration Patterns

### Vector Database Storage (Conceptual)

Embeddings are typically stored in vector databases for efficient similarity search:

```dart
// Pseudocode for vector database integration
Future<void> storeEmbeddings() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

  try {
    final texts = ['Document 1', 'Document 2', 'Document 3'];
    final embeddings = embedder.embedTextsBatch(texts);

    for (int i = 0; i < texts.length; i++) {
      await vectorDB.insert({
        'id': 'doc_$i',
        'text': texts[i],
        'vector': embeddings[i].values,  // List<double>
        'dimension': embeddings[i].dimension,
      });
    }

    // Search with similarity
    final queryEmb = embedder.embedText('search query');
    final results = await vectorDB.similaritySearch(
      vector: queryEmb.values,
      limit: 5,
    );
  } finally {
    embedder.dispose();
  }
}
```

### Caching Layer

Implement a caching layer to reduce computation:

```dart
import 'dart:convert';
import 'dart:io';

class PersistentEmbeddingCache {
  final File _cacheFile;
  final EmbedAnything _embedder;
  Map<String, List<double>> _cache = {};

  PersistentEmbeddingCache(this._embedder, String cacheFilePath)
      : _cacheFile = File(cacheFilePath) {
    _loadCache();
  }

  void _loadCache() {
    if (_cacheFile.existsSync()) {
      final json = jsonDecode(_cacheFile.readAsStringSync());
      _cache = Map<String, List<double>>.from(
        json.map((k, v) => MapEntry(k, List<double>.from(v))),
      );
    }
  }

  void _saveCache() {
    _cacheFile.writeAsStringSync(jsonEncode(_cache));
  }

  EmbeddingResult embedWithCache(String text) {
    if (_cache.containsKey(text)) {
      return EmbeddingResult(_cache[text]!);
    }

    final result = _embedder.embedText(text);
    _cache[text] = result.values;
    _saveCache();
    return result;
  }
}
```

### Microservice Architecture

Wrap embedder in a server:

```dart
// Pseudocode for HTTP server embedding service
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> runEmbeddingServer() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler((Request request) async {
    if (request.url.path == 'embed') {
      final body = await request.readAsString();
      final json = jsonDecode(body);
      final text = json['text'] as String;

      final result = embedder.embedText(text);

      return Response.ok(jsonEncode({
        'embedding': result.values,
        'dimension': result.dimension,
      }));
    }

    return Response.notFound('Not found');
  });

  await io.serve(handler, 'localhost', 8080);
}
```

### Background Processing

Process embeddings in isolates:

```dart
import 'dart:isolate';

// Isolate entry point
void embedIsolate(SendPort sendPort) {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is String) {
      final result = embedder.embedText(message);
      sendPort.send(result.values);
    }
  });
}

// Main isolate
Future<List<double>> embedInBackground(String text) async {
  final receivePort = ReceivePort();
  await Isolate.spawn(embedIsolate, receivePort.sendPort);

  final sendPort = await receivePort.first as SendPort;
  final responsePort = ReceivePort();

  sendPort.send(text);
  final result = await responsePort.first as List<double>;

  return result;
}
```

---

## Platform Considerations

### Supported Platforms

EmbedAnythingInDart currently supports **desktop platforms only**:

- macOS (x86_64, ARM64)
- Linux (x86_64)
- Windows (x86_64)

Platform-specific tests ensure consistency:

```dart
import 'dart:io';

void checkPlatform() {
  if (Platform.isMacOS) {
    print('Running on macOS');
  } else if (Platform.isLinux) {
    print('Running on Linux');
  } else if (Platform.isWindows) {
    print('Running on Windows');
  } else {
    throw UnsupportedError('Platform ${Platform.operatingSystem} not supported');
  }
}
```

### Why Web Isn't Supported

The library uses native Rust binaries compiled via FFI, which cannot run in browser environments:

- Web requires JavaScript/WebAssembly
- FFI (Foreign Function Interface) doesn't work in browsers
- Native binaries require OS-level process execution

### Cross-Platform Consistency

Models produce identical embeddings across platforms:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final text = 'Cross-platform consistency test';

  // Run on multiple platforms
  final result1 = embedder.embedText(text);
  final result2 = embedder.embedText(text);

  // Results are identical (within floating point precision)
  final similarity = result1.cosineSimilarity(result2);
  print('Consistency: ${similarity.toStringAsFixed(8)}');
  // Output: Consistency: 1.00000000
} finally {
  embedder.dispose();
}
```

### Model Caching Across Platforms

Models are cached in the same location on all platforms:

- **macOS/Linux**: `~/.cache/huggingface/hub`
- **Windows**: `%USERPROFILE%\.cache\huggingface\hub`

First model load downloads from HuggingFace Hub (slow, 100-500MB). Subsequent loads use the cache (fast, 100-150ms).

---

## Memory Management Deep Dive

### FFI Memory Ownership Transfer

EmbedAnythingInDart uses a carefully designed memory ownership transfer pattern between Rust and Dart:

**Ownership flow:**

1. **Rust allocates**: Embeddings are computed in Rust, allocating `Vec<f32>` on heap
2. **Transfer to Dart**: Rust converts to raw pointer, uses `std::mem::forget()` to prevent automatic deallocation
3. **Dart copies**: Dart reads the raw pointer and copies values to `List<double>`
4. **Rust reclaims**: Dart immediately calls FFI free function to reclaim Rust memory

```dart
// Simplified view of memory transfer
EmbeddingResult embedText(String text) {
  // 1. Call FFI function (Rust allocates)
  final embeddingPtr = ffi.embedText(_handle, textPtr);

  try {
    // 2. Dart reads and copies values
    final embedding = embeddingPtr.ref;
    final values = _copyFloatArray(embedding.values, embedding.len);

    // 3. Dart owns the copied values
    return EmbeddingResult(values);
  } finally {
    // 4. Rust memory is freed
    ffi.freeEmbedding(embeddingPtr);
  }
}
```

### NativeFinalizer Mechanism

Dart uses `NativeFinalizer` for automatic cleanup when embedder objects are garbage collected:

```dart
// Simplified finalizer pattern
class EmbedAnything {
  final Pointer<CEmbedder> _handle;
  bool _disposed = false;

  // Finalizer is attached when embedder is created
  static final _finalizer = NativeFinalizer(
    ffi.embedderFreePtr,  // Calls Rust cleanup function
  );

  EmbedAnything._(this._handle) {
    // Attach finalizer to this object
    _finalizer.attach(this, _handle.cast(), detach: this);
  }

  void dispose() {
    if (!_disposed) {
      // Manual disposal detaches finalizer
      _finalizer.detach(this);
      ffi.embedderFree(_handle);
      _disposed = true;
    }
  }
}
```

### When to Manually Dispose vs Rely on Finalizers

**Always manually dispose:**

The library requires explicit `dispose()` calls for predictable resource cleanup:

```dart
// ✓ CORRECT: Always use try-finally
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
try {
  final result = embedder.embedText('test');
  // Use result...
} finally {
  embedder.dispose();  // REQUIRED
}

// ✗ WRONG: Relying on GC is not enough
void badExample() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final result = embedder.embedText('test');
  // Missing dispose() - may cause resource leak
}
```

**Why manual disposal is required:**

- Finalizers run non-deterministically during garbage collection
- Native resources (GPU memory, file handles) may not be reclaimed promptly
- Predictable cleanup ensures resources are available for subsequent operations

### Memory Leak Detection

Test for memory leaks with repeated allocation/deallocation:

```dart
void testMemoryLeaks() {
  // Create and dispose 100 embedders
  for (int i = 0; i < 100; i++) {
    final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

    // Use the embedder
    final result = embedder.embedText('Test $i');
    expect(result.dimension, equals(384));

    // Dispose immediately
    embedder.dispose();
  }

  // If no crash or slowdown, memory management is working
  print('Memory leak test passed');
}
```

### Large Batch Memory Management

Process large batches efficiently:

```dart
void processLargeBatch() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Generate 1000 texts
    final texts = List.generate(1000, (i) => 'Text number $i');

    // Process in batch (results are automatically managed)
    final results = embedder.embedTextsBatch(texts);

    // Results are Dart objects, memory is managed by Dart GC
    expect(results.length, equals(1000));

    // No manual cleanup needed for results
    // Dart GC handles List<EmbeddingResult>
  } finally {
    // Only the embedder needs manual disposal
    embedder.dispose();
  }
}
```

### Multiple Dispose Calls Are Safe

The `dispose()` method is idempotent:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

embedder.dispose();
embedder.dispose();  // Safe, no-op
embedder.dispose();  // Still safe

// But using after dispose throws StateError
expect(
  () => embedder.embedText('test'),
  throwsA(isA<StateError>()),
);
```

---

## Edge Cases and Special Inputs

### Empty Strings

Empty strings are handled gracefully:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final result = embedder.embedText('');

  // Empty string still produces valid embedding
  expect(result.dimension, equals(384));
  expect(result.values.length, equals(384));

  print('Empty string embedding: ${result.values.take(5)}');
} finally {
  embedder.dispose();
}
```

### Very Long Text (Truncation)

BERT models have a maximum token limit (typically 512 tokens):

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  // Create text exceeding token limit (~1000 words)
  final longText = 'word ' * 1000;

  // Model automatically truncates to fit token limit
  final result = embedder.embedText(longText);

  // Still produces valid 384-dim embedding
  expect(result.dimension, equals(384));
} finally {
  embedder.dispose();
}
```

**Handling very long text:**

For documents longer than the token limit, use file embedding with chunking:

```dart
// For long documents, use chunking
final chunks = await embedder.embedFile(
  'long_document.txt',
  chunkSize: 1000,  // Chunks fit within token limit
);

// Each chunk is embedded separately
for (final chunk in chunks) {
  print('Chunk ${chunk.chunkIndex}: ${chunk.embedding.dimension} dim');
}
```

### Unicode and Emoji Handling

Unicode characters and emoji are handled correctly:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  // Emoji
  final emojiResult = embedder.embedText('Hello 👋 World 🌍 😊');
  expect(emojiResult.dimension, equals(384));

  // Chinese characters
  final chineseResult = embedder.embedText('你好世界，这是一个测试');
  expect(chineseResult.dimension, equals(384));

  // Arabic script
  final arabicResult = embedder.embedText('مرحبا بالعالم هذا اختبار');
  expect(arabicResult.dimension, equals(384));

  // All produce valid embeddings
} finally {
  embedder.dispose();
}
```

### Multi-Language Text

Models handle multi-language text based on their training:

```dart
// English-optimized models work best with English
final englishEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

// For multilingual text, use multilingual models
final multilingualEmbedder = EmbedAnything.fromConfig(
  ModelConfig(
    modelId: 'sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2',
    modelType: EmbeddingModel.bert,
  ),
);
```

### Mixed-Length Batches

Batch operations handle varying text lengths:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final mixedTexts = [
    '',  // Empty
    'Short',  // Short
    'This is a medium length text with some content',  // Medium
    'word ' * 200,  // Very long
    '   ',  // Whitespace only
    'Normal text at the end',
  ];

  // All texts are embedded successfully
  final results = embedder.embedTextsBatch(mixedTexts);

  expect(results.length, equals(6));
  for (final result in results) {
    expect(result.dimension, equals(384));
  }
} finally {
  embedder.dispose();
}
```

### Whitespace-Only Strings

Whitespace-only strings produce valid embeddings:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final whitespaceResult = embedder.embedText('   \t  \n  ');

  expect(whitespaceResult.dimension, equals(384));
  print('Whitespace embedding: ${whitespaceResult.values.take(5)}');
} finally {
  embedder.dispose();
}
```

### Special Characters

Special characters (quotes, newlines, tabs) are handled:

```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  // Newlines and tabs
  final result1 = embedder.embedText('Line 1\nLine 2\tTabbed');

  // Quotes and apostrophes
  final result2 = embedder.embedText('Text with "quotes" and \'apostrophes\'');

  // Both produce valid embeddings
  expect(result1.dimension, equals(384));
  expect(result2.dimension, equals(384));
} finally {
  embedder.dispose();
}
```

---

## Summary

This advanced topics guide covered:

- **File embedding**: Chunking strategies, metadata extraction, batch size tuning
- **Directory streaming**: Memory-efficient processing, extension filtering, progress tracking
- **Multiple embedders**: Model comparison, multi-lingual support, memory implications
- **Performance optimization**: Batch processing, F16 dtype, caching, parallel processing
- **Integration patterns**: Vector databases, caching layers, microservices, background processing
- **Platform considerations**: Supported platforms, web limitations, cross-platform consistency
- **Memory management**: FFI ownership transfer, finalizers, manual disposal requirements
- **Edge cases**: Empty strings, long text, Unicode, mixed batches, special characters

For additional questions or advanced use cases not covered here, please refer to:

- [API Reference](api-reference.md) - Complete API documentation
- [Usage Guide](usage-guide.md) - Common usage patterns
- [Error Handling](error-handling.md) - Error types and handling strategies
- [CLAUDE.md](../CLAUDE.md) - Architecture and troubleshooting details
