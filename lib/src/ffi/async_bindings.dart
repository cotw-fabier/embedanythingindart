// FFI bindings for async embedding operations.
//
// These @Native declarations map to the FFI functions in async_embed.rs.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'async_types.dart';
import 'native_types.dart';

// ============================================================================
// Async Model Loading
// ============================================================================

/// Start loading a model asynchronously.
///
/// Returns operation ID (positive) on success, -1 on immediate failure.
@Native<Int64 Function(Pointer<Utf8>, Pointer<Utf8>, Int32)>(
  symbol: 'start_load_model',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external int startLoadModel(
  Pointer<Utf8> modelId,
  Pointer<Utf8> revision,
  int dtype,
);

// ============================================================================
// Async Text Embedding
// ============================================================================

/// Start embedding a single text asynchronously.
///
/// Returns operation ID (positive) on success, -1 on immediate failure.
@Native<Int64 Function(Pointer<CEmbedder>, Pointer<Utf8>)>(
  symbol: 'start_embed_text',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external int startEmbedText(Pointer<CEmbedder> embedder, Pointer<Utf8> text);

/// Start embedding multiple texts asynchronously.
///
/// Returns operation ID (positive) on success, -1 on immediate failure.
@Native<Int64 Function(Pointer<CEmbedder>, Pointer<Pointer<Utf8>>, Size)>(
  symbol: 'start_embed_texts_batch',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external int startEmbedTextsBatch(
  Pointer<CEmbedder> embedder,
  Pointer<Pointer<Utf8>> texts,
  int count,
);

// ============================================================================
// Async File/Directory Embedding
// ============================================================================

/// Start embedding a file asynchronously.
///
/// Returns operation ID (positive) on success, -1 on immediate failure.
@Native<Int64 Function(Pointer<CEmbedder>, Pointer<Utf8>, Pointer<CTextEmbedConfig>)>(
  symbol: 'start_embed_file',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external int startEmbedFile(
  Pointer<CEmbedder> embedder,
  Pointer<Utf8> filePath,
  Pointer<CTextEmbedConfig> config,
);

/// Start embedding a directory asynchronously.
///
/// Returns operation ID (positive) on success, -1 on immediate failure.
@Native<Int64 Function(Pointer<CEmbedder>, Pointer<Utf8>, Pointer<Pointer<Utf8>>, Size, Pointer<CTextEmbedConfig>)>(
  symbol: 'start_embed_directory',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external int startEmbedDirectory(
  Pointer<CEmbedder> embedder,
  Pointer<Utf8> directoryPath,
  Pointer<Pointer<Utf8>> extensions,
  int extensionsCount,
  Pointer<CTextEmbedConfig> config,
);

// ============================================================================
// Polling and Cancellation
// ============================================================================

/// Poll for the result of an async operation.
///
/// Returns CAsyncPollResult with status and data.
@Native<CAsyncPollResult Function(Int64)>(
  symbol: 'poll_async_result',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external CAsyncPollResult pollAsyncResult(int operationId);

/// Cancel an async operation.
///
/// Returns 0 on success, -1 if operation ID not found.
@Native<Int32 Function(Int64)>(
  symbol: 'cancel_async_operation',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external int cancelAsyncOperation(int operationId);

// ============================================================================
// Memory Cleanup
// ============================================================================

/// Free the error message from a poll result.
@Native<Void Function(Pointer<Utf8>)>(
  symbol: 'free_async_error_message',
  assetId: 'package:embedanythingindart/embedanything_dart',
)
external void freeAsyncErrorMessage(Pointer<Utf8> ptr);
