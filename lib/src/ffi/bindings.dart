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
// Embedding Operations
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
// Memory Management
// ============================================================================

/// Free an embedder instance
@Native<Void Function(Pointer<CEmbedder>)>(
  symbol: 'embedder_free',
  assetId: _assetId,
)
external void embedderFree(Pointer<CEmbedder> embedder);

/// Free a single embedding
@Native<Void Function(Pointer<CTextEmbedding>)>(
  symbol: 'free_embedding',
  assetId: _assetId,
)
external void freeEmbedding(Pointer<CTextEmbedding> embedding);

/// Free a batch of embeddings
@Native<Void Function(Pointer<CTextEmbeddingBatch>)>(
  symbol: 'free_embedding_batch',
  assetId: _assetId,
)
external void freeEmbeddingBatch(Pointer<CTextEmbeddingBatch> batch);
