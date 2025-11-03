/// Base class for all EmbedAnything errors
///
/// This is a sealed class, which means all subtypes are known at compile time
/// and pattern matching can be exhaustive.
///
/// Example:
/// ```dart
/// try {
///   final embedder = EmbedAnything.fromPretrainedHf(
///     model: EmbeddingModel.bert,
///     modelId: 'invalid/model',
///   );
/// } on EmbedAnythingError catch (e) {
///   switch (e) {
///     case ModelNotFoundError():
///       print('Model not found: ${e.modelId}');
///     case InvalidConfigError():
///       print('Invalid config: ${e.field} - ${e.reason}');
///     case EmbeddingFailedError():
///       print('Embedding failed: ${e.reason}');
///     case MultiVectorNotSupportedError():
///       print('Multi-vector embeddings not supported');
///     case FFIError():
///       print('FFI error: ${e.operation}');
///   }
/// }
/// ```
sealed class EmbedAnythingError implements Exception {
  /// The error message
  String get message;

  /// String representation of the error
  @override
  String toString() => 'EmbedAnythingError: $message';
}

/// Error thrown when a model is not found on HuggingFace Hub
///
/// This typically occurs when:
/// - The model ID is incorrect or misspelled
/// - The model doesn't exist on HuggingFace Hub
/// - Network connectivity issues prevent model download
/// - The model requires authentication but no token is provided
///
/// Example:
/// ```dart
/// try {
///   final embedder = EmbedAnything.fromPretrainedHf(
///     model: EmbeddingModel.bert,
///     modelId: 'invalid/model/path',
///   );
/// } on ModelNotFoundError catch (e) {
///   print('Model not found: ${e.modelId}');
///   print('Check the model ID on https://huggingface.co/');
/// }
/// ```
class ModelNotFoundError extends EmbedAnythingError {
  /// The model ID that was not found
  final String modelId;

  /// Creates a new ModelNotFoundError
  ModelNotFoundError(this.modelId);

  @override
  String get message => 'Model not found: $modelId';

  @override
  String toString() => 'ModelNotFoundError: $message';
}

/// Error thrown when model or embedder configuration is invalid
///
/// This occurs when:
/// - Required configuration fields are missing or empty
/// - Configuration values are out of valid range
/// - Incompatible configuration options are used together
///
/// Example:
/// ```dart
/// try {
///   final config = ModelConfig(
///     modelId: '',  // Invalid: empty string
///     modelType: EmbeddingModel.bert,
///   );
///   config.validate();
/// } on InvalidConfigError catch (e) {
///   print('Invalid ${e.field}: ${e.reason}');
/// }
/// ```
class InvalidConfigError extends EmbedAnythingError {
  /// The configuration field that is invalid
  final String field;

  /// The reason why the configuration is invalid
  final String reason;

  /// Creates a new InvalidConfigError
  InvalidConfigError({required this.field, required this.reason});

  @override
  String get message => 'Invalid configuration for $field: $reason';

  @override
  String toString() => 'InvalidConfigError: $message';
}

/// Error thrown when embedding generation fails
///
/// This can occur due to:
/// - Text processing errors (e.g., invalid characters)
/// - Model inference failures
/// - Memory allocation failures during embedding generation
/// - Internal model errors
///
/// Example:
/// ```dart
/// try {
///   final result = embedder.embedText(someText);
/// } on EmbeddingFailedError catch (e) {
///   print('Failed to generate embedding: ${e.reason}');
///   // Consider retrying or using a different text
/// }
/// ```
class EmbeddingFailedError extends EmbedAnythingError {
  /// The reason why embedding generation failed
  final String reason;

  /// Creates a new EmbeddingFailedError
  EmbeddingFailedError({required this.reason});

  @override
  String get message => 'Embedding generation failed: $reason';

  @override
  String toString() => 'EmbeddingFailedError: $message';
}

/// Error thrown when multi-vector embeddings are encountered
///
/// Multi-vector embeddings (e.g., from ColBERT or late-interaction models)
/// are not currently supported in this version of the library.
/// Only dense single-vector embeddings are supported.
///
/// Example:
/// ```dart
/// try {
///   final embedder = EmbedAnything.fromPretrainedHf(
///     model: EmbeddingModel.bert,  // Some models may return multi-vector
///     modelId: 'some-colbert-model',
///   );
///   final result = embedder.embedText('test');
/// } on MultiVectorNotSupportedError catch (e) {
///   print(e.message);
///   // Use a different model that produces dense single vectors
/// }
/// ```
class MultiVectorNotSupportedError extends EmbedAnythingError {
  /// Creates a new MultiVectorNotSupportedError
  MultiVectorNotSupportedError();

  @override
  String get message =>
      'Multi-vector embeddings are not supported in this version. '
      'Please use a model that produces dense single-vector embeddings.';

  @override
  String toString() => 'MultiVectorNotSupportedError: $message';
}

/// Error thrown when an FFI (Foreign Function Interface) operation fails
///
/// This indicates a problem at the boundary between Dart and native code:
/// - Null pointer errors
/// - Invalid memory access
/// - Native function call failures
/// - Rust panic or native crashes (if caught)
///
/// Example:
/// ```dart
/// try {
///   final embedder = EmbedAnything.fromPretrainedHf(
///     model: EmbeddingModel.bert,
///     modelId: 'sentence-transformers/all-MiniLM-L6-v2',
///   );
/// } on FFIError catch (e) {
///   print('FFI operation failed: ${e.operation}');
///   if (e.nativeError != null) {
///     print('Native error: ${e.nativeError}');
///   }
/// }
/// ```
class FFIError extends EmbedAnythingError {
  /// The FFI operation that failed
  final String operation;

  /// Optional native error message from Rust/C side
  final String? nativeError;

  /// Creates a new FFIError
  FFIError({required this.operation, this.nativeError});

  @override
  String get message =>
      'FFI operation failed: $operation${nativeError != null ? " - $nativeError" : ""}';

  @override
  String toString() => 'FFIError: $message';
}
