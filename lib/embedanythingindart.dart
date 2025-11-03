/// EmbedAnythingInDart: Dart wrapper for the EmbedAnything embedding library
///
/// This library provides high-performance vector embeddings for text using
/// models from HuggingFace Hub. It supports BERT and Jina embedding models
/// with automatic memory management via FFI bindings to Rust.
library;

export 'src/embedder.dart';
export 'src/embedding_result.dart';
export 'src/errors.dart';
export 'src/model_config.dart';
export 'src/models.dart';
