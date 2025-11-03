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
