import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../errors.dart';
import 'bindings.dart';
import 'native_types.dart';

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
/// - "FILE_NOT_FOUND:" -> FileNotFoundError (Phase 3)
/// - "UNSUPPORTED_FORMAT:" -> UnsupportedFileFormatError (Phase 3)
/// - "FILE_READ_ERROR:" -> FileReadError (Phase 3)
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
  } else if (errorMessage.startsWith('FILE_NOT_FOUND:')) {
    final path = errorMessage.substring('FILE_NOT_FOUND:'.length).trim();
    return FileNotFoundError(path);
  } else if (errorMessage.startsWith('UNSUPPORTED_FORMAT:')) {
    // Expected format: "UNSUPPORTED_FORMAT: extension for /path/to/file"
    final parts = errorMessage.substring('UNSUPPORTED_FORMAT:'.length).trim();
    final forIndex = parts.indexOf(' for ');
    if (forIndex != -1) {
      final extension = parts.substring(0, forIndex).trim();
      final path = parts.substring(forIndex + 5).trim();
      return UnsupportedFileFormatError(path: path, extension: extension);
    } else {
      // Fallback: use the whole message as path with unknown extension
      return UnsupportedFileFormatError(path: parts, extension: 'unknown');
    }
  } else if (errorMessage.startsWith('FILE_READ_ERROR:')) {
    // Expected format: "FILE_READ_ERROR: /path/to/file: reason"
    final parts = errorMessage.substring('FILE_READ_ERROR:'.length).trim();
    final colonIndex = parts.indexOf(':', 1); // Start from 1 to skip potential drive letter on Windows
    if (colonIndex != -1) {
      final path = parts.substring(0, colonIndex).trim();
      final reason = parts.substring(colonIndex + 1).trim();
      return FileReadError(path: path, reason: reason);
    } else {
      return FileReadError(path: parts, reason: 'Unknown error');
    }
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
/// - [FileNotFoundError] - File or directory not found (Phase 3)
/// - [UnsupportedFileFormatError] - File format not supported (Phase 3)
/// - [FileReadError] - File I/O error (Phase 3)
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

// ============================================================================
// Phase 3 Helper Functions - File Embedding FFI Utilities
// ============================================================================

/// Allocate a CTextEmbedConfig struct from Dart parameters
///
/// The caller is responsible for freeing the returned pointer using calloc.free().
///
/// Example:
/// ```dart
/// final config = allocateTextEmbedConfig(
///   chunkSize: 1000,
///   overlapRatio: 0.1,
///   batchSize: 32,
///   bufferSize: 100,
/// );
/// try {
///   // Use config...
/// } finally {
///   calloc.free(config);
/// }
/// ```
Pointer<CTextEmbedConfig> allocateTextEmbedConfig({
  required int chunkSize,
  required double overlapRatio,
  required int batchSize,
  required int bufferSize,
}) {
  final config = calloc<CTextEmbedConfig>();
  config.ref.chunkSize = chunkSize;
  config.ref.overlapRatio = overlapRatio;
  config.ref.batchSize = batchSize;
  config.ref.bufferSize = bufferSize;
  return config;
}

/// Parse metadata JSON string to `Map<String, String>`
///
/// Returns null if:
/// - The JSON string is null
/// - The JSON string is empty
/// - The JSON parsing fails
/// - The parsed JSON is not a `Map<String, dynamic>`
///
/// Example:
/// ```dart
/// final metadata = parseMetadataJson('{"file_path":"/test/file.txt","page":"5"}');
/// print(metadata?['file_path']); // "/test/file.txt"
/// ```
Map<String, String>? parseMetadataJson(String? jsonString) {
  if (jsonString == null || jsonString.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(jsonString);
    if (decoded is Map) {
      // Convert all values to strings
      return decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    return null;
  } catch (e) {
    // Invalid JSON
    return null;
  }
}

/// Allocate a NULL-terminated array of Utf8 strings
///
/// The caller is responsible for freeing the array using [freeStringArray].
///
/// Example:
/// ```dart
/// final extensions = ['.txt', '.pdf', '.md'];
/// final arrayPtr = allocateStringArray(extensions);
/// try {
///   // Use arrayPtr...
/// } finally {
///   freeStringArray(arrayPtr, extensions.length);
/// }
/// ```
Pointer<Pointer<Utf8>> allocateStringArray(List<String> strings) {
  // Allocate array with extra slot for NULL terminator
  final arrayPtr = calloc<Pointer<Utf8>>(strings.length + 1);

  // Allocate and copy each string
  for (var i = 0; i < strings.length; i++) {
    arrayPtr[i] = stringToCString(strings[i]);
  }

  // NULL terminator
  arrayPtr[strings.length] = nullptr;

  return arrayPtr;
}

/// Free a NULL-terminated array of Utf8 strings
///
/// Frees all individual strings and the array itself.
/// Safe to call with nullptr.
///
/// Parameters:
/// - [arrayPtr]: Pointer to the string array
/// - [count]: Number of strings (excluding NULL terminator)
void freeStringArray(Pointer<Pointer<Utf8>> arrayPtr, int count) {
  if (arrayPtr == nullptr) {
    return;
  }

  // Free each string
  for (var i = 0; i < count; i++) {
    if (arrayPtr[i] != nullptr) {
      freeCString(arrayPtr[i]);
    }
  }

  // Free the array itself
  calloc.free(arrayPtr);
}

// NOTE: cEmbedDataToChunkEmbedding() conversion function will be implemented
// by the ui-designer (Task Group 3) in embedder.dart, as it depends on the
// ChunkEmbedding class which is part of the high-level API. The ui-designer
// will use the helper functions above (parseMetadataJson, etc.) to build
// ChunkEmbedding instances from CEmbedData structs.

/// Legacy exception type for backward compatibility
///
/// @deprecated Use typed errors (ModelNotFoundError, etc.) instead
class EmbedAnythingException implements Exception {
  final String message;

  EmbedAnythingException(this.message);

  @override
  String toString() => 'EmbedAnythingException: $message';
}
