# Usage Guide

This guide demonstrates common patterns and real-world usage scenarios for EmbedAnythingInDart. Each section provides complete, working examples that you can adapt to your own use cases.

> **🚀 Async-First Design**: EmbedAnythingInDart provides **async methods** that don't block the UI thread. For Flutter apps and responsive applications, **always prefer async methods** (`embedTextAsync`, `embedTextsBatchAsync`, `fromPretrainedHfAsync`, etc.) over their synchronous counterparts.

## Table of Contents

- [Pattern 1: Async Text Embedding (Recommended)](#pattern-1-async-text-embedding-recommended)
- [Pattern 2: Async Batch Processing](#pattern-2-async-batch-processing)
- [Pattern 3: Semantic Search](#pattern-3-semantic-search)
- [Pattern 4: Semantic Clustering](#pattern-4-semantic-clustering)
- [Pattern 5: Async File Embedding](#pattern-5-async-file-embedding)
- [Pattern 6: Directory Processing](#pattern-6-directory-processing)
- [Pattern 7: Cancellable Operations](#pattern-7-cancellable-operations)
- [Sync vs Async: When to Use Each](#sync-vs-async-when-to-use-each)
- [Best Practices](#best-practices)

---

## Pattern 1: Async Text Embedding (Recommended)

This pattern shows the **recommended async workflow** for loading a model and embedding text without blocking the UI thread. Use async methods in Flutter apps and any application requiring responsive UIs.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> asyncTextEmbedding() async {
  // Load model asynchronously (doesn't freeze UI during download/load)
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    // Embed text asynchronously (doesn't block UI)
    final text = 'EmbedAnything is a fast embedding library written in Rust';
    final result = await embedder.embedTextAsync(text);

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

**Why Async?**
- **UI Responsiveness**: Model loading can take seconds (especially first-time downloads). Async keeps your UI responsive.
- **Non-Blocking**: Embedding generation runs on background threads, not the main Dart isolate.
- **Flutter-Ready**: Essential for Flutter apps where blocking the main thread causes frame drops.

**Key Points:**
- Use `fromPretrainedHfAsync()` for non-blocking model loading
- Use `embedTextAsync()` for non-blocking text embedding
- Dimension depends on the model (384 for BERT MiniLM-L6-v2)
- Always use try-finally to ensure `dispose()` is called

**When to Use:**
- ✅ **Flutter applications** - Always use async
- ✅ **Responsive CLI tools** - For long-running operations
- ✅ **Server applications** - To handle concurrent requests
- ✅ **Any UI application** - To prevent freezing

---

## Pattern 2: Async Batch Processing

Batch processing is 5-10x faster than embedding texts individually, and **async batch processing keeps your UI responsive** while processing large numbers of texts.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> asyncBatchProcessing() async {
  // Load model asynchronously
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    // Prepare multiple texts
    final texts = [
      'The quick brown fox jumps over the lazy dog',
      'Machine learning is transforming technology',
      'Rust provides memory safety without garbage collection',
      'Dart is a modern programming language for building apps',
      'Vector embeddings capture semantic meaning',
    ];

    // Batch process asynchronously (doesn't block UI)
    print('Generating embeddings for ${texts.length} texts...');
    final results = await embedder.embedTextsBatchAsync(texts);

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

**Async vs Sync Performance:**

```dart
Future<void> performanceComparison() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  final texts = List.generate(100, (i) => 'Sample text $i');

  try {
    // ❌ SLOWEST: Individual sync embedding (blocks UI!)
    final slowStart = DateTime.now();
    for (final text in texts) {
      embedder.embedText(text);
    }
    final slowDuration = DateTime.now().difference(slowStart);
    print('Individual sync: ${slowDuration.inMilliseconds}ms');

    // ⚠️ FASTER: Batch sync embedding (still blocks UI)
    final batchStart = DateTime.now();
    embedder.embedTextsBatch(texts);
    final batchDuration = DateTime.now().difference(batchStart);
    print('Batch sync: ${batchDuration.inMilliseconds}ms');

    // ✅ BEST: Batch async embedding (non-blocking!)
    final asyncStart = DateTime.now();
    await embedder.embedTextsBatchAsync(texts);
    final asyncDuration = DateTime.now().difference(asyncStart);
    print('Batch async: ${asyncDuration.inMilliseconds}ms');

    // Async doesn't block UI during processing!

  } finally {
    embedder.dispose();
  }
}
```

**Key Points:**
- Use `embedTextsBatchAsync()` for non-blocking batch processing
- Batch processing is 5-10x faster than individual calls
- Results are returned in the same order as input texts
- UI remains responsive during async operations

**When to Use:**
- ✅ Building search indices in Flutter apps
- ✅ Processing user uploads without freezing
- ✅ Background indexing operations
- ✅ Any batch operation in responsive applications

---

## Pattern 3: Semantic Search

Semantic search finds the most relevant items from a collection based on meaning, not just keyword matching. This is the most common use case for embeddings.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> semanticSearch() async {
  // Load model asynchronously
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

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

    // Step 1: Embed the query asynchronously
    final queryEmb = await embedder.embedTextAsync(query);

    // Step 2: Embed all candidates asynchronously (batch for performance)
    final candidateEmbs = await embedder.embedTextsBatchAsync(candidates);

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
Future<void> searchWithThreshold() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'jinaai/jina-embeddings-v2-small-en',
  );

  try {
    final query = 'machine learning algorithms';
    final candidates = [
      'Neural networks are a type of machine learning model',
      'I went grocery shopping yesterday',
      'Support vector machines are powerful ML algorithms',
      'My cat likes to sleep on the couch',
      'Deep learning uses multiple layers of neural networks',
    ];

    final queryEmb = await embedder.embedTextAsync(query);
    final candidateEmbs = await embedder.embedTextsBatchAsync(candidates);

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
- Use `embedTextAsync()` and `embedTextsBatchAsync()` for responsive search
- Cosine similarity returns values from -1 to 1 (typically 0 to 1 for natural language)
- Higher scores indicate greater semantic similarity
- Use batch embedding for candidates to maximize performance
- Sort results descending by similarity score

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

Future<void> semanticClustering() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

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

    // Step 1: Embed all items asynchronously
    print('Embedding ${items.length} items...');
    final embeddings = await embedder.embedTextsBatchAsync(items);

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
Future<void> findOutliers() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    final items = [
      'Machine learning algorithms',
      'Neural network architectures',
      'Deep learning frameworks',
      'I like bananas',  // Outlier
      'Gradient descent optimization',
    ];

    final embeddings = await embedder.embedTextsBatchAsync(items);

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

## Pattern 5: Async File Embedding

File embedding automatically chunks documents and embeds each chunk with metadata. **Use `embedFileAsync()` for non-blocking file processing** in Flutter apps.

```dart
import 'dart:io';
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> fileEmbedding() async {
  // Load model asynchronously
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    // Embed a file asynchronously with automatic chunking
    final filePath = 'path/to/document.txt';

    final chunks = await embedder.embedFileAsync(
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
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'jinaai/jina-embeddings-v2-small-en',
  );

  try {
    // Step 1: Index a document asynchronously
    print('Indexing document...');
    final chunks = await embedder.embedFileAsync(
      'machine_learning_guide.txt',
      chunkSize: 400,
      overlapRatio: 0.15,  // 15% overlap for better context preservation
    );

    print('Indexed ${chunks.length} chunks');

    // Step 2: Perform semantic search within the document
    final query = 'supervised learning algorithms';
    print('\nSearching for: "$query"');

    final queryEmb = await embedder.embedTextAsync(query);

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
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    // Supported formats: .txt, .md, .pdf, .docx, .html

    // Text file - async for responsive UI
    final txtChunks = await embedder.embedFileAsync('document.txt');
    print('TXT: ${txtChunks.length} chunks');

    // Markdown file
    final mdChunks = await embedder.embedFileAsync('readme.md');
    print('Markdown: ${mdChunks.length} chunks');

    // PDF file (requires PDF support in underlying library)
    try {
      final pdfChunks = await embedder.embedFileAsync('paper.pdf');
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
- Use `embedFileAsync()` for non-blocking file processing
- **chunkSize**: Target character count per chunk (300-1000 recommended)
- **overlapRatio**: Overlap between consecutive chunks (0.1-0.2 preserves context)
- **batchSize**: Number of chunks to process at once (32-64 recommended)
- Chunks include metadata: `filePath`, `chunkIndex`, `text`

**When to Use:**
- Building document search systems
- Question answering over documents
- Document summarization
- Information retrieval
- Knowledge base search

---

## Pattern 6: Directory Processing

Directory processing handles multiple files efficiently. Use **`embedDirectoryAsync()`** for non-blocking batch processing, or **`embedDirectory()`** streaming for memory-efficient processing of large collections.

### Async Batch Processing (Recommended for most use cases)

```dart
import 'dart:io';
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> directoryAsyncProcessing() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    final directoryPath = 'path/to/documents';

    print('Embedding all files in: $directoryPath');

    // Process directory asynchronously (non-blocking)
    final chunks = await embedder.embedDirectoryAsync(
      directoryPath,
      extensions: ['.txt', '.md'],
      chunkSize: 500,
      overlapRatio: 0.1,
      batchSize: 32,
    );

    print('Processed ${chunks.length} chunks from directory');

    // Use results
    for (final chunk in chunks) {
      print('Chunk from: ${chunk.filePath}');
    }

  } finally {
    embedder.dispose();
  }
}
```

### Streaming Processing (Memory-efficient for large collections)

```dart
Future<void> directoryStreaming() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

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
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'jinaai/jina-embeddings-v2-small-en',
  );

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
    final queryEmb = await embedder.embedTextAsync(query);

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
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

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
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

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

## Pattern 7: Cancellable Operations

For long-running operations, use `AsyncEmbeddingOperation` to allow cancellation. This is essential for responsive UIs where users may want to abort in-progress operations.

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> cancellableEmbedding() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    // Start an embedding operation that can be cancelled
    final operation = embedder.startEmbedTextAsync('Some very long text...');

    // In a real app, you might wire this to a cancel button
    // operation.cancel();

    // You can check cancellation status
    print('Is cancelled: ${operation.isCancelled}');

    try {
      // Wait for the result
      final result = await operation.future;
      print('Got embedding with dimension: ${result.dimension}');
    } on EmbeddingCancelledError {
      print('Operation was cancelled by user');
    }

  } finally {
    embedder.dispose();
  }
}
```

**Flutter Integration Example:**

```dart
class EmbeddingWidget extends StatefulWidget {
  @override
  _EmbeddingWidgetState createState() => _EmbeddingWidgetState();
}

class _EmbeddingWidgetState extends State<EmbeddingWidget> {
  AsyncEmbeddingOperation<EmbeddingResult>? _currentOperation;
  EmbedAnything? _embedder;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEmbedder();
  }

  Future<void> _loadEmbedder() async {
    _embedder = await EmbedAnything.fromPretrainedHfAsync(
      modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    );
  }

  Future<void> _startEmbedding(String text) async {
    if (_embedder == null) return;

    setState(() => _isLoading = true);

    // Start cancellable operation
    _currentOperation = _embedder!.startEmbedTextAsync(text);

    try {
      final result = await _currentOperation!.future;
      print('Success: ${result.dimension} dimensions');
    } on EmbeddingCancelledError {
      print('Cancelled by user');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _cancelOperation() {
    _currentOperation?.cancel();
  }

  @override
  void dispose() {
    _currentOperation?.cancel();
    _embedder?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => _startEmbedding('Some text'),
          child: Text('Start Embedding'),
        ),
        if (_isLoading)
          ElevatedButton(
            onPressed: _cancelOperation,
            child: Text('Cancel'),
          ),
      ],
    );
  }
}
```

**Key Points:**
- Use `startEmbedTextAsync()` to get an `AsyncEmbeddingOperation`
- Call `operation.cancel()` to request cancellation
- Handle `EmbeddingCancelledError` when awaiting the future
- Check `operation.isCancelled` to see cancellation status
- Always cancel pending operations in widget `dispose()`

---

## Sync vs Async: When to Use Each

EmbedAnythingInDart provides both synchronous and asynchronous APIs. **Always prefer async methods** unless you have a specific reason to use sync.

### Async Methods (Recommended)

| Async Method | Returns | Use Case |
|-------------|---------|----------|
| `fromPretrainedHfAsync()` | `Future<EmbedAnything>` | Loading models without blocking |
| `embedTextAsync()` | `Future<EmbeddingResult>` | Single text embedding |
| `embedTextsBatchAsync()` | `Future<List<EmbeddingResult>>` | Batch embedding |
| `embedFileAsync()` | `Future<List<ChunkEmbedding>>` | File embedding |
| `embedDirectoryAsync()` | `Future<List<ChunkEmbedding>>` | Directory embedding |
| `startEmbedTextAsync()` | `AsyncEmbeddingOperation` | Cancellable embedding |

**Benefits:**
- ✅ Non-blocking - UI stays responsive
- ✅ Flutter-compatible - No frame drops
- ✅ Cancellable - User can abort operations
- ✅ Better resource management

### Sync Methods (Use with caution)

| Sync Method | Returns | Use Case |
|------------|---------|----------|
| `fromConfig()` | `EmbedAnything` | Simple scripts, CLIs |
| `embedText()` | `EmbeddingResult` | Quick one-off operations |
| `embedTextsBatch()` | `List<EmbeddingResult>` | Batch operations in scripts |

**When sync is acceptable:**
- ⚠️ Command-line tools where blocking is OK
- ⚠️ One-time scripts or batch jobs
- ⚠️ Test code that doesn't need responsiveness

### Decision Guide

```
Building a Flutter app?
├─ YES → Use async methods exclusively
└─ NO → Building a CLI tool?
    ├─ YES → Sync OK for simple scripts, async for long operations
    └─ NO → Building a server?
        └─ Use async to handle concurrent requests
```

**Example: Same task, sync vs async:**

```dart
// ❌ SYNC: Freezes UI during model load and embedding
void syncExample() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  try {
    final result = embedder.embedText('Hello'); // Blocks!
    print(result.dimension);
  } finally {
    embedder.dispose();
  }
}

// ✅ ASYNC: UI stays responsive
Future<void> asyncExample() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  try {
    final result = await embedder.embedTextAsync('Hello'); // Non-blocking!
    print(result.dimension);
  } finally {
    embedder.dispose();
  }
}
```

---

## Best Practices

### 1. Always Use Async Methods in Flutter

```dart
// ✅ BEST: Async methods keep UI responsive
Future<void> flutterExample() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  try {
    final result = await embedder.embedTextAsync('test');
    // UI stays responsive during embedding
  } finally {
    embedder.dispose();
  }
}

// ❌ BAD: Sync methods freeze Flutter UI
void badFlutterExample() {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final result = embedder.embedText('test'); // UI freezes!
  embedder.dispose();
}
```

### 2. Always Dispose Embedders

```dart
// ✅ GOOD: Use try-finally with async
Future<void> goodExample() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  try {
    final result = await embedder.embedTextAsync('test');
    // ... use result ...
  } finally {
    embedder.dispose();  // Always called, even if exception occurs
  }
}

// ❌ BAD: No disposal (memory leak)
Future<void> badExample() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  final result = await embedder.embedTextAsync('test');
  // Memory leak! Rust resources not freed
}
```

### 3. Use Async Batch Methods for Multiple Texts

```dart
// ✅ GOOD: Async batch processing (5-10x faster, non-blocking)
Future<void> efficientBatch() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  try {
    final texts = ['text1', 'text2', 'text3', 'text4', 'text5'];
    final results = await embedder.embedTextsBatchAsync(texts);  // Fast + non-blocking!
  } finally {
    embedder.dispose();
  }
}

// ❌ BAD: Individual async calls (slower)
Future<void> inefficientLoop() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  try {
    final texts = ['text1', 'text2', 'text3', 'text4', 'text5'];
    for (final text in texts) {
      await embedder.embedTextAsync(text);  // Works but slower than batch!
    }
  } finally {
    embedder.dispose();
  }
}
```

### 4. Reuse Embedders, Don't Create Many Instances

```dart
// ✅ GOOD: Single embedder for many operations
Future<void> reuseEmbedder() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  try {
    for (var i = 0; i < 100; i++) {
      await embedder.embedTextAsync('text $i');
    }
  } finally {
    embedder.dispose();
  }
}

// ❌ BAD: Creating many embedders (memory leak + slow)
Future<void> createManyEmbedders() async {
  for (var i = 0; i < 100; i++) {
    final embedder = await EmbedAnything.fromPretrainedHfAsync(
      modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    );
    await embedder.embedTextAsync('text $i');
    // No dispose - memory leak!
  }
}
```

### 5. Choose Appropriate Chunk Sizes

```dart
Future<void> chunkSizeGuidelines() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    // Small chunks (200-300): Fine-grained search, more chunks
    final fineChunks = await embedder.embedFileAsync(
      'document.txt',
      chunkSize: 250,
      overlapRatio: 0.15,  // More overlap for small chunks
    );

    // Medium chunks (400-600): Balanced (recommended)
    final balancedChunks = await embedder.embedFileAsync(
      'document.txt',
      chunkSize: 500,
      overlapRatio: 0.1,
    );

    // Large chunks (800-1000): Broader context, fewer chunks
    final coarseChunks = await embedder.embedFileAsync(
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

### 6. Cache Embeddings for Reuse

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

Future<void> useCaching() async {
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
  final cache = EmbeddingCache('embeddings_cache.json');

  cache.load();  // Load existing cache

  try {
    final text = 'This is a sample text';

    // Check cache first
    var embedding = cache.get(text);

    if (embedding == null) {
      // Not in cache - compute it asynchronously
      embedding = await embedder.embedTextAsync(text);
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

### 7. Handle Errors Gracefully

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

Future<void> robustErrorHandling() async {
  EmbedAnything? embedder;

  try {
    // Model loading can fail
    embedder = await EmbedAnything.fromPretrainedHfAsync(
      modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    );

    // Embedding operations can fail
    final result = await embedder.embedTextAsync('sample text');

    // Use result...

  } on ModelNotFoundError catch (e) {
    print('Model not found: ${e.message}');
    print('Check HuggingFace Hub and network connectivity');
  } on EmbeddingCancelledError catch (e) {
    print('Operation was cancelled: ${e.message}');
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

### 8. Monitor First Model Load (Use Async!)

The first time you load a model, it downloads from HuggingFace Hub (90-500MB). **Always use async for model loading** to keep your UI responsive during downloads.

```dart
Future<void> firstLoadExample() async {
  print('Loading model (first time downloads from HuggingFace)...');
  final start = DateTime.now();

  // Use async loading to keep UI responsive during download
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  final duration = DateTime.now().difference(start);
  print('Model loaded in ${duration.inMilliseconds}ms');
  // First run: ~3000-10000ms (downloading, but UI stays responsive!)
  // Subsequent runs: ~100-150ms (cached)

  try {
    // Use embedder with async methods...
    final result = await embedder.embedTextAsync('Hello');
    print('Embedding dimension: ${result.dimension}');
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
