# Usage Guide

This guide demonstrates common patterns and real-world usage scenarios for EmbedAnythingInDart. Each section provides complete, working examples that you can adapt to your own use cases.

## Table of Contents

- [Pattern 1: Basic Text Embedding](#pattern-1-basic-text-embedding)
- [Pattern 2: Batch Processing](#pattern-2-batch-processing)
- [Pattern 3: Semantic Search](#pattern-3-semantic-search)
- [Pattern 4: Semantic Clustering](#pattern-4-semantic-clustering)
- [Pattern 5: File Embedding](#pattern-5-file-embedding)
- [Pattern 6: Directory Streaming](#pattern-6-directory-streaming)
- [Best Practices](#best-practices)

---

## Pattern 1: Basic Text Embedding

This pattern shows the most basic workflow: loading a model, embedding a single text, and properly cleaning up resources.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void basicTextEmbedding() {
  // Load model using predefined configuration (recommended)
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Embed a single text
    final text = 'EmbedAnything is a fast embedding library written in Rust';
    final result = embedder.embedText(text);

    // Access embedding properties
    print('Embedding dimension: ${result.dimension}');
    // Output: Embedding dimension: 384

    print('First 10 values: ${result.values.take(10).toList()}');
    // Output: First 10 values: [0.123, -0.456, 0.789, ...]

    print('Vector preview: ${result.toString()}');
    // Output: EmbeddingResult(dimension: 384, preview: [0.123, -0.456...])

  } finally {
    // ALWAYS dispose to prevent memory leaks
    embedder.dispose();
  }
}
```

**Key Points:**
- Use `ModelConfig.bertMiniLML6()` for general-purpose text embedding (fastest option)
- The `embedText()` method returns an `EmbeddingResult` containing the vector
- Dimension depends on the model (384 for BERT MiniLM-L6-v2)
- Always use try-finally to ensure `dispose()` is called

**When to Use:**
- Single text embedding operations
- Quick prototyping and testing
- Low-volume embedding generation

---

## Pattern 2: Batch Processing

Batch processing is 5-10x faster than embedding texts individually. Use this pattern when you have multiple texts to embed.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void batchProcessing() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Prepare multiple texts
    final texts = [
      'The quick brown fox jumps over the lazy dog',
      'Machine learning is transforming technology',
      'Rust provides memory safety without garbage collection',
      'Dart is a modern programming language for building apps',
      'Vector embeddings capture semantic meaning',
    ];

    // Batch process all texts at once
    print('Generating embeddings for ${texts.length} texts...');
    final results = embedder.embedTextsBatch(texts);

    // Process results
    print('Generated ${results.length} embeddings:');
    for (int i = 0; i < texts.length; i++) {
      print('  [$i] Dimension: ${results[i].dimension}');
    }

    // Output:
    // Generated 5 embeddings:
    //   [0] Dimension: 384
    //   [1] Dimension: 384
    //   [2] Dimension: 384
    //   [3] Dimension: 384
    //   [4] Dimension: 384

  } finally {
    embedder.dispose();
  }
}
```

**Performance Comparison:**

```dart
void performanceComparison() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final texts = List.generate(100, (i) => 'Sample text $i');

  try {
    // ❌ SLOW: Individual embedding (not recommended)
    final slowStart = DateTime.now();
    for (final text in texts) {
      embedder.embedText(text);
    }
    final slowDuration = DateTime.now().difference(slowStart);
    print('Individual: ${slowDuration.inMilliseconds}ms');
    // Output: Individual: ~5000ms

    // ✅ FAST: Batch embedding (recommended)
    final fastStart = DateTime.now();
    embedder.embedTextsBatch(texts);
    final fastDuration = DateTime.now().difference(fastStart);
    print('Batch: ${fastDuration.inMilliseconds}ms');
    // Output: Batch: ~500ms

    print('Speedup: ${slowDuration.inMilliseconds / fastDuration.inMilliseconds}x');
    // Output: Speedup: 10x

  } finally {
    embedder.dispose();
  }
}
```

**Key Points:**
- Use `embedTextsBatch()` for 2+ texts to get significant speedup
- Batch size is automatically optimized (configurable via `ModelConfig.defaultBatchSize`)
- Results are returned in the same order as input texts
- Memory usage scales linearly with batch size

**When to Use:**
- Embedding multiple documents, sentences, or paragraphs
- Building search indices
- Preprocessing datasets
- Any scenario with 2+ texts

---

## Pattern 3: Semantic Search

Semantic search finds the most relevant items from a collection based on meaning, not just keyword matching. This is the most common use case for embeddings.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void semanticSearch() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Define search query
    final query = 'Programming languages';

    // Define candidate documents
    final candidates = [
      'Python is a popular programming language',
      'The weather is nice today',
      'Rust is a systems programming language',
      'I like to eat pizza',
      'JavaScript runs in web browsers',
    ];

    print('Query: "$query"');
    print('Finding most similar from ${candidates.length} candidates...\n');

    // Step 1: Embed the query
    final queryEmb = embedder.embedText(query);

    // Step 2: Embed all candidates (batch for performance)
    final candidateEmbs = embedder.embedTextsBatch(candidates);

    // Step 3: Compute similarities
    final similarities = candidateEmbs
        .asMap()
        .entries
        .map((e) => MapEntry(e.key, queryEmb.cosineSimilarity(e.value)))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by similarity descending

    // Step 4: Display top results
    print('Top 3 most similar:');
    for (int i = 0; i < 3; i++) {
      final idx = similarities[i].key;
      final score = similarities[i].value;
      print('  ${i + 1}. [${score.toStringAsFixed(4)}] "${candidates[idx]}"');
    }

    // Output:
    // Top 3 most similar:
    //   1. [0.7823] "Python is a popular programming language"
    //   2. [0.7654] "Rust is a systems programming language"
    //   3. [0.6891] "JavaScript runs in web browsers"

  } finally {
    embedder.dispose();
  }
}
```

**Advanced: Threshold-Based Filtering**

```dart
void searchWithThreshold() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

  try {
    final query = 'machine learning algorithms';
    final candidates = [
      'Neural networks are a type of machine learning model',
      'I went grocery shopping yesterday',
      'Support vector machines are powerful ML algorithms',
      'My cat likes to sleep on the couch',
      'Deep learning uses multiple layers of neural networks',
    ];

    final queryEmb = embedder.embedText(query);
    final candidateEmbs = embedder.embedTextsBatch(candidates);

    // Filter by similarity threshold
    const threshold = 0.5;
    final relevantResults = <({int index, double score, String text})>[];

    for (int i = 0; i < candidates.length; i++) {
      final score = queryEmb.cosineSimilarity(candidateEmbs[i]);
      if (score >= threshold) {
        relevantResults.add((index: i, score: score, text: candidates[i]));
      }
    }

    // Sort by score descending
    relevantResults.sort((a, b) => b.score.compareTo(a.score));

    print('Found ${relevantResults.length} results above threshold $threshold:');
    for (final result in relevantResults) {
      print('  [${result.score.toStringAsFixed(4)}] "${result.text}"');
    }

    // Output:
    // Found 3 results above threshold 0.5:
    //   [0.8234] "Neural networks are a type of machine learning model"
    //   [0.7891] "Support vector machines are powerful ML algorithms"
    //   [0.7123] "Deep learning uses multiple layers of neural networks"

  } finally {
    embedder.dispose();
  }
}
```

**Key Points:**
- Cosine similarity returns values from -1 to 1 (typically 0 to 1 for natural language)
- Higher scores indicate greater semantic similarity
- Use batch embedding for candidates to maximize performance
- Sort results descending by similarity score
- Consider threshold filtering for large result sets (e.g., threshold > 0.5)

**When to Use:**
- Document search systems
- Question answering systems
- Content recommendation
- Finding similar items
- Duplicate detection

---

## Pattern 4: Semantic Clustering

Semantic clustering groups similar items together based on their meaning. This pattern computes pairwise similarities to identify clusters.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void semanticClustering() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Define items to cluster
    final items = [
      'I love programming in Rust',           // Programming cluster
      'Rust is my favorite programming language', // Programming cluster
      'Writing code in Rust is enjoyable',    // Programming cluster
      'I enjoy cooking delicious meals',      // Cooking cluster
      'Making pasta from scratch is fun',     // Cooking cluster
      'Homemade pizza tastes amazing',        // Cooking cluster
    ];

    // Step 1: Embed all items
    print('Embedding ${items.length} items...');
    final embeddings = embedder.embedTextsBatch(items);

    // Step 2: Compute pairwise similarity matrix
    print('Computing pairwise similarities...');
    final similarities = List.generate(
      items.length,
      (i) => List.generate(
        items.length,
        (j) => embeddings[i].cosineSimilarity(embeddings[j]),
      ),
    );

    // Step 3: Find clusters using threshold-based grouping
    const threshold = 0.6; // Items with similarity >= 0.6 are in same cluster
    final clusters = <List<int>>[];
    final assigned = <bool>[for (var i = 0; i < items.length; i++) false];

    for (int i = 0; i < items.length; i++) {
      if (assigned[i]) continue;

      // Start new cluster with item i
      final cluster = [i];
      assigned[i] = true;

      // Add all unassigned items similar to i
      for (int j = i + 1; j < items.length; j++) {
        if (!assigned[j] && similarities[i][j] >= threshold) {
          cluster.add(j);
          assigned[j] = true;
        }
      }

      clusters.add(cluster);
    }

    // Step 4: Display clusters
    print('\nFound ${clusters.length} clusters (threshold: $threshold):\n');
    for (int i = 0; i < clusters.length; i++) {
      print('Cluster ${i + 1}:');
      for (final idx in clusters[i]) {
        print('  - "${items[idx]}"');
      }

      // Show internal similarities
      if (clusters[i].length > 1) {
        final avgSim = clusters[i]
            .expand((a) => clusters[i].map((b) => similarities[a][b]))
            .reduce((a, b) => a + b) / (clusters[i].length * clusters[i].length);
        print('  Average internal similarity: ${avgSim.toStringAsFixed(4)}');
      }
      print('');
    }

    // Output:
    // Found 2 clusters (threshold: 0.6):
    //
    // Cluster 1:
    //   - "I love programming in Rust"
    //   - "Rust is my favorite programming language"
    //   - "Writing code in Rust is enjoyable"
    //   Average internal similarity: 0.8234
    //
    // Cluster 2:
    //   - "I enjoy cooking delicious meals"
    //   - "Making pasta from scratch is fun"
    //   - "Homemade pizza tastes amazing"
    //   Average internal similarity: 0.7891

  } finally {
    embedder.dispose();
  }
}
```

**Advanced: Finding Outliers**

```dart
void findOutliers() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    final items = [
      'Machine learning algorithms',
      'Neural network architectures',
      'Deep learning frameworks',
      'I like bananas',  // Outlier
      'Gradient descent optimization',
    ];

    final embeddings = embedder.embedTextsBatch(items);

    // Compute average similarity of each item to all others
    final avgSimilarities = <double>[];
    for (int i = 0; i < items.length; i++) {
      double sum = 0.0;
      for (int j = 0; j < items.length; j++) {
        if (i != j) {
          sum += embeddings[i].cosineSimilarity(embeddings[j]);
        }
      }
      avgSimilarities.add(sum / (items.length - 1));
    }

    // Identify outliers (low average similarity)
    const outlierThreshold = 0.4;
    print('Potential outliers (avg similarity < $outlierThreshold):');
    for (int i = 0; i < items.length; i++) {
      if (avgSimilarities[i] < outlierThreshold) {
        print('  "${items[i]}" (avg similarity: ${avgSimilarities[i].toStringAsFixed(4)})');
      }
    }

    // Output:
    // Potential outliers (avg similarity < 0.4):
    //   "I like bananas" (avg similarity: 0.1234)

  } finally {
    embedder.dispose();
  }
}
```

**Key Points:**
- Pairwise similarity is O(n²) - suitable for small to medium datasets (< 10,000 items)
- For large datasets, consider approximate nearest neighbor algorithms (not included in this library)
- Threshold selection depends on your domain (0.5-0.7 is typical)
- Batch embed all items first for best performance

**When to Use:**
- Topic modeling and discovery
- Content categorization
- Duplicate detection
- Anomaly detection
- Data exploration

---

## Pattern 5: File Embedding

File embedding automatically chunks documents and embeds each chunk with metadata. This enables semantic search within and across documents.

```dart
import 'dart:io';
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> fileEmbedding() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Embed a file with automatic chunking
    final filePath = 'path/to/document.txt';

    final chunks = await embedder.embedFile(
      filePath,
      chunkSize: 500,      // Target ~500 characters per chunk
      overlapRatio: 0.1,   // 10% overlap between chunks (preserves context)
      batchSize: 32,       // Process 32 chunks at a time
    );

    print('Generated ${chunks.length} chunks with metadata:\n');

    // Access chunk information
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];

      print('Chunk $i:');
      print('  File: ${chunk.filePath}');
      print('  Index: ${chunk.chunkIndex}');
      print('  Text length: ${chunk.text?.length ?? 0} chars');
      print('  Embedding dimension: ${chunk.embedding.dimension}');
      print('  Preview: ${chunk.text?.substring(0, 50).replaceAll('\n', ' ')}...');
      print('');
    }

    // Output:
    // Generated 4 chunks with metadata:
    //
    // Chunk 0:
    //   File: path/to/document.txt
    //   Index: 0
    //   Text length: 523 chars
    //   Embedding dimension: 384
    //   Preview: Introduction to Machine Learning. Machine learn...
    //
    // Chunk 1:
    //   File: path/to/document.txt
    //   Index: 1
    //   Text length: 498 chars
    //   Embedding dimension: 384
    //   Preview: Supervised learning algorithms learn from label...

  } finally {
    embedder.dispose();
  }
}
```

**Complete Example: Document Search System**

```dart
Future<void> documentSearchSystem() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

  try {
    // Step 1: Index a document
    print('Indexing document...');
    final chunks = await embedder.embedFile(
      'machine_learning_guide.txt',
      chunkSize: 400,
      overlapRatio: 0.15,  // 15% overlap for better context preservation
    );

    print('Indexed ${chunks.length} chunks');

    // Step 2: Perform semantic search within the document
    final query = 'supervised learning algorithms';
    print('\nSearching for: "$query"');

    final queryEmb = embedder.embedText(query);

    // Rank chunks by relevance
    final rankedChunks = chunks
        .asMap()
        .entries
        .map((e) => (
              chunk: e.value,
              index: e.key,
              similarity: queryEmb.cosineSimilarity(e.value.embedding),
            ))
        .toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));

    // Step 3: Display top results
    print('\nTop 3 most relevant chunks:');
    for (var i = 0; i < 3 && i < rankedChunks.length; i++) {
      final result = rankedChunks[i];
      print('\nRank ${i + 1}:');
      print('  Chunk index: ${result.index}');
      print('  Similarity: ${result.similarity.toStringAsFixed(4)}');
      print('  Text: "${result.chunk.text?.substring(0, 100).replaceAll('\n', ' ')}..."');
    }

    // Output:
    // Top 3 most relevant chunks:
    //
    // Rank 1:
    //   Chunk index: 7
    //   Similarity: 0.8523
    //   Text: "Supervised learning algorithms learn from labeled data. Common examples include linear regression..."
    //
    // Rank 2:
    //   Chunk index: 12
    //   Similarity: 0.7891
    //   Text: "Classification algorithms like support vector machines and decision trees are widely used..."

  } finally {
    embedder.dispose();
  }
}
```

**Supported File Formats:**

```dart
Future<void> supportedFormats() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Supported formats: .txt, .md, .pdf, .docx, .html

    // Text file
    final txtChunks = await embedder.embedFile('document.txt');
    print('TXT: ${txtChunks.length} chunks');

    // Markdown file
    final mdChunks = await embedder.embedFile('readme.md');
    print('Markdown: ${mdChunks.length} chunks');

    // PDF file (requires PDF support in underlying library)
    try {
      final pdfChunks = await embedder.embedFile('paper.pdf');
      print('PDF: ${pdfChunks.length} chunks');
    } on UnsupportedFileFormatError catch (e) {
      print('PDF not supported: ${e.message}');
    }

  } finally {
    embedder.dispose();
  }
}
```

**Key Points:**
- **chunkSize**: Target character count per chunk (300-1000 recommended)
- **overlapRatio**: Overlap between consecutive chunks (0.1-0.2 preserves context)
- **batchSize**: Number of chunks to process at once (32-64 recommended)
- Chunks include metadata: `filePath`, `chunkIndex`, `text`
- Use `ChunkEmbedding.cosineSimilarity()` to compare chunks directly

**When to Use:**
- Building document search systems
- Question answering over documents
- Document summarization
- Information retrieval
- Knowledge base search

---

## Pattern 6: Directory Streaming

Directory streaming processes multiple files efficiently without loading all chunks into memory at once. This is essential for large document collections.

```dart
import 'dart:io';
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> directoryStreaming() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    final directoryPath = 'path/to/documents';

    print('Embedding all files in: $directoryPath');

    // Stream chunks as they're generated (memory-efficient)
    await for (final chunk in embedder.embedDirectory(
      directoryPath,
      chunkSize: 500,
      overlapRatio: 0.1,
      batchSize: 32,
    )) {
      // Process each chunk as it arrives
      print('Processing chunk from: ${chunk.filePath}');

      // Example: Store in database, write to file, etc.
      // await database.insert(chunk);
    }

    print('Finished processing directory');

  } finally {
    embedder.dispose();
  }
}
```

**Complete Example: Building a Search Index**

```dart
Future<void> buildSearchIndex() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

  try {
    final docsPath = 'knowledge_base';

    // Storage for the index (in-memory for this example)
    final index = <ChunkEmbedding>[];

    print('Indexing documents in: $docsPath\n');

    // Stream all chunks from directory
    var chunkCount = 0;
    final filesSeen = <String>{};

    await for (final chunk in embedder.embedDirectory(
      docsPath,
      extensions: ['.txt', '.md'],  // Only process text and markdown files
      chunkSize: 400,
      batchSize: 64,
    )) {
      // Add to index
      index.add(chunk);
      chunkCount++;

      // Track files
      if (chunk.filePath != null) {
        filesSeen.add(chunk.filePath!);
      }

      // Progress reporting
      if (chunkCount % 100 == 0) {
        print('Indexed $chunkCount chunks from ${filesSeen.length} files...');
      }
    }

    print('\nIndexing complete!');
    print('Total chunks: $chunkCount');
    print('Total files: ${filesSeen.length}');
    print('Average chunks per file: ${(chunkCount / filesSeen.length).toStringAsFixed(1)}');

    // Now use the index for search
    print('\n--- Searching Index ---');
    final query = 'machine learning fundamentals';
    final queryEmb = embedder.embedText(query);

    final results = index
        .map((chunk) => (
              chunk: chunk,
              similarity: queryEmb.cosineSimilarity(chunk.embedding),
            ))
        .where((r) => r.similarity > 0.5)  // Filter by threshold
        .toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));

    print('Found ${results.length} relevant chunks:');
    for (var i = 0; i < 5 && i < results.length; i++) {
      final result = results[i];
      final fileName = result.chunk.filePath?.split('/').last ?? 'unknown';
      print('  ${i + 1}. $fileName (score: ${result.similarity.toStringAsFixed(4)})');
    }

    // Output:
    // Indexing documents in: knowledge_base
    //
    // Indexed 100 chunks from 23 files...
    // Indexed 200 chunks from 47 files...
    //
    // Indexing complete!
    // Total chunks: 237
    // Total files: 52
    // Average chunks per file: 4.6
    //
    // --- Searching Index ---
    // Found 18 relevant chunks:
    //   1. intro_to_ml.txt (score: 0.8734)
    //   2. ml_basics.md (score: 0.8234)
    //   3. learning_algorithms.txt (score: 0.7891)

  } finally {
    embedder.dispose();
  }
}
```

**Filtering by File Extension**

```dart
Future<void> extensionFiltering() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    final docsPath = 'mixed_documents';

    // Option 1: Process only text files
    print('Processing .txt files only...');
    var txtCount = 0;
    await for (final chunk in embedder.embedDirectory(
      docsPath,
      extensions: ['.txt'],
      chunkSize: 500,
    )) {
      txtCount++;
    }
    print('Processed $txtCount chunks from .txt files\n');

    // Option 2: Process multiple file types
    print('Processing .txt and .md files...');
    var textCount = 0;
    await for (final chunk in embedder.embedDirectory(
      docsPath,
      extensions: ['.txt', '.md'],
      chunkSize: 500,
    )) {
      textCount++;
    }
    print('Processed $textCount chunks from .txt and .md files\n');

    // Option 3: Process all supported formats (default)
    print('Processing all supported formats...');
    var allCount = 0;
    await for (final chunk in embedder.embedDirectory(
      docsPath,
      chunkSize: 500,
    )) {
      allCount++;
    }
    print('Processed $allCount chunks from all files');

  } finally {
    embedder.dispose();
  }
}
```

**Error Handling in Streams**

```dart
Future<void> robustDirectoryProcessing() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    final docsPath = 'documents';

    var successCount = 0;
    var errorCount = 0;

    try {
      await for (final chunk in embedder.embedDirectory(
        docsPath,
        chunkSize: 500,
      )) {
        successCount++;

        // Process chunk
        // ...
      }
    } on FileNotFoundError catch (e) {
      print('Directory not found: ${e.path}');
      errorCount++;
    } on FileReadError catch (e) {
      print('Error reading file: ${e.message}');
      errorCount++;
    }

    print('\nProcessing complete:');
    print('  Success: $successCount chunks');
    print('  Errors: $errorCount');

  } finally {
    embedder.dispose();
  }
}
```

**Key Points:**
- **Memory-efficient**: Chunks are streamed, not loaded all at once
- **Extension filtering**: Use `extensions` parameter to filter file types
- **Progress tracking**: Count chunks in the stream loop
- **Error handling**: Wrap in try-catch to handle file errors
- **Use cases**: Large document collections, background indexing

**When to Use:**
- Indexing large document collections (100s-1000s of files)
- Background processing workflows
- Memory-constrained environments
- Real-time processing as files are added
- Building search systems over document repositories

---

## Best Practices

### 1. Always Dispose Embedders

```dart
// ✅ GOOD: Use try-finally
void goodExample() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  try {
    final result = embedder.embedText('test');
    // ... use result ...
  } finally {
    embedder.dispose();  // Always called, even if exception occurs
  }
}

// ❌ BAD: No disposal (memory leak)
void badExample() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final result = embedder.embedText('test');
  // Memory leak! Rust resources not freed
}
```

### 2. Use Batch Methods for Multiple Texts

```dart
// ✅ GOOD: Batch processing (5-10x faster)
void efficientBatch() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  try {
    final texts = ['text1', 'text2', 'text3', 'text4', 'text5'];
    final results = embedder.embedTextsBatch(texts);  // Fast!
  } finally {
    embedder.dispose();
  }
}

// ❌ BAD: Individual calls (slow)
void inefficientLoop() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  try {
    final texts = ['text1', 'text2', 'text3', 'text4', 'text5'];
    for (final text in texts) {
      embedder.embedText(text);  // Slow!
    }
  } finally {
    embedder.dispose();
  }
}
```

### 3. Reuse Embedders, Don't Create Many Instances

```dart
// ✅ GOOD: Single embedder for many operations
void reuseEmbedder() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  try {
    for (var i = 0; i < 100; i++) {
      embedder.embedText('text $i');
    }
  } finally {
    embedder.dispose();
  }
}

// ❌ BAD: Creating many embedders (memory leak + slow)
void createManyEmbedders() {
  for (var i = 0; i < 100; i++) {
    final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
    embedder.embedText('text $i');
    // No dispose - memory leak!
  }
}
```

### 4. Choose Appropriate Chunk Sizes

```dart
Future<void> chunkSizeGuidelines() async {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  try {
    // Small chunks (200-300): Fine-grained search, more chunks
    final fineChunks = await embedder.embedFile(
      'document.txt',
      chunkSize: 250,
      overlapRatio: 0.15,  // More overlap for small chunks
    );

    // Medium chunks (400-600): Balanced (recommended)
    final balancedChunks = await embedder.embedFile(
      'document.txt',
      chunkSize: 500,
      overlapRatio: 0.1,
    );

    // Large chunks (800-1000): Broader context, fewer chunks
    final coarseChunks = await embedder.embedFile(
      'document.txt',
      chunkSize: 900,
      overlapRatio: 0.05,  // Less overlap for large chunks
    );

    print('Fine-grained: ${fineChunks.length} chunks');
    print('Balanced: ${balancedChunks.length} chunks');
    print('Coarse: ${coarseChunks.length} chunks');

  } finally {
    embedder.dispose();
  }
}
```

**Chunk Size Guidelines:**
- **200-300 characters**: Precise search, sentence-level granularity
- **400-600 characters**: Recommended for most use cases
- **800-1000 characters**: Paragraph-level, broader context
- **Overlap**: 0.1-0.2 (10-20%) preserves context across boundaries

### 5. Cache Embeddings for Reuse

```dart
import 'dart:convert';
import 'dart:io';

class EmbeddingCache {
  final Map<String, EmbeddingResult> _cache = {};
  final String _cacheFile;

  EmbeddingCache(this._cacheFile);

  // Save embedding to cache
  void put(String key, EmbeddingResult embedding) {
    _cache[key] = embedding;
  }

  // Retrieve embedding from cache
  EmbeddingResult? get(String key) {
    return _cache[key];
  }

  // Persist cache to disk
  void save() {
    final data = _cache.map((k, v) => MapEntry(k, v.values));
    File(_cacheFile).writeAsStringSync(jsonEncode(data));
  }

  // Load cache from disk
  void load() {
    try {
      final json = jsonDecode(File(_cacheFile).readAsStringSync()) as Map;
      _cache.clear();
      json.forEach((k, v) {
        _cache[k as String] = EmbeddingResult((v as List).cast<double>());
      });
    } catch (_) {
      // Cache file doesn't exist or is invalid
    }
  }
}

void useCaching() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final cache = EmbeddingCache('embeddings_cache.json');

  cache.load();  // Load existing cache

  try {
    final text = 'This is a sample text';

    // Check cache first
    var embedding = cache.get(text);

    if (embedding == null) {
      // Not in cache - compute it
      embedding = embedder.embedText(text);
      cache.put(text, embedding);
      print('Computed new embedding');
    } else {
      print('Retrieved from cache');
    }

    // Use embedding...

  } finally {
    cache.save();  // Persist cache
    embedder.dispose();
  }
}
```

### 6. Use Predefined Configs Unless Customizing

```dart
// ✅ GOOD: Use predefined configs (recommended)
void usePredefinedConfigs() {
  // General purpose - fastest
  final fast = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  // Better quality
  final better = EmbedAnything.fromConfig(ModelConfig.bertMiniLML12());

  // Search-optimized
  final search = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());

  // Highest quality
  final best = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());

  // Clean up
  fast.dispose();
  better.dispose();
  search.dispose();
  best.dispose();
}

// ⚠️ CUSTOM: Only when you need specific settings
void customConfig() {
  final config = ModelConfig(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    modelType: EmbeddingModel.bert,
    dtype: ModelDtype.f16,      // Half precision for speed
    normalize: true,            // Unit vector normalization
    defaultBatchSize: 128,      // Larger batches
  );

  final embedder = EmbedAnything.fromConfig(config);
  try {
    // ... use embedder ...
  } finally {
    embedder.dispose();
  }
}
```

### 7. Handle Errors Gracefully

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void robustErrorHandling() {
  EmbedAnything? embedder;

  try {
    // Model loading can fail
    embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

    // Embedding operations can fail
    final result = embedder.embedText('sample text');

    // Use result...

  } on ModelNotFoundError catch (e) {
    print('Model not found: ${e.message}');
    print('Check HuggingFace Hub and network connectivity');
  } on InvalidConfigError catch (e) {
    print('Invalid configuration: ${e.message}');
  } on EmbeddingFailedError catch (e) {
    print('Embedding failed: ${e.message}');
  } on FFIError catch (e) {
    print('FFI error: ${e.message}');
    print('Check native library installation');
  } on EmbedAnythingError catch (e) {
    // Catch-all for any EmbedAnything errors
    print('Error: ${e.message}');
  } finally {
    // Always dispose, even if error occurred
    embedder?.dispose();
  }
}
```

### 8. Monitor First Model Load

The first time you load a model, it downloads from HuggingFace Hub (90-500MB). Subsequent loads are fast.

```dart
Future<void> firstLoadExample() async {
  print('First load will download model (~100-500ms)...');
  final start = DateTime.now();

  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  final duration = DateTime.now().difference(start);
  print('Model loaded in ${duration.inMilliseconds}ms');
  // First run: ~3000-10000ms (downloading)
  // Subsequent runs: ~100-150ms (cached)

  try {
    // Use embedder...
  } finally {
    embedder.dispose();
  }
}
```

**Model Cache Location:**
- Linux/macOS: `~/.cache/huggingface/hub`
- Windows: `%USERPROFILE%\.cache\huggingface\hub`

---

## Summary

This guide covered the most common usage patterns for EmbedAnythingInDart:

1. **Basic Text Embedding**: Simple, single-text embedding workflow
2. **Batch Processing**: 5-10x faster for multiple texts
3. **Semantic Search**: Find relevant items by meaning, not keywords
4. **Semantic Clustering**: Group similar items together
5. **File Embedding**: Chunk and embed documents with metadata
6. **Directory Streaming**: Memory-efficient processing of large document collections

**Key Takeaways:**
- Always use try-finally to ensure `dispose()` is called
- Use batch methods for 2+ texts (much faster)
- Reuse embedders instead of creating many instances
- Choose appropriate chunk sizes (400-600 recommended)
- Cache embeddings when texts are reused
- Handle errors with specific exception types

**Next Steps:**
- Review [API Reference](api-reference.md) for complete API documentation
- Learn about [Error Handling](error-handling.md) patterns
- Explore [Models and Configuration](models-and-configuration.md) for choosing the right model
- Check [Advanced Topics](advanced-topics.md) for optimization strategies

For questions or issues, see the [project repository](https://github.com/StarlightSearch/EmbedAnything) or file an issue.
