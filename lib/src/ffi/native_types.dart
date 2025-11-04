import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Opaque pointer to Rust Embedder
///
/// This type represents a handle to the native EmbedAnything embedder.
/// It cannot be directly accessed from Dart.
final class CEmbedder extends Opaque {}

/// C representation of a text embedding
///
/// Contains a pointer to the f32 array and its length.
final class CTextEmbedding extends Struct {
  external Pointer<Float> values;

  @Size()
  external int len;
}

/// C representation of a batch of text embeddings
///
/// Contains a pointer to an array of CTextEmbedding and the count.
final class CTextEmbeddingBatch extends Struct {
  external Pointer<CTextEmbedding> embeddings;

  @Size()
  external int count;
}

/// C representation of text embedding configuration
///
/// Configuration for chunking and embedding text from files.
/// Memory layout must match Rust CTextEmbedConfig struct.
final class CTextEmbedConfig extends Struct {
  /// Maximum characters per chunk
  @Size()
  external int chunkSize;

  /// Overlap between chunks (0.0-1.0)
  @Float()
  external double overlapRatio;

  /// Batch size for embedding generation
  @Size()
  external int batchSize;

  /// Buffer size for streaming operations
  @Size()
  external int bufferSize;
}

/// C representation of embedded chunk data
///
/// Contains the embedding vector, text content, and JSON metadata.
/// Memory layout must match Rust CEmbedData struct.
final class CEmbedData extends Struct {
  /// Pointer to the embedding values array (f32)
  external Pointer<Float> embeddingValues;

  /// Length of the embedding vector
  @Size()
  external int embeddingLen;

  /// Text content of this chunk (NULL if none)
  external Pointer<Utf8> text;

  /// Metadata as JSON string (NULL if none)
  external Pointer<Utf8> metadataJson;
}

/// C representation of a batch of embedded data
///
/// Contains an array of CEmbedData items.
/// Memory layout must match Rust CEmbedDataBatch struct.
final class CEmbedDataBatch extends Struct {
  /// Pointer to array of CEmbedData items
  external Pointer<CEmbedData> items;

  /// Number of items in the array
  @Size()
  external int count;
}
