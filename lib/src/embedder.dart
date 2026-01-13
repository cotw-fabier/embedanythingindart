import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'chunk_embedding.dart';
import 'embedding_result.dart';
import 'errors.dart';
import 'ffi/async_bindings.dart' as async_ffi;
import 'ffi/async_types.dart';
import 'ffi/bindings.dart' as ffi;
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

  /// Embed a single file with automatic chunking
  ///
  /// Processes a document file and returns all text chunks with their embeddings
  /// and metadata. The file is automatically chunked based on the configuration
  /// parameters.
  ///
  /// Supported file formats: PDF, TXT, MD, DOCX, HTML
  ///
  /// Parameters:
  /// - [filePath]: Path to the file to embed
  /// - [chunkSize]: Maximum characters per chunk (default: 1000)
  /// - [overlapRatio]: Overlap between chunks 0.0-1.0 (default: 0.0)
  /// - [batchSize]: Batch size for embedding generation (default: 32)
  ///
  /// Returns a [Future] that completes with a list of [ChunkEmbedding]s,
  /// one for each chunk of the file. Each chunk includes the embedding,
  /// text content, and metadata (file path, chunk index, page number for PDFs).
  ///
  /// Throws:
  /// - [FileNotFoundError] if the file does not exist
  /// - [UnsupportedFileFormatError] if the file format is not supported
  /// - [FileReadError] if there's a permission or I/O error reading the file
  /// - [EmbeddingFailedError] if embedding generation fails
  /// - [StateError] if the embedder has been disposed
  ///
  /// Example:
  /// ```dart
  /// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  /// try {
  ///   final chunks = await embedder.embedFile(
  ///     'document.pdf',
  ///     chunkSize: 500,
  ///     overlapRatio: 0.1,
  ///   );
  ///
  ///   for (final chunk in chunks) {
  ///     print('File: ${chunk.filePath}');
  ///     print('Page: ${chunk.page}');
  ///     print('Chunk ${chunk.chunkIndex}: ${chunk.text?.substring(0, 50)}...');
  ///   }
  /// } finally {
  ///   embedder.dispose();
  /// }
  /// ```
  Future<List<ChunkEmbedding>> embedFile(
    String filePath, {
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  }) async {
    _checkDisposed();

    // Allocate config struct
    final config = allocateTextEmbedConfig(
      chunkSize: chunkSize,
      overlapRatio: overlapRatio,
      batchSize: batchSize,
      bufferSize: 100, // Default buffer size
    );

    // Convert file path to C string
    final filePathPtr = stringToCString(filePath);

    try {
      // Call FFI function
      final batchPtr = ffi.embedFile(_handle, filePathPtr, config);

      if (batchPtr == nullptr) {
        throwLastError('Failed to embed file: $filePath');
      }

      try {
        final batch = batchPtr.ref;
        final results = <ChunkEmbedding>[];

        // Convert each CEmbedData to ChunkEmbedding
        for (int i = 0; i < batch.count; i++) {
          final embedData = batch.items[i];
          results.add(_cEmbedDataToChunkEmbedding(embedData));
        }

        return results;
      } finally {
        ffi.freeEmbedDataBatch(batchPtr);
      }
    } finally {
      // Free allocated memory
      freeCString(filePathPtr);
      calloc.free(config);
    }
  }

  /// Embed all files in a directory (streaming)
  ///
  /// Processes all files in a directory and returns a [Stream] that yields
  /// [ChunkEmbedding]s as they are generated. This allows processing large
  /// directories without loading all embeddings into memory at once.
  ///
  /// Files that fail to process will emit stream errors but won't stop
  /// the processing of other files.
  ///
  /// Supported file formats: PDF, TXT, MD, DOCX, HTML
  ///
  /// Parameters:
  /// - [directoryPath]: Path to the directory to embed
  /// - [extensions]: Optional list of file extensions to include (e.g., ['.pdf', '.txt']).
  ///   If null, all supported file types will be processed.
  /// - [chunkSize]: Maximum characters per chunk (default: 1000)
  /// - [overlapRatio]: Overlap between chunks 0.0-1.0 (default: 0.0)
  /// - [batchSize]: Batch size for embedding generation (default: 32)
  ///
  /// Returns a [Stream] of [ChunkEmbedding]s that yields results incrementally
  /// as files are processed.
  ///
  /// Throws:
  /// - [FileNotFoundError] if the directory does not exist
  /// - [FileReadError] if there's a permission error accessing the directory
  ///
  /// Stream errors:
  /// - Individual file processing errors are emitted to the stream but don't stop processing
  ///
  /// Example:
  /// ```dart
  /// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  /// try {
  ///   await for (final chunk in embedder.embedDirectory(
  ///     'documents/',
  ///     extensions: ['.pdf', '.txt'],
  ///   )) {
  ///     print('Processing ${chunk.filePath}: chunk ${chunk.chunkIndex}');
  ///     // Process chunk immediately without storing all in memory
  ///   }
  /// } finally {
  ///   embedder.dispose();
  /// }
  /// ```
  Stream<ChunkEmbedding> embedDirectory(
    String directoryPath, {
    List<String>? extensions,
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  }) {
    _checkDisposed();

    late StreamController<ChunkEmbedding> controller;
    NativeCallable<ffi.StreamCallbackType>? callback;
    Pointer<CTextEmbedConfig>? config;
    Pointer<Utf8>? directoryPathPtr;
    Pointer<Pointer<Utf8>>? extensionsPtr;

    controller = StreamController<ChunkEmbedding>(
      onListen: () {
        // Allocate config struct
        config = allocateTextEmbedConfig(
          chunkSize: chunkSize,
          overlapRatio: overlapRatio,
          batchSize: batchSize,
          bufferSize: 100,
        );

        // Allocate extensions array if provided
        if (extensions != null && extensions.isNotEmpty) {
          extensionsPtr = allocateStringArray(extensions);
        }

        // Convert directory path to C string
        directoryPathPtr = stringToCString(directoryPath);

        // Use Completer to wait for callback before closing stream
        final callbackCompleter = Completer<void>();

        // Create callback that adds chunks to stream
        callback = NativeCallable<ffi.StreamCallbackType>.listener(
          (Pointer<CEmbedDataBatch> batchPtr, Pointer<Void> context) {
            try {
              print('DEBUG DART: Directory callback fired');
              final batch = batchPtr.ref;
              print('DEBUG DART: Batch count: ${batch.count}');

              // Convert each CEmbedData to ChunkEmbedding and add to stream
              for (int i = 0; i < batch.count; i++) {
                final embedData = batch.items[i];
                final chunk = _cEmbedDataToChunkEmbedding(embedData);
                controller.add(chunk);
                print('DEBUG DART: Added chunk $i to stream');
              }

              // Free the batch memory (CRITICAL for preventing memory leaks)
              ffi.freeEmbedDataBatch(batchPtr);
              print('DEBUG DART: Freed batch memory');
            } catch (e, stackTrace) {
              print('DEBUG DART: Callback error: $e');
              // Add error to stream instead of throwing
              controller.addError(e, stackTrace);
            } finally {
              // Signal that callback has completed
              if (!callbackCompleter.isCompleted) {
                callbackCompleter.complete();
              }
            }
          },
        );

        // Call FFI function
        final result = ffi.embedDirectoryStream(
          _handle,
          directoryPathPtr!,
          extensionsPtr ?? nullptr,
          extensions?.length ?? 0,
          config!,
          callback!.nativeFunction,
          nullptr, // No context needed
        );

        // Check result and handle errors
        if (result != 0) {
          final errorMessage = getLastErrorMessage();
          if (errorMessage != null) {
            controller.addError(
              _parseErrorForDirectory(errorMessage, directoryPath),
            );
          } else {
            controller.addError(
              Exception('Failed to embed directory: $directoryPath'),
            );
          }
          // Complete the completer since callback won't be called on error
          if (!callbackCompleter.isCompleted) {
            callbackCompleter.complete();
          }
        }

        // Wait for callback to complete before closing stream
        callbackCompleter.future.then((_) {
          print('DEBUG DART: Callback completed, closing stream');
          controller.close();
        });
      },
      onCancel: () {
        // Clean up resources when stream is cancelled
        _cleanupDirectoryResources(
          callback,
          config,
          directoryPathPtr,
          extensionsPtr,
          extensions?.length ?? 0,
        );
      },
    );

    return controller.stream;
  }

  /// Helper to parse error for directory operations
  Exception _parseErrorForDirectory(String errorMessage, String directoryPath) {
    // Parse error message using same logic as ffi_utils.dart
    if (errorMessage.startsWith('FILE_NOT_FOUND:')) {
      final path = errorMessage.substring('FILE_NOT_FOUND:'.length).trim();
      return FileNotFoundError(path);
    } else if (errorMessage.startsWith('FILE_READ_ERROR:')) {
      final parts = errorMessage.substring('FILE_READ_ERROR:'.length).trim();
      final colonIndex = parts.indexOf(':', 1);
      if (colonIndex != -1) {
        final path = parts.substring(0, colonIndex).trim();
        final reason = parts.substring(colonIndex + 1).trim();
        return FileReadError(path: path, reason: reason);
      } else {
        return FileReadError(path: parts, reason: 'Unknown error');
      }
    } else if (errorMessage.startsWith('UNSUPPORTED_FORMAT:')) {
      final parts = errorMessage.substring('UNSUPPORTED_FORMAT:'.length).trim();
      final forIndex = parts.indexOf(' for ');
      if (forIndex != -1) {
        final extension = parts.substring(0, forIndex).trim();
        final path = parts.substring(forIndex + 5).trim();
        return UnsupportedFileFormatError(path: path, extension: extension);
      } else {
        return UnsupportedFileFormatError(path: parts, extension: 'unknown');
      }
    } else {
      // Fallback: treat as FFI error
      return FFIError(operation: 'Directory embedding', nativeError: errorMessage);
    }
  }

  /// Helper to clean up directory streaming resources
  void _cleanupDirectoryResources(
    NativeCallable<ffi.StreamCallbackType>? callback,
    Pointer<CTextEmbedConfig>? config,
    Pointer<Utf8>? directoryPathPtr,
    Pointer<Pointer<Utf8>>? extensionsPtr,
    int extensionsCount,
  ) {
    callback?.close();
    if (config != null && config != nullptr) {
      calloc.free(config);
    }
    if (directoryPathPtr != null && directoryPathPtr != nullptr) {
      freeCString(directoryPathPtr);
    }
    if (extensionsPtr != null && extensionsPtr != nullptr) {
      freeStringArray(extensionsPtr, extensionsCount);
    }
  }

  /// Convert CEmbedData to ChunkEmbedding
  ChunkEmbedding _cEmbedDataToChunkEmbedding(CEmbedData embedData) {
    // Copy embedding vector
    final embeddingValues = _copyFloatArray(
      embedData.embeddingValues,
      embedData.embeddingLen,
    );
    final embedding = EmbeddingResult(embeddingValues);

    // Parse combined text and metadata JSON (SurrealDB pattern)
    String? text;
    Map<String, String>? metadata;

    print('DEBUG DART: textAndMetadataJson pointer: ${embedData.textAndMetadataJson}');
    if (embedData.textAndMetadataJson != nullptr) {
      print('DEBUG DART: Pointer is NOT null, converting to string...');
      final jsonString = embedData.textAndMetadataJson.toDartString();
      print('DEBUG DART: JSON string received: $jsonString');
      try {
        final combined = jsonDecode(jsonString);
        print('DEBUG DART: Decoded JSON: $combined');
        if (combined is Map) {
          // Extract text field (may be null in JSON)
          final textValue = combined['text'];
          if (textValue != null && textValue is String) {
            text = textValue;
            print('DEBUG DART: Extracted text (${text!.length} chars)');
          }

          // Extract metadata field (may be null in JSON)
          final metadataValue = combined['metadata'];
          if (metadataValue != null && metadataValue is Map) {
            // Convert all values to strings
            metadata = metadataValue.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
            print('DEBUG DART: Extracted metadata with ${metadata!.length} keys');
          }
        }
      } catch (e) {
        print('DEBUG DART: JSON parsing failed: $e');
        // Invalid JSON, leave text and metadata as null
      }
    } else {
      print('DEBUG DART: Pointer IS null!');
    }

    return ChunkEmbedding(
      embedding: embedding,
      text: text,
      metadata: metadata,
    );
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

  // ==========================================================================
  // THREAD POOL CONFIGURATION
  // ==========================================================================

  /// Configure the maximum number of threads for parallel embedding operations.
  ///
  /// **MUST be called BEFORE creating any EmbedAnything instances or loading
  /// any models.** Once the thread pool is initialized (which happens on first
  /// use), this setting cannot be changed.
  ///
  /// The underlying ML library (Candle) uses Rayon for parallel matrix
  /// operations. By default, Rayon creates one thread per CPU core, which
  /// can be excessive on machines with many cores.
  ///
  /// Recommended values:
  /// - 4-8 threads for most use cases
  /// - 2-4 threads for memory-constrained environments
  /// - 0 to use the default (num_cpus)
  ///
  /// Parameters:
  /// - [numThreads]: Maximum threads (0 = use default/num_cpus)
  ///
  /// Returns `true` if configuration succeeded, `false` if called too late.
  ///
  /// Example:
  /// ```dart
  /// // Configure BEFORE loading any models
  /// EmbedAnything.configureThreadPool(4);
  ///
  /// // Now load models and embed
  /// final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  /// ```
  static bool configureThreadPool(int numThreads) {
    final result = ffi.configureThreadPool(numThreads);
    return result == 0;
  }

  /// Get the current thread pool size.
  ///
  /// Returns the number of threads in the Rayon thread pool.
  /// If [configureThreadPool] was not called, returns the default (num_cpus).
  static int getThreadPoolSize() {
    return ffi.getThreadPoolSize();
  }

  // ==========================================================================
  // DEVICE QUERY METHODS - Check compute device availability
  // ==========================================================================

  /// Get the currently active compute device.
  ///
  /// This returns the device that will be used for all embedding operations.
  /// The device is automatically selected at model load time based on
  /// compiled features and hardware availability:
  ///
  /// 1. Metal (on macOS/iOS if GPU is available)
  /// 2. CUDA (on Linux/Windows if NVIDIA GPU is available)
  /// 3. CPU (fallback, always available)
  ///
  /// Note: MKL and Accelerate are CPU optimizations that don't change the
  /// device type - they speed up matrix operations but still use CPU.
  ///
  /// Example:
  /// ```dart
  /// final device = EmbedAnything.getActiveDevice();
  /// print('Using: $device'); // e.g., "ComputeDevice.metal"
  ///
  /// if (device == ComputeDevice.cuda) {
  ///   print('GPU acceleration enabled!');
  /// }
  /// ```
  static ComputeDevice getActiveDevice() {
    _initializeRuntime();
    return ComputeDevice.fromValue(ffi.getActiveDevice());
  }

  /// Check if a specific compute device is available.
  ///
  /// Returns `true` if the device can be used for computation, `false` otherwise.
  ///
  /// This is useful for checking hardware capabilities before loading models
  /// or for displaying device information in your application.
  ///
  /// Example:
  /// ```dart
  /// // Check available acceleration
  /// if (EmbedAnything.isDeviceAvailable(ComputeDevice.cuda)) {
  ///   print('CUDA GPU acceleration available!');
  /// } else if (EmbedAnything.isDeviceAvailable(ComputeDevice.metal)) {
  ///   print('Metal GPU acceleration available!');
  /// } else {
  ///   print('Using CPU (consider installing CUDA toolkit for better performance)');
  /// }
  /// ```
  static bool isDeviceAvailable(ComputeDevice device) {
    _initializeRuntime();
    return ffi.isDeviceAvailable(device.value) == 1;
  }

  // ==========================================================================
  // ASYNC METHODS - Non-blocking operations for Flutter UI
  // ==========================================================================

  /// Load a model asynchronously without blocking the UI.
  ///
  /// This is the recommended way to load models in Flutter applications.
  /// Model loading (especially the first time with model downloads) can
  /// take several seconds, so async loading keeps your UI responsive.
  ///
  /// Parameters:
  /// - [modelId]: HuggingFace model identifier
  ///   (e.g., 'sentence-transformers/all-MiniLM-L6-v2')
  /// - [revision]: Git revision/branch (defaults to 'main')
  /// - [dtype]: Model data type (default: auto)
  ///
  /// Throws:
  /// - [ModelNotFoundError] if model doesn't exist on HuggingFace Hub
  /// - [EmbeddingCancelledError] if operation was cancelled
  /// - [FFIError] if model loading fails
  ///
  /// Example:
  /// ```dart
  /// // Load model without blocking UI
  /// final embedder = await EmbedAnything.fromPretrainedHfAsync(
  ///   modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  /// );
  ///
  /// try {
  ///   final result = await embedder.embedTextAsync('Hello world');
  ///   print('Dimension: ${result.dimension}');
  /// } finally {
  ///   embedder.dispose();
  /// }
  /// ```
  static Future<EmbedAnything> fromPretrainedHfAsync({
    required String modelId,
    String revision = 'main',
    ModelDtype dtype = ModelDtype.f32,
  }) async {
    // Initialize runtime first
    _initializeRuntime();

    final opId = withCString(modelId, (modelIdPtr) {
      return withCString(revision, (revisionPtr) {
        return async_ffi.startLoadModel(modelIdPtr, revisionPtr, dtype.value);
      });
    });

    if (opId < 0) {
      throwLastError('Failed to start model loading');
    }

    final handle = await _pollUntilComplete<Pointer<CEmbedder>>(
      opId,
      AsyncResultType.modelLoad,
    );

    // Create config for reference
    final config = ModelConfig(
      modelId: modelId,
      modelType: EmbeddingModel.bert, // Default, actual type determined by model
      revision: revision,
      dtype: dtype,
    );

    return EmbedAnything._(handle, config);
  }

  /// Embed text asynchronously without blocking the UI.
  ///
  /// This is the async version of [embedText]. Use this in Flutter
  /// applications to keep the UI responsive during embedding generation.
  ///
  /// Parameters:
  /// - [text]: The text to embed
  ///
  /// Returns a [Future] that completes with the [EmbeddingResult].
  ///
  /// Throws:
  /// - [EmbeddingFailedError] if embedding generation fails
  /// - [EmbeddingCancelledError] if operation was cancelled
  /// - [StateError] if the embedder has been disposed
  ///
  /// Example:
  /// ```dart
  /// final result = await embedder.embedTextAsync('Hello, world!');
  /// print('Dimension: ${result.dimension}');
  /// ```
  Future<EmbeddingResult> embedTextAsync(String text) async {
    _checkDisposed();

    final opId = withCString(text, (textPtr) {
      return async_ffi.startEmbedText(_handle, textPtr);
    });

    if (opId < 0) {
      throwLastError('Failed to start text embedding');
    }

    return _pollUntilComplete<EmbeddingResult>(
      opId,
      AsyncResultType.singleEmbedding,
    );
  }

  /// Embed multiple texts asynchronously without blocking the UI.
  ///
  /// This is the async version of [embedTextsBatch]. Use this in Flutter
  /// applications for batch processing without freezing the UI.
  ///
  /// **Auto-chunking:** For large batches, texts are automatically processed
  /// in chunks to prevent memory issues and system overload. The chunk size
  /// is determined by [chunkSize] parameter, [ModelConfig.defaultBatchSize],
  /// or defaults to 32.
  ///
  /// Parameters:
  /// - [texts]: List of texts to embed
  /// - [chunkSize]: Override the default batch chunk size. If not specified,
  ///   uses [ModelConfig.defaultBatchSize] or 32.
  /// - [onProgress]: Optional callback for progress updates. Called after
  ///   each chunk completes with (completedCount, totalCount).
  ///
  /// Returns a [Future] that completes with a list of [EmbeddingResult]s.
  ///
  /// Throws:
  /// - [EmbeddingFailedError] if embedding generation fails
  /// - [EmbeddingCancelledError] if operation was cancelled
  /// - [StateError] if the embedder has been disposed
  ///
  /// Example:
  /// ```dart
  /// // Simple usage
  /// final results = await embedder.embedTextsBatchAsync([
  ///   'First text',
  ///   'Second text',
  ///   'Third text',
  /// ]);
  /// print('Generated ${results.length} embeddings');
  ///
  /// // With progress tracking for large batches
  /// final results = await embedder.embedTextsBatchAsync(
  ///   largeTextList,
  ///   chunkSize: 50,
  ///   onProgress: (done, total) => print('Progress: $done / $total'),
  /// );
  /// ```
  Future<List<EmbeddingResult>> embedTextsBatchAsync(
    List<String> texts, {
    int? chunkSize,
    void Function(int completed, int total)? onProgress,
  }) async {
    _checkDisposed();

    if (texts.isEmpty) {
      return [];
    }

    // Determine effective chunk size
    final effectiveChunkSize = chunkSize ?? _config?.defaultBatchSize ?? 32;

    // If batch is small enough, process directly without chunking overhead
    if (texts.length <= effectiveChunkSize) {
      final results = await _embedTextsBatchAsyncInternal(texts);
      onProgress?.call(texts.length, texts.length);
      return results;
    }

    // Process in chunks for large batches
    final results = <EmbeddingResult>[];

    for (int i = 0; i < texts.length; i += effectiveChunkSize) {
      final end = (i + effectiveChunkSize < texts.length)
          ? i + effectiveChunkSize
          : texts.length;
      final chunk = texts.sublist(i, end);

      final chunkResults = await _embedTextsBatchAsyncInternal(chunk);
      results.addAll(chunkResults);

      // Report progress after each chunk
      onProgress?.call(results.length, texts.length);
    }

    return results;
  }

  /// Internal method to embed a batch of texts without chunking.
  Future<List<EmbeddingResult>> _embedTextsBatchAsyncInternal(
    List<String> texts,
  ) async {
    // Convert Dart strings to C strings
    final cStrings = texts.map((t) => stringToCString(t)).toList();
    final cStringsArray = malloc<Pointer<Utf8>>(texts.length);

    try {
      // Fill the array
      for (int i = 0; i < texts.length; i++) {
        cStringsArray[i] = cStrings[i];
      }

      final opId = async_ffi.startEmbedTextsBatch(
        _handle,
        cStringsArray,
        texts.length,
      );

      if (opId < 0) {
        throwLastError('Failed to start batch embedding');
      }

      return _pollUntilComplete<List<EmbeddingResult>>(
        opId,
        AsyncResultType.batchEmbedding,
      );
    } finally {
      // Free all C strings
      for (final cStr in cStrings) {
        freeCString(cStr);
      }
      malloc.free(cStringsArray);
    }
  }

  /// Embed a file asynchronously without blocking the UI.
  ///
  /// This is the async version of [embedFile]. Use this in Flutter
  /// applications for file processing without freezing the UI.
  ///
  /// Parameters:
  /// - [filePath]: Path to the file to embed
  /// - [chunkSize]: Maximum characters per chunk (default: 1000)
  /// - [overlapRatio]: Overlap between chunks 0.0-1.0 (default: 0.0)
  /// - [batchSize]: Batch size for embedding generation (default: 32)
  ///
  /// Returns a [Future] that completes with a list of [ChunkEmbedding]s.
  ///
  /// Throws:
  /// - [FileNotFoundError] if the file does not exist
  /// - [UnsupportedFileFormatError] if the file format is not supported
  /// - [EmbeddingCancelledError] if operation was cancelled
  /// - [StateError] if the embedder has been disposed
  ///
  /// Example:
  /// ```dart
  /// final chunks = await embedder.embedFileAsync('document.pdf');
  /// for (final chunk in chunks) {
  ///   print('Chunk ${chunk.chunkIndex}: ${chunk.text?.substring(0, 50)}...');
  /// }
  /// ```
  Future<List<ChunkEmbedding>> embedFileAsync(
    String filePath, {
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  }) async {
    _checkDisposed();

    // Allocate config struct
    final config = allocateTextEmbedConfig(
      chunkSize: chunkSize,
      overlapRatio: overlapRatio,
      batchSize: batchSize,
      bufferSize: 100,
    );

    // Convert file path to C string
    final filePathPtr = stringToCString(filePath);

    try {
      final opId = async_ffi.startEmbedFile(_handle, filePathPtr, config);

      if (opId < 0) {
        throwLastError('Failed to start file embedding');
      }

      return _pollUntilComplete<List<ChunkEmbedding>>(
        opId,
        AsyncResultType.fileEmbedding,
      );
    } finally {
      freeCString(filePathPtr);
      calloc.free(config);
    }
  }

  /// Embed a directory asynchronously without blocking the UI.
  ///
  /// This is an async version that returns a Future instead of a Stream.
  /// All results are collected and returned when processing is complete.
  ///
  /// Parameters:
  /// - [directoryPath]: Path to the directory to embed
  /// - [extensions]: Optional list of file extensions to include
  /// - [chunkSize]: Maximum characters per chunk (default: 1000)
  /// - [overlapRatio]: Overlap between chunks 0.0-1.0 (default: 0.0)
  /// - [batchSize]: Batch size for embedding generation (default: 32)
  ///
  /// Returns a [Future] that completes with a list of [ChunkEmbedding]s.
  ///
  /// Throws:
  /// - [FileNotFoundError] if the directory does not exist
  /// - [EmbeddingCancelledError] if operation was cancelled
  /// - [StateError] if the embedder has been disposed
  ///
  /// Example:
  /// ```dart
  /// final chunks = await embedder.embedDirectoryAsync(
  ///   'documents/',
  ///   extensions: ['.pdf', '.txt'],
  /// );
  /// print('Generated ${chunks.length} chunks');
  /// ```
  Future<List<ChunkEmbedding>> embedDirectoryAsync(
    String directoryPath, {
    List<String>? extensions,
    int chunkSize = 1000,
    double overlapRatio = 0.0,
    int batchSize = 32,
  }) async {
    _checkDisposed();

    // Allocate config struct
    final config = allocateTextEmbedConfig(
      chunkSize: chunkSize,
      overlapRatio: overlapRatio,
      batchSize: batchSize,
      bufferSize: 100,
    );

    // Convert directory path to C string
    final directoryPathPtr = stringToCString(directoryPath);

    // Allocate extensions array if provided
    Pointer<Pointer<Utf8>>? extensionsPtr;
    if (extensions != null && extensions.isNotEmpty) {
      extensionsPtr = allocateStringArray(extensions);
    }

    try {
      final opId = async_ffi.startEmbedDirectory(
        _handle,
        directoryPathPtr,
        extensionsPtr ?? nullptr,
        extensions?.length ?? 0,
        config,
      );

      if (opId < 0) {
        throwLastError('Failed to start directory embedding');
      }

      return _pollUntilComplete<List<ChunkEmbedding>>(
        opId,
        AsyncResultType.fileEmbedding,
      );
    } finally {
      freeCString(directoryPathPtr);
      calloc.free(config);
      if (extensionsPtr != null) {
        freeStringArray(extensionsPtr, extensions!.length);
      }
    }
  }

  /// Start an async text embedding that can be cancelled.
  ///
  /// Unlike [embedTextAsync], this returns an [AsyncEmbeddingOperation]
  /// that allows you to cancel the operation if needed.
  ///
  /// Parameters:
  /// - [text]: The text to embed
  ///
  /// Returns an [AsyncEmbeddingOperation] with a [future] that completes
  /// with the result, and a [cancel] method to abort the operation.
  ///
  /// Example:
  /// ```dart
  /// final operation = embedder.startEmbedTextAsync('Some long text...');
  ///
  /// // Later, if needed:
  /// operation.cancel();
  ///
  /// try {
  ///   final result = await operation.future;
  /// } on EmbeddingCancelledError catch (e) {
  ///   print('Operation was cancelled');
  /// }
  /// ```
  AsyncEmbeddingOperation<EmbeddingResult> startEmbedTextAsync(String text) {
    _checkDisposed();

    final opId = withCString(text, (textPtr) {
      return async_ffi.startEmbedText(_handle, textPtr);
    });

    if (opId < 0) {
      // Return an operation that immediately fails
      return AsyncEmbeddingOperation<EmbeddingResult>._(
        opId,
        Future.error(FFIError(
          operation: 'startEmbedText',
          nativeError: getLastErrorMessage(),
        )),
      );
    }

    final future = _pollUntilComplete<EmbeddingResult>(
      opId,
      AsyncResultType.singleEmbedding,
    );

    return AsyncEmbeddingOperation._(opId, future);
  }

  /// Poll for async operation completion.
  ///
  /// Returns when the operation completes (success/error/cancelled).
  static Future<T> _pollUntilComplete<T>(int opId, int expectedType) async {
    const pollInterval = Duration(milliseconds: 10);

    while (true) {
      final result = async_ffi.pollAsyncResult(opId);

      switch (result.status) {
        case AsyncPollStatus.success:
          try {
            return _extractResult<T>(result, expectedType);
          } finally {
            // Free error message if present
            if (result.errorMessage != nullptr) {
              async_ffi.freeAsyncErrorMessage(result.errorMessage);
            }
          }

        case AsyncPollStatus.error:
          final errorMsg = result.errorMessage != nullptr
              ? result.errorMessage.toDartString()
              : 'Unknown error';
          if (result.errorMessage != nullptr) {
            async_ffi.freeAsyncErrorMessage(result.errorMessage);
          }
          throwLastError(errorMsg);

        case AsyncPollStatus.cancelled:
          throw EmbeddingCancelledError();

        case AsyncPollStatus.pending:
        default:
          await Future.delayed(pollInterval);
      }
    }
  }

  /// Extract typed result from CAsyncPollResult.
  static T _extractResult<T>(CAsyncPollResult result, int expectedType) {
    if (result.resultType != expectedType) {
      throw FFIError(
        operation: 'extractResult',
        nativeError: 'Unexpected result type: ${result.resultType} (expected $expectedType)',
      );
    }

    switch (expectedType) {
      case AsyncResultType.singleEmbedding:
        final ptr = result.data.cast<CTextEmbedding>();
        final embedding = ptr.ref;
        final values = _copyFloatArray(embedding.values, embedding.len);
        // Free the embedding
        ffi.freeEmbedding(ptr);
        return EmbeddingResult(values) as T;

      case AsyncResultType.batchEmbedding:
        final ptr = result.data.cast<CTextEmbeddingBatch>();
        final batch = ptr.ref;
        final results = <EmbeddingResult>[];
        for (int i = 0; i < batch.count; i++) {
          final embedding = batch.embeddings[i];
          final values = _copyFloatArray(embedding.values, embedding.len);
          results.add(EmbeddingResult(values));
        }
        // Free the batch
        ffi.freeEmbeddingBatch(ptr);
        return results as T;

      case AsyncResultType.fileEmbedding:
        final ptr = result.data.cast<CEmbedDataBatch>();
        final batch = ptr.ref;
        final results = <ChunkEmbedding>[];
        for (int i = 0; i < batch.count; i++) {
          final embedData = batch.items[i];
          results.add(_cEmbedDataToChunkEmbeddingStatic(embedData));
        }
        // Free the batch
        ffi.freeEmbedDataBatch(ptr);
        return results as T;

      case AsyncResultType.modelLoad:
        return result.data.cast<CEmbedder>() as T;

      default:
        throw FFIError(
          operation: 'extractResult',
          nativeError: 'Unknown result type: $expectedType',
        );
    }
  }

  /// Static version of _cEmbedDataToChunkEmbedding for use in static methods.
  static ChunkEmbedding _cEmbedDataToChunkEmbeddingStatic(CEmbedData embedData) {
    // Copy embedding vector
    final embeddingValues = _copyFloatArray(
      embedData.embeddingValues,
      embedData.embeddingLen,
    );
    final embedding = EmbeddingResult(embeddingValues);

    // Parse combined text and metadata JSON
    String? text;
    Map<String, String>? metadata;

    if (embedData.textAndMetadataJson != nullptr) {
      final jsonString = embedData.textAndMetadataJson.toDartString();
      try {
        final combined = jsonDecode(jsonString);
        if (combined is Map) {
          final textValue = combined['text'];
          if (textValue != null && textValue is String) {
            text = textValue;
          }

          final metadataValue = combined['metadata'];
          if (metadataValue != null && metadataValue is Map) {
            metadata = metadataValue.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            );
          }
        }
      } catch (_) {
        // Invalid JSON, leave text and metadata as null
      }
    }

    return ChunkEmbedding(
      embedding: embedding,
      text: text,
      metadata: metadata,
    );
  }
}

/// Represents an in-progress async embedding operation that can be cancelled.
///
/// This class wraps an async operation and provides:
/// - A [future] that completes with the result
/// - A [cancel] method to abort the operation
/// - An [isCancelled] property to check cancellation status
///
/// Example:
/// ```dart
/// final operation = embedder.startEmbedTextAsync('Some text');
///
/// // Cancel if taking too long
/// Future.delayed(Duration(seconds: 5), () {
///   if (!operation.future.isCompleted) {
///     operation.cancel();
///   }
/// });
///
/// try {
///   final result = await operation.future;
///   print('Got result: ${result.dimension} dimensions');
/// } on EmbeddingCancelledError catch (e) {
///   print('Operation was cancelled');
/// }
/// ```
class AsyncEmbeddingOperation<T> {
  final int _operationId;

  /// The future that completes with the operation result.
  final Future<T> future;

  bool _cancelled = false;

  AsyncEmbeddingOperation._(this._operationId, this.future);

  /// Cancel the operation.
  ///
  /// After calling this, the [future] will complete with an
  /// [EmbeddingCancelledError].
  ///
  /// This method is idempotent - calling it multiple times is safe.
  void cancel() {
    if (!_cancelled) {
      _cancelled = true;
      async_ffi.cancelAsyncOperation(_operationId);
    }
  }

  /// Whether the operation has been cancelled.
  bool get isCancelled => _cancelled;

  /// The operation ID (for debugging).
  int get operationId => _operationId;
}
