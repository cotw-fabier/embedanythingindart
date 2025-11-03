/// Supported embedding model architectures.
///
/// Different model types use different underlying architectures and
/// tokenization strategies. Choose based on your use case:
/// - [bert]: General-purpose, fast, good quality
/// - [jina]: Optimized for semantic search, higher quality
///
/// Example:
/// ```dart
/// final embedder = EmbedAnything.fromPretrainedHf(
///   model: EmbeddingModel.bert,
///   modelId: 'sentence-transformers/all-MiniLM-L6-v2',
/// );
/// ```
enum EmbeddingModel {
  /// BERT-based models.
  ///
  /// BERT (Bidirectional Encoder Representations from Transformers)
  /// models are general-purpose sentence embedding models that work
  /// well for most semantic similarity tasks.
  ///
  /// Common BERT models:
  /// - `sentence-transformers/all-MiniLM-L6-v2` (384 dim, fast)
  /// - `sentence-transformers/all-MiniLM-L12-v2` (384 dim, better quality)
  ///
  /// Best for:
  /// - General semantic similarity
  /// - Fast inference requirements
  /// - Moderate quality requirements
  ///
  /// Performance:
  /// - Model load (warm cache): ~100ms
  /// - Single embedding latency (short text): ~5-10ms
  bert(0),

  /// Jina embedding models.
  ///
  /// Jina models are specifically optimized for semantic search
  /// and retrieval tasks, offering higher quality at the cost of
  /// slightly slower inference.
  ///
  /// Common Jina models:
  /// - `jinaai/jina-embeddings-v2-small-en` (512 dim, fast)
  /// - `jinaai/jina-embeddings-v2-base-en` (768 dim, high quality)
  ///
  /// Best for:
  /// - Semantic search applications
  /// - High-quality similarity matching
  /// - Document retrieval systems
  ///
  /// Performance:
  /// - Model load (warm cache): ~150ms
  /// - Single embedding latency (short text): ~10-15ms
  jina(1);

  const EmbeddingModel(this.value);

  /// Numeric value passed to Rust FFI.
  ///
  /// This internal value is used for communication with the native
  /// Rust layer and should not be used directly by applications.
  final int value;
}

/// Model data type for weights.
///
/// Determines the precision of model weights during inference.
/// Lower precision types (F16) provide faster inference and lower
/// memory usage at the cost of slightly reduced quality.
///
/// Example:
/// ```dart
/// // Use F16 for faster inference on resource-constrained systems
/// final config = ModelConfig(
///   modelId: 'sentence-transformers/all-MiniLM-L6-v2',
///   modelType: EmbeddingModel.bert,
///   dtype: ModelDtype.f16,
/// );
/// final embedder = EmbedAnything.fromConfig(config);
/// ```
///
/// Performance comparison (BERT all-MiniLM-L6-v2):
/// - F32: 100% quality, ~90MB memory, baseline speed
/// - F16: 99% quality, ~45MB memory, ~1.3x faster
///
/// See also:
/// - [ModelConfig] for configuring models
enum ModelDtype {
  /// 32-bit floating point (full precision).
  ///
  /// This is the default and recommended option for most use cases.
  /// Provides the highest quality embeddings at the cost of larger
  /// memory footprint and slightly slower inference.
  ///
  /// Memory usage (typical models):
  /// - BERT all-MiniLM-L6-v2: ~90MB
  /// - Jina v2-base-en: ~280MB
  ///
  /// Use when:
  /// - Quality is the top priority
  /// - Memory is not a constraint
  /// - Reproducibility across platforms is important
  f32(0),

  /// 16-bit floating point (half precision).
  ///
  /// Reduces memory usage by approximately 50% and can provide
  /// faster inference on supported hardware. The quality difference
  /// is typically negligible for most applications.
  ///
  /// Memory usage (typical models):
  /// - BERT all-MiniLM-L6-v2: ~45MB
  /// - Jina v2-base-en: ~140MB
  ///
  /// Use when:
  /// - Running on resource-constrained devices
  /// - Memory usage is a concern
  /// - Speed is more important than maximum quality
  ///
  /// Note: Not all platforms support F16 acceleration. On unsupported
  /// platforms, the model may fall back to F32 internally.
  f16(1);

  const ModelDtype(this.value);

  /// Numeric value passed to Rust FFI.
  ///
  /// Mapping:
  /// - 0 = F32 (full precision)
  /// - 1 = F16 (half precision)
  /// - -1 = default/None (handled in Rust)
  ///
  /// This internal value is used for communication with the native
  /// Rust layer and should not be used directly by applications.
  final int value;
}
