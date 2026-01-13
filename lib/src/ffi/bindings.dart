import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'native_types.dart';

// Asset ID must match: package:<pubspec_name>/<cargo_package_name>
const String _assetId = 'package:embedanythingindart/embedanything_dart';

// ============================================================================
// Runtime Initialization
// ============================================================================

/// Initialize the Tokio runtime (must be called once before using embedder)
@Native<Int32 Function()>(
  symbol: 'init_runtime',
  assetId: _assetId,
)
external int initRuntime();

// ============================================================================
// Thread Pool Configuration
// ============================================================================

/// Configure the global Rayon thread pool with a limited number of threads.
///
/// MUST be called BEFORE any embedding operations to take effect.
/// If not called, Rayon uses num_cpus threads by default.
///
/// Parameters:
/// - numThreads: Maximum number of threads (0 = use default/num_cpus)
///
/// Returns:
/// - 0 on success
/// - -1 if thread pool was already initialized (call came too late)
/// - -2 on other errors
@Native<Int32 Function(Size)>(
  symbol: 'configure_thread_pool',
  assetId: _assetId,
)
external int configureThreadPool(int numThreads);

/// Get the current number of Rayon threads.
@Native<Int32 Function()>(
  symbol: 'get_thread_pool_size',
  assetId: _assetId,
)
external int getThreadPoolSize();

// ============================================================================
// Error Handling
// ============================================================================

/// Get the last error message from the Rust side
@Native<Pointer<Utf8> Function()>(
  symbol: 'get_last_error',
  assetId: _assetId,
)
external Pointer<Utf8> getLastError();

/// Free an error string allocated by Rust
@Native<Void Function(Pointer<Utf8>)>(
  symbol: 'free_error_string',
  assetId: _assetId,
)
external void freeErrorString(Pointer<Utf8> ptr);

// ============================================================================
// Model Loading
// ============================================================================

/// Create an embedder from a pretrained HuggingFace model
///
/// Parameters:
/// - modelType: 0 = BERT, 1 = Jina
/// - modelId: HuggingFace model identifier
/// - revision: Git revision (or nullptr for default)
/// - dtype: Data type for model weights (0 = F32, 1 = F16, -1 = default)
///
/// Returns: Pointer to CEmbedder or nullptr on failure
@Native<
    Pointer<CEmbedder> Function(Uint8, Pointer<Utf8>, Pointer<Utf8>, Int32)>(
  symbol: 'embedder_from_pretrained_hf',
  assetId: _assetId,
)
external Pointer<CEmbedder> embedderFromPretrainedHf(
  int modelType,
  Pointer<Utf8> modelId,
  Pointer<Utf8> revision,
  int dtype,
);

// ============================================================================
// Embedding Operations - Text
// ============================================================================

/// Embed a single text query
///
/// Parameters:
/// - embedder: Pointer to CEmbedder
/// - text: Text to embed
///
/// Returns: Pointer to CTextEmbedding or nullptr on failure
@Native<Pointer<CTextEmbedding> Function(Pointer<CEmbedder>, Pointer<Utf8>)>(
  symbol: 'embed_text',
  assetId: _assetId,
)
external Pointer<CTextEmbedding> embedText(
  Pointer<CEmbedder> embedder,
  Pointer<Utf8> text,
);

/// Embed a batch of texts
///
/// Parameters:
/// - embedder: Pointer to CEmbedder
/// - texts: Array of text pointers
/// - count: Number of texts
///
/// Returns: Pointer to CTextEmbeddingBatch or nullptr on failure
@Native<
    Pointer<CTextEmbeddingBatch> Function(
      Pointer<CEmbedder>,
      Pointer<Pointer<Utf8>>,
      Size,
    )>(
  symbol: 'embed_texts_batch',
  assetId: _assetId,
)
external Pointer<CTextEmbeddingBatch> embedTextsBatch(
  Pointer<CEmbedder> embedder,
  Pointer<Pointer<Utf8>> texts,
  int count,
);

// ============================================================================
// Embedding Operations - File & Directory (Phase 3)
// ============================================================================

/// Callback typedef for directory streaming
///
/// Called from Rust with batches of embeddings during directory processing.
/// Parameters:
/// - batch: Pointer to CEmbedDataBatch containing the embeddings
/// - context: User data pointer passed through from embedDirectoryStream
typedef StreamCallbackType = Void Function(
    Pointer<CEmbedDataBatch>, Pointer<Void>);

/// Embed a single file with chunking
///
/// Parameters:
/// - embedder: Pointer to CEmbedder
/// - filePath: Path to file to embed
/// - config: Pointer to CTextEmbedConfig with chunking parameters
///
/// Returns: Pointer to CEmbedDataBatch or nullptr on failure
@Native<
    Pointer<CEmbedDataBatch> Function(
      Pointer<CEmbedder>,
      Pointer<Utf8>,
      Pointer<CTextEmbedConfig>,
    )>(
  symbol: 'embed_file',
  assetId: _assetId,
)
external Pointer<CEmbedDataBatch> embedFile(
  Pointer<CEmbedder> embedder,
  Pointer<Utf8> filePath,
  Pointer<CTextEmbedConfig> config,
);

/// Embed all files in a directory with streaming callback
///
/// Parameters:
/// - embedder: Pointer to CEmbedder
/// - directoryPath: Path to directory to embed
/// - extensions: NULL-terminated array of extension strings, or nullptr for all
/// - extensionsCount: Number of extensions (0 if extensions is nullptr)
/// - config: Pointer to CTextEmbedConfig with chunking parameters
/// - callback: Function to call with each batch of embeddings
/// - callbackContext: User data passed through to callback
///
/// Returns: 0 on success, -1 on failure
@Native<
    Int32 Function(
      Pointer<CEmbedder>,
      Pointer<Utf8>,
      Pointer<Pointer<Utf8>>,
      Size,
      Pointer<CTextEmbedConfig>,
      Pointer<NativeFunction<StreamCallbackType>>,
      Pointer<Void>,
    )>(
  symbol: 'embed_directory_stream',
  assetId: _assetId,
)
external int embedDirectoryStream(
  Pointer<CEmbedder> embedder,
  Pointer<Utf8> directoryPath,
  Pointer<Pointer<Utf8>> extensions,
  int extensionsCount,
  Pointer<CTextEmbedConfig> config,
  Pointer<NativeFunction<StreamCallbackType>> callback,
  Pointer<Void> callbackContext,
);

// ============================================================================
// Memory Management
// ============================================================================

/// Free an embedder instance
@Native<Void Function(Pointer<CEmbedder>)>(
  symbol: 'embedder_free',
  assetId: _assetId,
)
external void embedderFree(Pointer<CEmbedder> embedder);

/// Free a single text embedding
@Native<Void Function(Pointer<CTextEmbedding>)>(
  symbol: 'free_embedding',
  assetId: _assetId,
)
external void freeEmbedding(Pointer<CTextEmbedding> embedding);

/// Free a batch of text embeddings
@Native<Void Function(Pointer<CTextEmbeddingBatch>)>(
  symbol: 'free_embedding_batch',
  assetId: _assetId,
)
external void freeEmbeddingBatch(Pointer<CTextEmbeddingBatch> batch);

/// Free a single embed data instance (Phase 3)
@Native<Void Function(Pointer<CEmbedData>)>(
  symbol: 'free_embed_data',
  assetId: _assetId,
)
external void freeEmbedData(Pointer<CEmbedData> data);

/// Free a batch of embed data instances (Phase 3)
@Native<Void Function(Pointer<CEmbedDataBatch>)>(
  symbol: 'free_embed_data_batch',
  assetId: _assetId,
)
external void freeEmbedDataBatch(Pointer<CEmbedDataBatch> batch);

// ============================================================================
// Device Query Functions
// ============================================================================

/// Get the currently active compute device type.
///
/// Returns:
/// - 0: CPU
/// - 1: CUDA (NVIDIA GPU)
/// - 2: Metal (Apple GPU)
///
/// The device is auto-selected based on compiled features and availability:
/// 1. Metal (on macOS if available)
/// 2. CUDA (on Linux/Windows if available)
/// 3. CPU (fallback, always available)
@Native<Int32 Function()>(
  symbol: 'get_active_device',
  assetId: _assetId,
)
external int getActiveDevice();

/// Check if a specific device type is available.
///
/// Parameters:
/// - deviceType: 0=CPU, 1=CUDA, 2=Metal
///
/// Returns:
/// - 1: Device is available
/// - 0: Device is not available
@Native<Int32 Function(Int32)>(
  symbol: 'is_device_available',
  assetId: _assetId,
)
external int isDeviceAvailable(int deviceType);
