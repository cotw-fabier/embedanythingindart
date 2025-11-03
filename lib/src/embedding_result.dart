/// Result of an embedding operation.
///
/// Contains the dense vector embedding as a list of doubles representing
/// the semantic meaning of the input text. These vectors can be compared
/// using cosine similarity to measure semantic similarity between texts.
///
/// The vectors are typically normalized to unit length, making them
/// suitable for direct cosine similarity comparisons.
///
/// Example:
/// ```dart
/// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
/// final result = embedder.embedText('Hello, world!');
///
/// print('Dimension: ${result.dimension}');
/// print('First 5 values: ${result.values.take(5)}');
/// ```
///
/// See also:
/// - [EmbedAnything.embedText] for generating single embeddings
/// - [EmbedAnything.embedTextsBatch] for batch processing
class EmbeddingResult {
  /// The embedding vector as a list of doubles.
  ///
  /// The length of this list equals the embedding dimension,
  /// which depends on the model used:
  /// - BERT all-MiniLM-L6-v2: 384 dimensions
  /// - BERT all-MiniLM-L12-v2: 384 dimensions
  /// - Jina v2-small-en: 512 dimensions
  /// - Jina v2-base-en: 768 dimensions
  final List<double> values;

  /// Creates an embedding result from a vector.
  ///
  /// The [values] list should not be empty and typically contains
  /// normalized floating-point numbers.
  const EmbeddingResult(this.values);

  /// The dimensionality of the embedding.
  ///
  /// This is the length of the [values] vector and depends on
  /// the model architecture used to generate the embedding.
  int get dimension => values.length;

  /// Compute cosine similarity with another embedding.
  ///
  /// Returns a value between -1 and 1, where:
  /// - **1.0** means the embeddings are identical (maximum similarity)
  /// - **0.0** means the embeddings are orthogonal (no similarity)
  /// - **-1.0** means the embeddings are opposite (maximum dissimilarity)
  ///
  /// In practice, similarity scores for natural language are typically
  /// in the range [0.0, 1.0], with higher values indicating greater
  /// semantic similarity.
  ///
  /// Throws [ArgumentError] if the embeddings have different dimensions.
  ///
  /// Example:
  /// ```dart
  /// final emb1 = embedder.embedText('I love machine learning');
  /// final emb2 = embedder.embedText('Machine learning is great');
  /// final emb3 = embedder.embedText('I enjoy cooking pasta');
  ///
  /// final sim12 = emb1.cosineSimilarity(emb2);
  /// final sim13 = emb1.cosineSimilarity(emb3);
  ///
  /// print('Related texts similarity: ${sim12.toStringAsFixed(4)}');
  /// // Output: Related texts similarity: 0.8742
  ///
  /// print('Unrelated texts similarity: ${sim13.toStringAsFixed(4)}');
  /// // Output: Unrelated texts similarity: 0.2156
  /// ```
  ///
  /// Performance note:
  /// This operation is O(n) where n is the dimension. For typical
  /// embedding dimensions (384-768), this completes in microseconds.
  ///
  /// See also:
  /// - [dimension] for the embedding vector length
  double cosineSimilarity(EmbeddingResult other) {
    if (dimension != other.dimension) {
      throw ArgumentError(
        'Cannot compute similarity between embeddings of different dimensions '
        '($dimension vs ${other.dimension})',
      );
    }

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < dimension; i++) {
      dotProduct += values[i] * other.values[i];
      normA += values[i] * values[i];
      normB += other.values[i] * other.values[i];
    }

    final magnitude = (normA * normB);
    if (magnitude == 0.0) return 0.0;

    return dotProduct / magnitude.abs();
  }

  @override
  String toString() => 'EmbeddingResult(dimension: $dimension, '
      'preview: [${values.take(5).join(", ")}...])';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! EmbeddingResult) return false;
    if (dimension != other.dimension) return false;

    for (int i = 0; i < dimension; i++) {
      if ((values[i] - other.values[i]).abs() > 1e-6) return false;
    }

    return true;
  }

  @override
  int get hashCode => values.fold(0, (hash, v) => hash ^ v.hashCode);
}
