import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'embedding_result.dart';
import 'ffi/bindings.dart' as ffi;
import 'ffi/finalizers.dart';
import 'ffi/ffi_utils.dart';
import 'ffi/native_types.dart';
import 'model_config.dart';
import 'models.dart';

/// High-level interface to EmbedAnything embedding models
///
/// This class provides a convenient Dart API for generating embeddings
/// using various models from HuggingFace Hub. It handles FFI calls,
/// memory management, and error handling automatically.
///
/// **IMPORTANT:** You MUST call [dispose] when done using an embedder
/// to prevent memory leaks. Automatic cleanup via finalizers is not
/// currently available due to limitations with the @Native API.
///
/// Example usage:
/// ```dart
/// // Load a model using a predefined configuration
/// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
///
/// try {
///   // Generate embeddings
///   final result = embedder.embedText('Hello, world!');
///   print('Embedding dimension: ${result.dimension}');
///
///   // Batch processing
///   final batch = embedder.embedTextsBatch(['Text 1', 'Text 2', 'Text 3']);
/// } finally {
///   // ALWAYS dispose to prevent memory leaks
///   embedder.dispose();
/// }
/// ```
class EmbedAnything {
  final Pointer<CEmbedder> _handle;
  bool _disposed = false;
  final ModelConfig? _config;

  /// Private constructor - use factory methods to create instances
  EmbedAnything._(this._handle, [this._config]);

  /// Create an embedder from a model configuration
  ///
  /// This is the recommended way to create an embedder, as it provides
  /// full control over model loading parameters including data type,
  /// normalization, and batch size.
  ///
  /// Parameters:
  /// - [config]: Model configuration object
  ///
  /// Throws:
  /// - [InvalidConfigError] if configuration is invalid
  /// - [ModelNotFoundError] if model doesn't exist on HuggingFace Hub
  /// - [FFIError] if model loading fails
  ///
  /// Example:
  /// ```dart
  /// // Use predefined configuration
  /// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  ///
  /// // Or create custom configuration
  /// final config = ModelConfig(
  ///   modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  ///   modelType: EmbeddingModel.bert,
  ///   dtype: ModelDtype.f16,
  ///   defaultBatchSize: 64,
  /// );
  /// final embedder = EmbedAnything.fromConfig(config);
  /// ```
  factory EmbedAnything.fromConfig(ModelConfig config) {
    // Validate configuration before attempting to load model
    config.validate();

    // Initialize runtime on first use
    _initializeRuntime();

    final handle = withCString(config.modelId, (modelIdPtr) {
      return withCString(config.revision, (revisionPtr) {
        return ffi.embedderFromPretrainedHf(
          config.modelType.value,
          modelIdPtr,
          revisionPtr,
          config.dtype.value,
        );
      });
    });

    if (handle == nullptr) {
      throwLastError('Failed to load model: ${config.modelId}');
    }

    return EmbedAnything._(handle, config);
  }

  /// Create an embedder from a pretrained HuggingFace model
  ///
  /// This is a convenience method that creates a ModelConfig internally
  /// and calls [fromConfig]. For more control over model loading,
  /// use [fromConfig] directly with a custom [ModelConfig].
  ///
  /// Parameters:
  /// - [model]: The model architecture (BERT or Jina)
  /// - [modelId]: HuggingFace model identifier
  ///   (e.g., 'sentence-transformers/all-MiniLM-L6-v2')
  /// - [revision]: Git revision/branch (defaults to 'main')
  ///
  /// Throws:
  /// - [ModelNotFoundError] if model doesn't exist on HuggingFace Hub
  /// - [FFIError] if model loading fails
  ///
  /// Common models:
  /// - BERT: 'sentence-transformers/all-MiniLM-L6-v2' (384 dim)
  /// - BERT: 'sentence-transformers/all-MiniLM-L12-v2' (384 dim)
  /// - Jina: 'jinaai/jina-embeddings-v2-small-en' (512 dim)
  /// - Jina: 'jinaai/jina-embeddings-v2-base-en' (768 dim)
  ///
  /// Example:
  /// ```dart
  /// final embedder = EmbedAnything.fromPretrainedHf(
  ///   model: EmbeddingModel.bert,
  ///   modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  /// );
  /// ```
  factory EmbedAnything.fromPretrainedHf({
    required EmbeddingModel model,
    required String modelId,
    String revision = 'main',
  }) {
    // Create a ModelConfig and use fromConfig
    // This ensures all configuration logic is centralized
    final config = ModelConfig(
      modelId: modelId,
      modelType: model,
      revision: revision,
    );

    return EmbedAnything.fromConfig(config);
  }

  /// Generate embedding for a single text
  ///
  /// Converts the input text into a dense vector representation
  /// that captures its semantic meaning. The resulting vector
  /// can be compared with other embeddings using cosine similarity.
  ///
  /// Parameters:
  /// - [text]: The text to embed
  ///
  /// Returns an [EmbeddingResult] containing the dense vector.
  ///
  /// Throws:
  /// - [EmbeddingFailedError] if embedding generation fails
  /// - [StateError] if the embedder has been disposed
  ///
  /// Example:
  /// ```dart
  /// final result = embedder.embedText('Hello, world!');
  /// print('Dimension: ${result.dimension}');
  /// print('First 5 values: ${result.values.take(5)}');
  /// ```
  EmbeddingResult embedText(String text) {
    _checkDisposed();

    final embeddingPtr = withCString(text, (textPtr) {
      return ffi.embedText(_handle, textPtr);
    });

    if (embeddingPtr == nullptr) {
      throwLastError('Failed to generate embedding');
    }

    try {
      final embedding = embeddingPtr.ref;
      final values = _copyFloatArray(embedding.values, embedding.len);
      return EmbeddingResult(values);
    } finally {
      ffi.freeEmbedding(embeddingPtr);
    }
  }

  /// Generate embeddings for multiple texts in a batch
  ///
  /// This is significantly more efficient than calling [embedText] multiple
  /// times, as it processes texts in parallel on the Rust side and reduces
  /// FFI overhead. Use this for better performance when embedding multiple texts.
  ///
  /// Parameters:
  /// - [texts]: List of texts to embed
  ///
  /// Returns a list of [EmbeddingResult]s, one for each input text
  /// in the same order as the input.
  ///
  /// Throws:
  /// - [EmbeddingFailedError] if embedding generation fails
  /// - [StateError] if the embedder has been disposed
  ///
  /// Example:
  /// ```dart
  /// final texts = ['First text', 'Second text', 'Third text'];
  /// final results = embedder.embedTextsBatch(texts);
  ///
  /// for (var i = 0; i < texts.length; i++) {
  ///   print('Text: ${texts[i]}');
  ///   print('Dimension: ${results[i].dimension}');
  /// }
  /// ```
  ///
  /// Performance note:
  /// Batch processing is typically 5-10x faster than sequential
  /// single embeddings for batches of 50+ items.
  List<EmbeddingResult> embedTextsBatch(List<String> texts) {
    _checkDisposed();

    if (texts.isEmpty) {
      return [];
    }

    // Convert Dart strings to C strings
    final cStrings = texts.map((t) => stringToCString(t)).toList();
    final cStringsArray = malloc<Pointer<Utf8>>(texts.length);

    try {
      // Fill the array
      for (int i = 0; i < texts.length; i++) {
        cStringsArray[i] = cStrings[i];
      }

      // Call FFI function
      final batchPtr = ffi.embedTextsBatch(_handle, cStringsArray, texts.length);

      if (batchPtr == nullptr) {
        throwLastError('Failed to generate embeddings batch');
      }

      try {
        final batch = batchPtr.ref;
        final results = <EmbeddingResult>[];

        for (int i = 0; i < batch.count; i++) {
          final embedding = batch.embeddings[i];
          final values = _copyFloatArray(embedding.values, embedding.len);
          results.add(EmbeddingResult(values));
        }

        return results;
      } finally {
        ffi.freeEmbeddingBatch(batchPtr);
      }
    } finally {
      // Free all C strings
      for (final cStr in cStrings) {
        freeCString(cStr);
      }
      malloc.free(cStringsArray);
    }
  }

  /// Manually dispose of the embedder
  ///
  /// Releases native resources immediately. After calling this,
  /// the embedder cannot be used and any method calls will throw
  /// a [StateError].
  ///
  /// **IMPORTANT:** You MUST call this method to prevent memory leaks.
  /// Automatic cleanup is not currently available due to limitations
  /// with the @Native FFI API.
  ///
  /// This method is idempotent - calling it multiple times is safe
  /// and will not cause errors.
  ///
  /// Example:
  /// ```dart
  /// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  /// try {
  ///   final result = embedder.embedText('test');
  ///   // Use result...
  /// } finally {
  ///   embedder.dispose(); // Ensure cleanup
  /// }
  /// ```
  void dispose() {
    if (!_disposed) {
      ffi.embedderFree(_handle);
      _disposed = true;
    }
  }

  /// Get the configuration used to create this embedder
  ///
  /// Returns null if the embedder was created before ModelConfig
  /// support was added (legacy API).
  ModelConfig? get config => _config;

  /// Check if the embedder has been disposed
  void _checkDisposed() {
    if (_disposed) {
      throw StateError('EmbedAnything instance has been disposed');
    }
  }

  /// Copy a float array from native memory to Dart `List<double>`
  static List<double> _copyFloatArray(Pointer<Float> ptr, int length) {
    final list = <double>[];
    for (int i = 0; i < length; i++) {
      list.add(ptr[i]);
    }
    return list;
  }

  /// Initialize the Tokio runtime (once)
  static bool _runtimeInitialized = false;

  static void _initializeRuntime() {
    if (!_runtimeInitialized) {
      final result = ffi.initRuntime();
      if (result != 0) {
        throwLastError('Failed to initialize async runtime');
      }
      _runtimeInitialized = true;
    }
  }
}
