// Async FFI types for non-blocking embedding operations.
//
// These types map to the C-compatible structs defined in async_embed.rs.

import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Poll result from async operations.
///
/// Maps to CAsyncPollResult in Rust.
final class CAsyncPollResult extends Struct {
  /// Status: 0=pending, 1=success, -1=error, -2=cancelled
  @Int32()
  external int status;

  /// Result type: 0=single, 1=batch, 2=file, 3=model
  @Int32()
  external int resultType;

  /// Pointer to result data (type depends on resultType)
  external Pointer<Void> data;

  /// Error message (only set if status == -1)
  external Pointer<Utf8> errorMessage;
}

/// Result type identifiers (matches AsyncResultType in Rust).
abstract class AsyncResultType {
  static const int singleEmbedding = 0;
  static const int batchEmbedding = 1;
  static const int fileEmbedding = 2;
  static const int modelLoad = 3;
}

/// Async poll status codes.
abstract class AsyncPollStatus {
  /// Operation is still in progress.
  static const int pending = 0;

  /// Operation completed successfully.
  static const int success = 1;

  /// Operation failed with an error.
  static const int error = -1;

  /// Operation was cancelled.
  static const int cancelled = -2;
}
