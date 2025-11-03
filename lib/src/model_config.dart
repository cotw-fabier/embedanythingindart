import 'errors.dart';
import 'models.dart';

/// Configuration for loading embedding models from HuggingFace Hub
///
/// This class provides a flexible way to configure model loading with
/// sensible defaults while allowing customization for advanced use cases.
///
/// Example:
/// ```dart
/// // Use predefined configuration
/// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
///
/// // Create custom configuration
/// final config = ModelConfig(
///   modelId: 'custom/model',
///   modelType: EmbeddingModel.bert,
///   revision: 'v1.0',
///   dtype: ModelDtype.f16,
///   defaultBatchSize: 64,
/// );
/// final embedder = EmbedAnything.fromConfig(config);
/// ```
class ModelConfig {
  /// HuggingFace model identifier (e.g., 'sentence-transformers/all-MiniLM-L6-v2')
  ///
  /// This should be a valid model path on HuggingFace Hub.
  /// The model will be downloaded and cached on first use.
  final String modelId;

  /// Model architecture type (BERT or Jina)
  ///
  /// This determines which embedding model architecture to use.
  final EmbeddingModel modelType;

  /// Git revision (branch, tag, or commit hash)
  ///
  /// Defaults to 'main'. Can be used to pin to a specific model version.
  ///
  /// Examples:
  /// - 'main' (default branch)
  /// - 'v1.0' (tag)
  /// - 'abc123' (commit hash)
  final String revision;

  /// Data type for model weights
  ///
  /// Defaults to F32 (full precision).
  /// Use F16 for faster inference with slightly reduced quality.
  final ModelDtype dtype;

  /// Whether to normalize embeddings to unit length
  ///
  /// Defaults to true. Normalized embeddings are suitable for
  /// cosine similarity comparisons.
  final bool normalize;

  /// Default batch size for batch operations
  ///
  /// Defaults to 32. Larger batch sizes are more efficient but
  /// require more memory. Adjust based on your hardware and use case.
  final int defaultBatchSize;

  /// Creates a new ModelConfig with required and optional parameters
  ///
  /// Throws [InvalidConfigError] during validation if parameters are invalid.
  const ModelConfig({
    required this.modelId,
    required this.modelType,
    this.revision = 'main',
    this.dtype = ModelDtype.f32,
    this.normalize = true,
    this.defaultBatchSize = 32,
  });

  /// Predefined configuration for BERT all-MiniLM-L6-v2
  ///
  /// This is a lightweight 384-dimensional BERT model suitable for
  /// most general-purpose semantic similarity tasks.
  ///
  /// Model details:
  /// - Dimensions: 384
  /// - Speed: Fast
  /// - Quality: Good
  /// - Use case: General purpose
  factory ModelConfig.bertMiniLML6() => const ModelConfig(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        modelType: EmbeddingModel.bert,
      );

  /// Predefined configuration for BERT all-MiniLM-L12-v2
  ///
  /// This is a slightly larger 384-dimensional BERT model with
  /// 12 layers instead of 6, providing better quality at the cost
  /// of slower inference.
  ///
  /// Model details:
  /// - Dimensions: 384
  /// - Speed: Medium
  /// - Quality: Better
  /// - Use case: When quality is more important than speed
  factory ModelConfig.bertMiniLML12() => const ModelConfig(
        modelId: 'sentence-transformers/all-MiniLM-L12-v2',
        modelType: EmbeddingModel.bert,
      );

  /// Predefined configuration for Jina v2-small-en
  ///
  /// This is a 512-dimensional Jina model optimized for English text.
  ///
  /// Model details:
  /// - Dimensions: 512
  /// - Speed: Fast
  /// - Quality: Good
  /// - Use case: English text embeddings
  factory ModelConfig.jinaV2Small() => const ModelConfig(
        modelId: 'jinaai/jina-embeddings-v2-small-en',
        modelType: EmbeddingModel.jina,
      );

  /// Predefined configuration for Jina v2-base-en
  ///
  /// This is a 768-dimensional Jina model providing high-quality
  /// embeddings for English text.
  ///
  /// Model details:
  /// - Dimensions: 768
  /// - Speed: Medium
  /// - Quality: Excellent
  /// - Use case: High-quality English text embeddings
  factory ModelConfig.jinaV2Base() => const ModelConfig(
        modelId: 'jinaai/jina-embeddings-v2-base-en',
        modelType: EmbeddingModel.jina,
      );

  /// Validates the configuration parameters
  ///
  /// Throws [InvalidConfigError] if:
  /// - modelId is empty
  /// - defaultBatchSize is not positive
  ///
  /// Example:
  /// ```dart
  /// final config = ModelConfig(
  ///   modelId: '',
  ///   modelType: EmbeddingModel.bert,
  /// );
  ///
  /// try {
  ///   config.validate();
  /// } on InvalidConfigError catch (e) {
  ///   print('Invalid config: ${e.field} - ${e.reason}');
  /// }
  /// ```
  void validate() {
    if (modelId.isEmpty) {
      throw InvalidConfigError(
        field: 'modelId',
        reason: 'cannot be empty',
      );
    }

    if (defaultBatchSize <= 0) {
      throw InvalidConfigError(
        field: 'defaultBatchSize',
        reason: 'must be positive',
      );
    }
  }

  @override
  String toString() {
    return 'ModelConfig('
        'modelId: $modelId, '
        'modelType: $modelType, '
        'revision: $revision, '
        'dtype: $dtype, '
        'normalize: $normalize, '
        'defaultBatchSize: $defaultBatchSize'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ModelConfig &&
        other.modelId == modelId &&
        other.modelType == modelType &&
        other.revision == revision &&
        other.dtype == dtype &&
        other.normalize == normalize &&
        other.defaultBatchSize == defaultBatchSize;
  }

  @override
  int get hashCode {
    return Object.hash(
      modelId,
      modelType,
      revision,
      dtype,
      normalize,
      defaultBatchSize,
    );
  }
}
