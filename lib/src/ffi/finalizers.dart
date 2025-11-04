import 'dart:ffi';

import 'bindings.dart';
import 'native_types.dart';

// TEMPORARY FIX: NativeFinalizer with @Native functions
//
// The new @Native API in Dart doesn't provide a straightforward way to get
// function pointers for NativeFinalizer. The old Native.addressOf API has
// been removed, and there's no direct replacement yet.
//
// For now, we don't use NativeFinalizers at all since they would require
// native callbacks that can cause isolate issues. Users must manually dispose.
// This is safe but requires explicit cleanup.
//
// TODO: Once Dart provides a proper API for getting @Native function addresses,
// update these to use proper NativeFinalizers.
//
// See: https://github.com/dart-lang/sdk/issues/...

// Manual cleanup functions for explicit use
// These are the functions that MUST be called manually

/// Manually free an embedder instance
void manualEmbedderFree(Pointer<CEmbedder> ptr) {
  if (ptr != nullptr) {
    embedderFree(ptr);
  }
}

/// Manually free an embedding instance
void manualFreeEmbedding(Pointer<CTextEmbedding> ptr) {
  if (ptr != nullptr) {
    freeEmbedding(ptr);
  }
}

/// Manually free an embedding batch instance
void manualFreeEmbeddingBatch(Pointer<CTextEmbeddingBatch> ptr) {
  if (ptr != nullptr) {
    freeEmbeddingBatch(ptr);
  }
}

/// Manually free an embed data instance (Phase 3)
///
/// Frees a single CEmbedData including its embedding values, text, and metadata.
/// This function should be called for each CEmbedData that is no longer needed.
///
/// Note: If the CEmbedData is part of a CEmbedDataBatch, prefer using
/// manualFreeEmbedDataBatch which will free all items in the batch.
void manualFreeEmbedData(Pointer<CEmbedData> ptr) {
  if (ptr != nullptr) {
    freeEmbedData(ptr);
  }
}

/// Manually free an embed data batch instance (Phase 3)
///
/// Frees a CEmbedDataBatch and all contained CEmbedData items.
/// This includes freeing all embedding vectors, text strings, and metadata
/// for each item in the batch.
///
/// Behavior and Timing:
/// - Call this function after copying all needed data from the batch to Dart
/// - The batch and all items are freed immediately
/// - Do NOT access the batch pointer after calling this function
/// - Safe to call with nullptr (no-op)
///
/// Example:
/// ```dart
/// final batch = embedFile(embedder, filePath, config);
/// try {
///   // Process batch and copy data to Dart
///   final chunks = convertBatchToChunks(batch);
/// } finally {
///   // Always free in finally block
///   manualFreeEmbedDataBatch(batch);
/// }
/// ```
void manualFreeEmbedDataBatch(Pointer<CEmbedDataBatch> ptr) {
  if (ptr != nullptr) {
    freeEmbedDataBatch(ptr);
  }
}
