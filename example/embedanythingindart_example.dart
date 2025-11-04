import 'dart:io';

import 'package:embedanythingindart/embedanythingindart.dart';

void main() async {
  print('=== EmbedAnything Dart Example ===\n');

  // ============================================================================
  // Example 1: Loading Models with Different Configurations
  // ============================================================================
  print('--- Example 1: Loading Models ---');

  // Method 1: Using predefined configurations (recommended)
  print('Loading BERT model using predefined config...');
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  print('Model loaded successfully!\n');

  // Method 2: Using custom configuration
  print('Loading Jina model with custom configuration...');
  final customConfig = ModelConfig(
    modelId: 'jinaai/jina-embeddings-v2-small-en',
    modelType: EmbeddingModel.jina,
    dtype: ModelDtype.f16, // Use half precision for faster inference
    defaultBatchSize: 64,
  );
  final jinaEmbedder = EmbedAnything.fromConfig(customConfig);
  print('Custom Jina model loaded successfully!');
  print('Config: ${customConfig.toString()}\n');

  // ============================================================================
  // Example 2: Single Text Embedding
  // ============================================================================
  print('--- Example 2: Single Text Embedding ---');

  final text = 'EmbedAnything is a fast embedding library written in Rust';
  print('Embedding text: "$text"');

  final result = embedder.embedText(text);
  print('Embedding dimension: ${result.dimension}');
  print('First 10 values: ${result.values.take(10).toList()}');
  print('Vector preview: ${result.toString()}\n');

  // ============================================================================
  // Example 3: Batch Embedding for Performance
  // ============================================================================
  print('--- Example 3: Batch Embedding ---');

  final texts = [
    'The quick brown fox jumps over the lazy dog',
    'Machine learning is transforming technology',
    'Rust provides memory safety without garbage collection',
    'Dart is a modern programming language for building apps',
    'Vector embeddings capture semantic meaning',
  ];

  print(
    'Generating embeddings for ${texts.length} texts using batch processing...',
  );
  final batchResults = embedder.embedTextsBatch(texts);

  print('Generated ${batchResults.length} embeddings:');
  for (int i = 0; i < texts.length; i++) {
    print('  [$i] Dimension: ${batchResults[i].dimension}');
  }
  print('');

  // ============================================================================
  // Example 4: Computing Semantic Similarity
  // ============================================================================
  print('--- Example 4: Semantic Similarity ---');

  // Related texts (should have high similarity)
  final text1 = 'I love programming in Rust';
  final text2 = 'Rust is my favorite programming language';
  final text3 = 'Writing code in Rust is enjoyable';

  // Unrelated text (should have low similarity)
  final text4 = 'I enjoy cooking delicious meals';

  print('Embedding texts for similarity comparison...');
  final emb1 = embedder.embedText(text1);
  final emb2 = embedder.embedText(text2);
  final emb3 = embedder.embedText(text3);
  final emb4 = embedder.embedText(text4);

  print('\nText 1: "$text1"');
  print('Text 2: "$text2"');
  final sim12 = emb1.cosineSimilarity(emb2);
  print('Similarity 1-2: ${sim12.toStringAsFixed(4)} (highly related)\n');

  print('Text 1: "$text1"');
  print('Text 3: "$text3"');
  final sim13 = emb1.cosineSimilarity(emb3);
  print('Similarity 1-3: ${sim13.toStringAsFixed(4)} (related)\n');

  print('Text 1: "$text1"');
  print('Text 4: "$text4"');
  final sim14 = emb1.cosineSimilarity(emb4);
  print('Similarity 1-4: ${sim14.toStringAsFixed(4)} (unrelated)\n');

  // ============================================================================
  // Example 5: Finding Most Similar Text
  // ============================================================================
  print('--- Example 5: Finding Most Similar Text ---');

  final query = 'Programming languages';
  final candidates = [
    'Python is a popular programming language',
    'The weather is nice today',
    'Rust is a systems programming language',
    'I like to eat pizza',
    'JavaScript runs in web browsers',
  ];

  print('Query: "$query"');
  print('Finding most similar from ${candidates.length} candidates...\n');

  final queryEmb = embedder.embedText(query);
  final candidateEmbs = embedder.embedTextsBatch(candidates);

  // Compute similarities
  final similarities =
      candidateEmbs
          .asMap()
          .entries
          .map((e) => MapEntry(e.key, queryEmb.cosineSimilarity(e.value)))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // Sort by similarity desc

  print('Top 3 most similar:');
  for (int i = 0; i < 3; i++) {
    final idx = similarities[i].key;
    final score = similarities[i].value;
    print('  ${i + 1}. [${score.toStringAsFixed(4)}] "${candidates[idx]}"');
  }
  print('');

  // ============================================================================
  // Example 6: Error Handling
  // ============================================================================
  print('--- Example 6: Error Handling ---');

  try {
    print('Attempting to load invalid model...');
    final invalidEmbedder = EmbedAnything.fromPretrainedHf(
      model: EmbeddingModel.bert,
      modelId: 'invalid/model/that/does/not/exist',
    );
    // This should not execute
    invalidEmbedder.dispose();
  } on EmbedAnythingError catch (e) {
    print('Caught expected error: ${e.runtimeType}');
    print('Message: ${e.message}');

    // Pattern match on error types for specific handling
    switch (e) {
      case ModelNotFoundError():
        print('Action: Check model ID on HuggingFace Hub');
      case InvalidConfigError():
        print('Action: Review configuration parameters');
      case EmbeddingFailedError():
        print('Action: Check input text format');
      case MultiVectorNotSupportedError():
        print('Action: Use a dense single-vector model');
      case FFIError():
        print('Action: Check native library installation');
      case FileNotFoundError():
        print('Action: Verify file/directory path exists');
      case UnsupportedFileFormatError():
        print('Action: Use supported formats (.txt, .md, .pdf, etc.)');
      case FileReadError():
        print('Action: Check file permissions and accessibility');
    }
    print('');
  }

  // ============================================================================
  // Example 7: Using Multiple Models
  // ============================================================================
  print('--- Example 7: Comparing Different Models ---');

  final testText = 'Natural language processing';

  // BERT embedding
  final bertEmb = embedder.embedText(testText);
  print('BERT all-MiniLM-L6-v2:');
  print('  Dimension: ${bertEmb.dimension}');
  print('  First 5: ${bertEmb.values.take(5).toList()}\n');

  // Jina embedding
  final jinaEmb = jinaEmbedder.embedText(testText);
  print('Jina v2-small-en (F16):');
  print('  Dimension: ${jinaEmb.dimension}');
  print('  First 5: ${jinaEmb.values.take(5).toList()}\n');

  // ============================================================================
  // Example 8: Memory Management Best Practices
  // ============================================================================
  print('--- Example 8: Memory Management ---');

  print('Demonstrating manual cleanup (recommended for long-running apps)...');

  // Bad: Creating many embedders without cleanup
  // for (var i = 0; i < 100; i++) {
  //   final e = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  //   e.embedText('test');
  //   // No dispose - memory leak!
  // }

  // Good: Reuse embedder and dispose properly
  final tempEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  try {
    for (var i = 0; i < 5; i++) {
      tempEmbedder.embedText('Test $i');
    }
    print('Processed 5 texts with single embedder instance');
  } finally {
    tempEmbedder.dispose();
    print('Embedder disposed manually\n');
  }

  // Alternative: Automatic cleanup via finalizer (for short-lived usage)
  void processWithAutoCleanup() {
    final autoEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
    autoEmbedder.embedText('test');
    // No dispose needed - finalizer will clean up when GC runs
  }

  processWithAutoCleanup();
  print('Processed text with automatic cleanup (finalizer)');
  print(
    'Note: Manual dispose() is still recommended for deterministic cleanup\n',
  );

  // ============================================================================
  // Example 9: File Embedding with Metadata
  // ============================================================================
  print('--- Example 9: File Embedding ---');

  // Create a temporary example file
  final exampleFile = 'example_document.txt';
  final exampleContent = '''
Machine Learning Fundamentals

Machine learning enables computers to learn from data without explicit programming.
It uses algorithms to identify patterns and make predictions.

Key concepts include:
- Supervised learning: Learning from labeled data
- Unsupervised learning: Finding patterns in unlabeled data
- Reinforcement learning: Learning through trial and error

Applications span from recommendation systems to autonomous vehicles.
''';

  try {
    // Write example file
    final file = File(exampleFile);
    file.writeAsStringSync(exampleContent);

    print('Embedding file: $exampleFile');

    // Embed file with automatic chunking
    final fileChunks = await embedder.embedFile(
      exampleFile,
      chunkSize: 200,      // Split into ~200 character chunks
      overlapRatio: 0.1,   // 10% overlap between chunks
      batchSize: 32,
    );

    print('Generated ${fileChunks.length} chunks with metadata:\n');

    for (var i = 0; i < fileChunks.length; i++) {
      final chunk = fileChunks[i];
      print('Chunk $i:');
      print('  File: ${chunk.filePath ?? "N/A"}');
      print('  Index: ${chunk.chunkIndex ?? "N/A"}');
      print('  Text length: ${chunk.text?.length ?? 0} chars');
      print('  Embedding dimension: ${chunk.embedding.dimension}');
      print('  Preview: ${chunk.text?.substring(0, 50).replaceAll('\n', ' ')}...');
      print('');
    }

    // Demonstrate semantic search across chunks
    print('Searching for "supervised learning" across chunks...');
    final queryEmb = embedder.embedText('supervised learning');

    final rankedChunks = fileChunks
        .asMap()
        .entries
        .map((e) => MapEntry(
              e.key,
              queryEmb.cosineSimilarity(e.value.embedding),
            ))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    print('Most relevant chunk: #${rankedChunks[0].key}');
    print(
      'Similarity: ${rankedChunks[0].value.toStringAsFixed(4)}\n',
    );

  } catch (e) {
    print('Error: $e\n');
  } finally {
    // Clean up example file
    try {
      final file = File(exampleFile);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  // ============================================================================
  // Example 10: Directory Embedding with Filtering
  // ============================================================================
  print('--- Example 10: Directory Embedding ---');

  // Create temporary directory with example files
  final exampleDir = 'example_docs';

  try {
    // Create directory structure
    final dir = Directory(exampleDir);
    if (!dir.existsSync()) {
      dir.createSync();
    }

    // Create different file types
    File('$exampleDir/doc1.txt').writeAsStringSync(
      'Introduction to Neural Networks\n\nNeural networks are computing systems inspired by biological brains.',
    );

    File('$exampleDir/doc2.md').writeAsStringSync(
      '# Deep Learning\n\nDeep learning uses multi-layer neural networks for complex pattern recognition.',
    );

    File('$exampleDir/doc3.txt').writeAsStringSync(
      'Transformers Architecture\n\nThe transformer model revolutionized NLP with attention mechanisms.',
    );

    File('$exampleDir/readme.md').writeAsStringSync(
      '# Project Documentation\n\nThis directory contains ML documentation.',
    );

    print('Embedding all files in directory: $exampleDir');

    // Option 1: Embed all supported files
    final allChunks = <ChunkEmbedding>[];
    await for (final chunk in embedder.embedDirectory(
      exampleDir,
      chunkSize: 300,
      batchSize: 32,
    )) {
      allChunks.add(chunk);
    }

    print('Embedded ${allChunks.length} chunks from all files\n');

    // Option 2: Filter by extension (.txt files only)
    print('Embedding only .txt files...');
    final txtChunks = <ChunkEmbedding>[];
    await for (final chunk in embedder.embedDirectory(
      exampleDir,
      extensions: ['.txt'],
      chunkSize: 300,
    )) {
      txtChunks.add(chunk);
    }

    print('Embedded ${txtChunks.length} chunks from .txt files');

    // Show file distribution
    final fileGroups = <String, int>{};
    for (var chunk in txtChunks) {
      final fileName = chunk.filePath?.split('/').last ?? 'unknown';
      fileGroups[fileName] = (fileGroups[fileName] ?? 0) + 1;
    }

    print('Distribution:');
    fileGroups.forEach((file, count) {
      print('  $file: $count chunks');
    });
    print('');

    // Demonstrate cross-file semantic search
    print('Searching for "attention mechanism" across all files...');
    final searchQuery = embedder.embedText('attention mechanism');

    final results = allChunks
        .asMap()
        .entries
        .map((e) => (
              chunk: e.value,
              similarity: searchQuery.cosineSimilarity(e.value.embedding),
            ))
        .toList()
      ..sort((a, b) => b.similarity.compareTo(a.similarity));

    print('Top 3 results:');
    for (var i = 0; i < 3 && i < results.length; i++) {
      final result = results[i];
      final fileName = result.chunk.filePath?.split('/').last ?? 'unknown';
      print(
        '  ${i + 1}. $fileName (similarity: ${result.similarity.toStringAsFixed(4)})',
      );
      print('     "${result.chunk.text?.substring(0, 60).replaceAll('\n', ' ')}..."');
    }
    print('');

  } catch (e) {
    print('Error: $e\n');
  } finally {
    // Clean up example directory
    try {
      final dir = Directory(exampleDir);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (_) {}
  }

  // ============================================================================
  // Example 11: File Error Handling
  // ============================================================================
  print('--- Example 11: File-Specific Error Handling ---');

  // File not found
  try {
    print('Attempting to embed non-existent file...');
    await embedder.embedFile('non_existent_file.txt');
  } on FileNotFoundError catch (e) {
    print('Caught FileNotFoundError: ${e.message}');
    print('Path: ${e.path}\n');
  }

  // Unsupported format
  try {
    print('Attempting to embed unsupported file format...');
    final tempFile = File('test.xyz')
      ..writeAsStringSync('test content');

    try {
      await embedder.embedFile('test.xyz');
    } finally {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    }
  } on UnsupportedFileFormatError catch (e) {
    print('Caught UnsupportedFileFormatError: ${e.message}');
    print('Extension: ${e.extension}\n');
  }

  // Directory not found
  try {
    print('Attempting to embed non-existent directory...');
    await embedder.embedDirectory('non_existent_dir').first;
  } on FileNotFoundError catch (e) {
    print('Caught FileNotFoundError for directory: ${e.message}\n');
  }

  // ============================================================================
  // Cleanup
  // ============================================================================
  print('--- Cleanup ---');
  print('Disposing embedders...');
  embedder.dispose();
  jinaEmbedder.dispose();

  print('\n=== Example Complete ===');
  print('');
  print('Key Takeaways:');
  print('  - Use ModelConfig for flexible model loading');
  print('  - Batch processing is 5-10x faster for multiple texts');
  print('  - Cosine similarity measures semantic similarity (0-1 range)');
  print('  - Use try-catch with EmbedAnythingError for robust error handling');
  print('  - File/directory embedding supports automatic chunking and metadata');
  print('  - Stream-based directory embedding for memory-efficient processing');
  print('  - Filter files by extension when embedding directories');
  print('  - ChunkEmbedding provides filePath, chunkIndex, and other metadata');
  print('  - Dispose embedders manually for predictable resource management');
  print('  - Reuse embedders instead of creating many instances');
}
