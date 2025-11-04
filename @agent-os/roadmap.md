# EmbedAnythingInDart Roadmap

## Phase 3: File and Directory Embedding
**Status**: In Progress (Spec Created: 2025-11-03)

Core file and directory embedding functionality.

### Completed
- ✅ Text embedding (`embedText`, `embedTextsBatch`)
- ✅ Basic model loading from HuggingFace
- ✅ Memory management and error handling

### In Progress
- 🔄 File embedding API (`embedFile`)
- 🔄 Directory embedding API (`embedDirectory`)
- 🔄 ChunkEmbedding data structure with metadata
- 🔄 Streaming support for directories

### Deferred (Future Phases)

#### Advanced Chunking Options
These features are supported by the underlying EmbedAnything Rust library but deferred from the initial Phase 3 implementation:

- **Late Chunking**: Considers larger context during chunking for better semantic coherence
  - API: `lateChunking: true` parameter
  - Use case: Better embeddings for documents with long-range dependencies

- **OCR Support**: Extract text from scanned PDFs using Tesseract
  - API: `useOcr: true` and optional `tesseractPath: String` parameters
  - Use case: Processing scanned documents and images

- **Splitting Strategies**: Different approaches to chunk boundary detection
  - Options: `SplittingStrategy.sentence` (default) vs `SplittingStrategy.semantic`
  - Semantic strategy uses embeddings to find natural breakpoints
  - API: `splittingStrategy: SplittingStrategy.semantic` parameter

- **Semantic Encoder for Chunking**: Use a separate model for semantic chunking
  - Allows using a fast model for chunking detection while using a different model for final embeddings
  - API: `semanticEncoder: EmbedAnything` parameter

## Phase 4: Vector Database Adapters (Planned)

Streaming embeddings directly to vector databases.

- Adapter interface design
- Weaviate adapter
- Qdrant adapter
- Pinecone adapter
- Milvus adapter
- Elasticsearch adapter
- In-memory adapter for testing

## Future Features

### Multimodal Support
- Image embedding (CLIP models)
- Audio embedding (Whisper)
- Video embedding

### Additional Model Types
- ONNX runtime support
- ColPali for vision embeddings
- Sparse embeddings (SPLADE)
- Late-interaction embeddings (ColBERT)
- Reranker models

### Platform Support
- Mobile (iOS, Android) via Native Assets
- Web (WASM compilation)

### Performance
- GPU acceleration
- Model quantization options (INT8, Q4)
- Batch optimization

### Cloud Embedding Services
- OpenAI embeddings API
- Cohere embeddings API
- Google Gemini embeddings API

## Contributing

To suggest new features or changes to the roadmap, please create an issue or pull request.
