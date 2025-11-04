import 'embedding_result.dart';

/// Result of embedding a text chunk from a file
///
/// Contains the embedding vector, the original text chunk,
/// and metadata about the source (file path, page, chunk index).
///
/// This is returned by [EmbedAnything.embedFile] and [EmbedAnything.embedDirectory]
/// when embedding document files.
///
/// Example:
/// ```dart
/// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
/// try {
///   final chunks = await embedder.embedFile('document.pdf');
///
///   for (final chunk in chunks) {
///     print('File: ${chunk.filePath}');
///     print('Page: ${chunk.page}');
///     print('Text: ${chunk.text?.substring(0, 50)}...');
///     print('Embedding dimension: ${chunk.embedding.dimension}');
///   }
/// } finally {
///   embedder.dispose();
/// }
/// ```
class ChunkEmbedding {
  /// The embedding vector for this chunk
  final EmbeddingResult embedding;

  /// The text content of this chunk (may be null)
  final String? text;

  /// Metadata dictionary with file path, chunk index, page number, etc.
  ///
  /// Common metadata keys:
  /// - `file_path`: Path to the source file
  /// - `page_number`: Page number (for PDFs)
  /// - `chunk_index`: Index of this chunk within the document
  /// - `heading`: Section heading (for structured documents)
  final Map<String, String>? metadata;

  /// Create a new chunk embedding
  ///
  /// Parameters:
  /// - [embedding]: The embedding vector (required)
  /// - [text]: The text content of this chunk (optional)
  /// - [metadata]: Metadata about the chunk (optional)
  const ChunkEmbedding({
    required this.embedding,
    this.text,
    this.metadata,
  });

  /// Convenience getter for file path from metadata
  ///
  /// Returns the value of the `file_path` key in metadata,
  /// or null if metadata is null or the key doesn't exist.
  ///
  /// Example:
  /// ```dart
  /// final chunk = chunks.first;
  /// print('Source: ${chunk.filePath ?? "unknown"}');
  /// ```
  String? get filePath => metadata?['file_path'];

  /// Convenience getter for page number from metadata (PDFs)
  ///
  /// Returns the integer value of the `page_number` key in metadata,
  /// or null if metadata is null, the key doesn't exist, or the value
  /// cannot be parsed as an integer.
  ///
  /// Example:
  /// ```dart
  /// final chunk = chunks.first;
  /// if (chunk.page != null) {
  ///   print('Found on page ${chunk.page}');
  /// }
  /// ```
  int? get page {
    final pageStr = metadata?['page_number'];
    return pageStr != null ? int.tryParse(pageStr) : null;
  }

  /// Convenience getter for chunk index from metadata
  ///
  /// Returns the integer value of the `chunk_index` key in metadata,
  /// or null if metadata is null, the key doesn't exist, or the value
  /// cannot be parsed as an integer.
  ///
  /// Example:
  /// ```dart
  /// final chunk = chunks.first;
  /// print('Chunk #${chunk.chunkIndex ?? 0}');
  /// ```
  int? get chunkIndex {
    final idxStr = metadata?['chunk_index'];
    return idxStr != null ? int.tryParse(idxStr) : null;
  }

  /// Compute cosine similarity with another chunk's embedding
  ///
  /// This is a convenience method that delegates to
  /// [EmbeddingResult.cosineSimilarity]. It compares the embedding
  /// vectors of two chunks to measure their semantic similarity.
  ///
  /// Returns a value between -1 and 1, where higher values indicate
  /// greater semantic similarity.
  ///
  /// Example:
  /// ```dart
  /// final chunks = await embedder.embedFile('document.pdf');
  /// final query = chunks.first;
  ///
  /// // Find most similar chunk
  /// double maxSim = -1;
  /// ChunkEmbedding? mostSimilar;
  ///
  /// for (final chunk in chunks.skip(1)) {
  ///   final sim = query.cosineSimilarity(chunk);
  ///   if (sim > maxSim) {
  ///     maxSim = sim;
  ///     mostSimilar = chunk;
  ///   }
  /// }
  ///
  /// print('Most similar chunk has similarity: $maxSim');
  /// ```
  double cosineSimilarity(ChunkEmbedding other) {
    return embedding.cosineSimilarity(other.embedding);
  }

  /// String representation for debugging
  ///
  /// Shows a preview of the text, embedding dimension, and metadata.
  @override
  String toString() {
    final textPreview = text != null && text!.length > 50
        ? '${text!.substring(0, 50)}...'
        : text ?? 'null';

    return 'ChunkEmbedding('
        'text: "$textPreview", '
        'embedding: ${embedding.dimension}D, '
        'metadata: $metadata'
        ')';
  }
}
