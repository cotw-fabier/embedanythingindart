import 'dart:ffi';

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
