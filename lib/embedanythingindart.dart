/// EmbedAnythingInDart: Dart wrapper for the EmbedAnything embedding library
///
/// This library provides high-performance vector embeddings for text and files using
/// models from HuggingFace Hub. It supports BERT and Jina embedding models
/// with automatic memory management via FFI bindings to Rust.
///
/// Features:
/// - Text embedding with single or batch operations
/// - File embedding with automatic chunking (PDF, TXT, MD, DOCX, HTML)
/// - Directory embedding with streaming results
/// - Cosine similarity utilities
/// - **Async operations** for non-blocking Flutter UI (embedTextAsync, etc.)
/// - **Cancellable operations** via AsyncEmbeddingOperation
/// - **GPU acceleration** - Metal (macOS), CUDA (Linux/Windows), with CPU fallback
///
/// GPU acceleration is automatically enabled based on platform and available hardware:
/// - macOS/iOS: Metal GPU + Accelerate CPU optimization
/// - Linux/Windows: CUDA GPU (if toolkit installed) + MKL CPU optimization
///
/// Use [EmbedAnything.getActiveDevice] to check which device is being used.
library;

export 'src/chunk_embedding.dart';
export 'src/embedder.dart';
export 'src/embedding_result.dart';
export 'src/errors.dart';
export 'src/model_config.dart';
export 'src/models.dart';
