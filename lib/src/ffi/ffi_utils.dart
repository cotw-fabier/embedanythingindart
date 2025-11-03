import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../errors.dart';
import 'bindings.dart';

/// Convert a Dart String to a C string (`Pointer<Utf8>`)
///
/// The caller is responsible for freeing the returned pointer using [freeCString].
Pointer<Utf8> stringToCString(String str) {
  return str.toNativeUtf8();
}

/// Convert a C string (`Pointer<Utf8>`) to a Dart String
///
/// Throws ArgumentError if ptr is null.
String cStringToDartString(Pointer<Utf8> ptr) {
  if (ptr == nullptr) {
    throw ArgumentError.notNull('ptr');
  }
  return ptr.toDartString();
}

/// Free a C string allocated by Dart
void freeCString(Pointer<Utf8> ptr) {
  if (ptr != nullptr) {
    malloc.free(ptr);
  }
}

/// Execute a callback with a C string, ensuring proper cleanup
///
/// The C string is automatically freed after the callback completes.
///
/// Example:
/// ```dart
/// final result = withCString('hello', (ptr) => nativeFunction(ptr));
/// ```
T withCString<T>(String str, T Function(Pointer<Utf8>) callback) {
  final ptr = stringToCString(str);
  try {
    return callback(ptr);
  } finally {
    freeCString(ptr);
  }
}

/// Get the last error message from Rust
///
/// Returns null if no error occurred.
/// Automatically frees the error string.
String? getLastErrorMessage() {
  final errorPtr = getLastError();
  if (errorPtr == nullptr) {
    return null;
  }

  try {
    return cStringToDartString(errorPtr);
  } finally {
    freeErrorString(errorPtr);
  }
}

/// Parse error message and determine error type based on prefix
///
/// Error messages from Rust are prefixed with type indicators:
/// - "MODEL_NOT_FOUND:" -> ModelNotFoundError
/// - "INVALID_CONFIG:" -> InvalidConfigError
/// - "EMBEDDING_FAILED:" -> EmbeddingFailedError
/// - "MULTI_VECTOR:" -> MultiVectorNotSupportedError
/// - "FFI_ERROR:" -> FFIError
///
/// If no prefix is found, returns FFIError as fallback.
EmbedAnythingError _parseError(String errorMessage, String operation) {
  if (errorMessage.startsWith('MODEL_NOT_FOUND:')) {
    final modelId = errorMessage.substring('MODEL_NOT_FOUND:'.length).trim();
    return ModelNotFoundError(modelId);
  } else if (errorMessage.startsWith('INVALID_CONFIG:')) {
    final parts = errorMessage.substring('INVALID_CONFIG:'.length).trim();
    // Expected format: "field=value: reason"
    final colonIndex = parts.indexOf(':');
    if (colonIndex != -1) {
      final field = parts.substring(0, colonIndex).trim();
      final reason = parts.substring(colonIndex + 1).trim();
      return InvalidConfigError(field: field, reason: reason);
    } else {
      return InvalidConfigError(field: 'unknown', reason: parts);
    }
  } else if (errorMessage.startsWith('EMBEDDING_FAILED:')) {
    final reason = errorMessage.substring('EMBEDDING_FAILED:'.length).trim();
    return EmbeddingFailedError(reason: reason);
  } else if (errorMessage.startsWith('MULTI_VECTOR:')) {
    return MultiVectorNotSupportedError();
  } else if (errorMessage.startsWith('FFI_ERROR:')) {
    final nativeError =
        errorMessage.substring('FFI_ERROR:'.length).trim();
    return FFIError(operation: operation, nativeError: nativeError);
  } else {
    // Fallback: treat as FFI error with the full message
    return FFIError(operation: operation, nativeError: errorMessage);
  }
}

/// Throw a typed exception with the last error message from Rust
///
/// Parses the error message from Rust and throws the appropriate
/// typed error based on the error prefix.
///
/// Parameters:
/// - [operation]: Description of the operation that failed (e.g., 'Failed to load model')
/// - [defaultMessage]: Fallback message if no error is available
///
/// Throws one of:
/// - [ModelNotFoundError] - Model not found on HuggingFace Hub
/// - [InvalidConfigError] - Invalid configuration parameters
/// - [EmbeddingFailedError] - Embedding generation failed
/// - [MultiVectorNotSupportedError] - Multi-vector embeddings not supported
/// - [FFIError] - Generic FFI operation failure
Never throwLastError(
    [String operation = 'Operation failed', String? defaultMessage]) {
  final errorMessage = getLastErrorMessage();

  if (errorMessage == null) {
    throw FFIError(
      operation: operation,
      nativeError: defaultMessage ?? 'Unknown error',
    );
  }

  throw _parseError(errorMessage, operation);
}

/// Legacy exception type for backward compatibility
///
/// @deprecated Use typed errors (ModelNotFoundError, etc.) instead
class EmbedAnythingException implements Exception {
  final String message;

  EmbedAnythingException(this.message);

  @override
  String toString() => 'EmbedAnythingException: $message';
}
