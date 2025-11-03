# Product Roadmap

## Phase 1: Core Text Embedding (Current - Foundation)

1. [x] Fix Rust FFI Return Type Compatibility - Update `embed_query()` and `embed()` to properly extract vectors from EmbedData/EmbeddingResult enum returned by EmbedAnything `S`
2. [x] Comprehensive Test Coverage - Expand test suite to cover edge cases, error conditions, and memory leak detection with realistic workloads `S`
3. [x] API Documentation - Generate dartdoc with comprehensive API documentation, usage examples, and troubleshooting guides for all public APIs `S`
4. [x] Performance Benchmarking - Establish baseline performance metrics for single/batch embedding operations across different model sizes and text lengths `M`
5. [x] Model Configuration API - Add support for custom HuggingFace models with configurable parameters (dtype, revision, normalization options) `M`

## Phase 2: Production Readiness

6. [ ] iOS Platform Support - Add iOS target with proper staticlib configuration, test on physical devices, and optimize for mobile performance constraints `L`
7. [ ] Android Platform Support - Implement Android NDK integration with proper JNI bindings, test across ARM/x86 architectures, and optimize APK size `L`
8. [ ] Async/Isolate Integration - Wrap blocking embedding calls with compute() or custom isolates to prevent UI freezing in Flutter applications `M`
9. [ ] Error Recovery - Implement retry logic for model downloads, graceful fallback for corrupted caches, and detailed error messages with remediation steps `S`
10. [ ] CI/CD Pipeline - Set up GitHub Actions to test across all platforms (macOS, Linux, Windows, iOS simulator, Android emulator) on every commit `M`

## Phase 3: Multi-Modal Expansion

11. [ ] Document Embedding - Implement PDF, DOCX, and Markdown file parsing with chunk extraction and embedding generation for RAG use cases `L`
12. [ ] Image Embedding - Integrate CLIP models for image-to-vector embeddings with support for semantic image search and visual similarity `XL`
13. [ ] Audio Embedding - Add Whisper-based audio transcription and embedding for voice search and audio content analysis `XL`
14. [ ] Multi-Modal Query API - Unified search API allowing text queries against image/audio embeddings and vice versa for cross-modal retrieval `L`

## Phase 4: Optimization & Scaling

15. [ ] ONNX Runtime Backend - Integrate ONNX runtime as alternative backend for faster inference on mobile devices and reduced memory footprint `XL`
16. [ ] Model Quantization - Support for quantized models (int8, int4) to reduce model size by 75% for mobile deployment `L`
17. [ ] Streaming Batch Processing - Implement streaming API for processing large document collections with backpressure control and progress callbacks `M`
18. [ ] Model Preloading - Add warm-start API to preload models during app initialization for zero-latency first embedding `S`
19. [ ] Vector Database Adapters - Built-in adapters for Pinecone, Weaviate, Qdrant with automatic batching and connection pooling `XL`

## Phase 5: Enterprise Features

20. [ ] Cloud API Fallback - Optional adapters for OpenAI, Cohere, and other cloud providers when local processing is unavailable or insufficient `M`
21. [ ] Custom Model Training - Support for fine-tuned models with local ONNX export from training pipelines `XL`
22. [ ] Embedding Cache Layer - Intelligent caching of computed embeddings with LRU eviction and persistence to reduce redundant computation `M`
23. [ ] Telemetry & Monitoring - Optional metrics collection for embedding latency, model performance, and resource usage to identify bottlenecks `M`

> Notes
> - Phase 1 COMPLETE - All core text embedding functionality implemented and tested
> - iOS/Android support (Phase 2) required before Phase 3 multi-modal features reach mobile users
> - ONNX integration (Phase 4) provides significant performance wins but requires substantial backend refactoring
> - Prioritization balances technical dependencies (FFI fixes before new features) with user value (mobile support, multi-modal)
> - Each phase delivers independently valuable capabilities while building toward comprehensive multi-modal embedding platform
