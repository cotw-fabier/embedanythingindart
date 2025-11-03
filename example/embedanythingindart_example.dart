import 'package:embedanythingindart/embedanythingindart.dart';

void main() {
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

  print('Generating embeddings for ${texts.length} texts using batch processing...');
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
  final similarities = candidateEmbs
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
  print('Note: Manual dispose() is still recommended for deterministic cleanup\n');

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
  print('  - Dispose embedders manually for predictable resource management');
  print('  - Reuse embedders instead of creating many instances');
}
