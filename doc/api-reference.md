# API Reference

Complete API documentation for EmbedAnythingInDart library classes, methods, and types.

---

## Table of Contents

- [EmbedAnything Class](#embedanything-class)
  - [Factory Methods](#factory-methods)
  - [Instance Methods](#instance-methods)
  - [Properties](#properties)
- [EmbeddingResult Class](#embeddingresult-class)
- [ChunkEmbedding Class](#chunkembedding-class)
- [ModelConfig Class](#modelconfig-class)
  - [Constructor](#modelconfig-constructor)
  - [Factory Methods](#modelconfig-factory-methods)
  - [Instance Methods](#modelconfig-instance-methods)
  - [Properties](#modelconfig-properties)
- [Enums](#enums)
  - [EmbeddingModel](#embeddingmodel-enum)
  - [ModelDtype](#modeldtype-enum)
- [Error Classes](#error-classes)

---

## EmbedAnything Class

High-level interface to EmbedAnything embedding models. Provides a convenient Dart API for generating embeddings using various models from HuggingFace Hub with automatic FFI memory management.

> **⚠️ Important:** You MUST call `dispose()` when done using an embedder to prevent memory leaks.

### Factory Methods

#### fromConfig()

Creates an embedder from a model configuration. This is the recommended way to create an embedder as it provides full control over model loading parameters.

**Signature:**
```dart
factory EmbedAnything.fromConfig(ModelConfig config)
```

**Parameters:**
- `config` (ModelConfig): Model configuration object containing model ID, type, revision, dtype, normalization, and batch size settings.

**Returns:**
- `EmbedAnything`: A new embedder instance.

**Throws:**
- `InvalidConfigError`: If configuration is invalid (e.g., empty model ID, invalid batch size).
- `ModelNotFoundError`: If model doesn't exist on HuggingFace Hub.
- `FFIError`: If model loading fails at the native layer.

**Example:**
```dart
// Use predefined configuration
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

// Or create custom configuration
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,
  defaultBatchSize: 64,
);
final embedder = EmbedAnything.fromConfig(config);

try {
  final result = embedder.embedText('Hello, world!');
  print('Dimension: ${result.dimension}');
} finally {
  embedder.dispose();
}
```

---

#### fromPretrainedHf()

Creates an embedder from a pretrained HuggingFace model. This is a convenience method that creates a ModelConfig internally and calls `fromConfig()`.

**Signature:**
```dart
factory EmbedAnything.fromPretrainedHf({
  required EmbeddingModel model,
  required String modelId,
  String revision = 'main',
})
```

**Parameters:**
- `model` (EmbeddingModel): The model architecture (bert or jina).
- `modelId` (String): HuggingFace model identifier (e.g., 'sentence-transformers/all-MiniLM-L6-v2').
- `revision` (String, optional): Git revision/branch/tag (defaults to 'main').

**Returns:**
- `EmbedAnything`: A new embedder instance.

**Throws:**
- `ModelNotFoundError`: If model doesn't exist on HuggingFace Hub.
- `FFIError`: If model loading fails.

**Common Model IDs:**
- BERT: `sentence-transformers/all-MiniLM-L6-v2` (384 dimensions)
- BERT: `sentence-transformers/all-MiniLM-L12-v2` (384 dimensions)
- Jina: `jinaai/jina-embeddings-v2-small-en` (512 dimensions)
- Jina: `jinaai/jina-embeddings-v2-base-en` (768 dimensions)

**Example:**
```dart
final embedder = EmbedAnything.fromPretrainedHf(
  model: EmbeddingModel.bert,
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
);

try {
  final result = embedder.embedText('Natural language processing');
  print('Embedding: ${result.dimension}D vector');
} finally {
  embedder.dispose();
}
```

---

### Instance Methods

#### embedText()

Generates an embedding for a single text. Converts the input text into a dense vector representation that captures its semantic meaning.

**Signature:**
```dart
EmbeddingResult embedText(String text)
```

**Parameters:**
- `text` (String): The text to embed.

**Returns:**
- `EmbeddingResult`: The embedding result containing the dense vector.

**Throws:**
- `EmbeddingFailedError`: If embedding generation fails.
- `StateError`: If the embedder has been disposed.

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final result = embedder.embedText('Hello, world!');
  print('Dimension: ${result.dimension}');
  print('First 5 values: ${result.values.take(5)}');
} finally {
  embedder.dispose();
}
```

---

#### embedTextsBatch()

Generates embeddings for multiple texts in a batch. This is significantly more efficient than calling `embedText()` multiple times (typically 5-10x faster for batches of 50+ items).

**Signature:**
```dart
List<EmbeddingResult> embedTextsBatch(List<String> texts)
```

**Parameters:**
- `texts` (List\<String\>): List of texts to embed.

**Returns:**
- `List<EmbeddingResult>`: List of embedding results, one for each input text in the same order.

**Throws:**
- `EmbeddingFailedError`: If embedding generation fails.
- `StateError`: If the embedder has been disposed.

**Performance Note:**
Batch processing processes texts in parallel on the Rust side and reduces FFI overhead.

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final texts = ['First text', 'Second text', 'Third text'];
  final results = embedder.embedTextsBatch(texts);

  for (var i = 0; i < texts.length; i++) {
    print('Text: ${texts[i]}');
    print('Dimension: ${results[i].dimension}');
  }
} finally {
  embedder.dispose();
}
```

---

#### embedFile()

Embeds a single file with automatic chunking. Processes a document file and returns all text chunks with their embeddings and metadata.

**Signature:**
```dart
Future<List<ChunkEmbedding>> embedFile(
  String filePath, {
  int chunkSize = 1000,
  double overlapRatio = 0.0,
  int batchSize = 32,
})
```

**Parameters:**
- `filePath` (String): Path to the file to embed.
- `chunkSize` (int, optional): Maximum characters per chunk (default: 1000).
- `overlapRatio` (double, optional): Overlap between chunks 0.0-1.0 (default: 0.0).
- `batchSize` (int, optional): Batch size for embedding generation (default: 32).

**Returns:**
- `Future<List<ChunkEmbedding>>`: A Future that completes with a list of ChunkEmbeddings, one for each chunk of the file. Each chunk includes the embedding, text content, and metadata (file path, chunk index, page number for PDFs).

**Throws:**
- `FileNotFoundError`: If the file does not exist.
- `UnsupportedFileFormatError`: If the file format is not supported.
- `FileReadError`: If there's a permission or I/O error reading the file.
- `EmbeddingFailedError`: If embedding generation fails.
- `StateError`: If the embedder has been disposed.

**Supported File Formats:**
PDF, TXT, MD, DOCX, HTML

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final chunks = await embedder.embedFile(
    'document.pdf',
    chunkSize: 500,
    overlapRatio: 0.1,
  );

  for (final chunk in chunks) {
    print('File: ${chunk.filePath}');
    print('Page: ${chunk.page}');
    print('Chunk ${chunk.chunkIndex}: ${chunk.text?.substring(0, 50)}...');
  }
} finally {
  embedder.dispose();
}
```

---

#### embedDirectory()

Embeds all files in a directory (streaming). Processes all files in a directory and returns a Stream that yields ChunkEmbeddings as they are generated. This allows processing large directories without loading all embeddings into memory at once.

**Signature:**
```dart
Stream<ChunkEmbedding> embedDirectory(
  String directoryPath, {
  List<String>? extensions,
  int chunkSize = 1000,
  double overlapRatio = 0.0,
  int batchSize = 32,
})
```

**Parameters:**
- `directoryPath` (String): Path to the directory to embed.
- `extensions` (List\<String\>?, optional): Optional list of file extensions to include (e.g., ['.pdf', '.txt']). If null, all supported file types will be processed.
- `chunkSize` (int, optional): Maximum characters per chunk (default: 1000).
- `overlapRatio` (double, optional): Overlap between chunks 0.0-1.0 (default: 0.0).
- `batchSize` (int, optional): Batch size for embedding generation (default: 32).

**Returns:**
- `Stream<ChunkEmbedding>`: A Stream of ChunkEmbeddings that yields results incrementally as files are processed.

**Throws:**
- `FileNotFoundError`: If the directory does not exist.
- `FileReadError`: If there's a permission error accessing the directory.

**Stream Errors:**
Individual file processing errors are emitted to the stream but don't stop processing of other files.

**Supported File Formats:**
PDF, TXT, MD, DOCX, HTML

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  await for (final chunk in embedder.embedDirectory(
    'documents/',
    extensions: ['.pdf', '.txt'],
  )) {
    print('Processing ${chunk.filePath}: chunk ${chunk.chunkIndex}');
    // Process chunk immediately without storing all in memory
  }
} finally {
  embedder.dispose();
}
```

---

#### dispose()

Manually disposes of the embedder and releases native resources immediately. After calling this, the embedder cannot be used and any method calls will throw a StateError.

**Signature:**
```dart
void dispose()
```

**Returns:**
- void

**Important:**
- You MUST call this method to prevent memory leaks
- This method is idempotent - calling it multiple times is safe
- Always use try-finally to ensure cleanup

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final result = embedder.embedText('test');
  // Use result...
} finally {
  embedder.dispose(); // Ensure cleanup
}
```

---

### Properties

#### config

Gets the configuration used to create this embedder.

**Signature:**
```dart
ModelConfig? get config
```

**Returns:**
- `ModelConfig?`: The configuration object, or null if the embedder was created before ModelConfig support was added.

**Example:**
```dart
final config = ModelConfig.bertMiniLML6();
final embedder = EmbedAnything.fromConfig(config);

try {
  print('Model ID: ${embedder.config?.modelId}');
  print('Model Type: ${embedder.config?.modelType}');
  print('Dtype: ${embedder.config?.dtype}');
} finally {
  embedder.dispose();
}
```

---

## EmbeddingResult Class

Result of an embedding operation. Contains the dense vector embedding as a list of doubles representing the semantic meaning of the input text.

The vectors are typically normalized to unit length, making them suitable for direct cosine similarity comparisons.

### Constructor

**Signature:**
```dart
const EmbeddingResult(List<double> values)
```

**Parameters:**
- `values` (List\<double\>): The embedding vector. Should not be empty and typically contains normalized floating-point numbers.

**Example:**
```dart
final embedding = EmbeddingResult([0.1, 0.2, 0.3, 0.4]);
print('Dimension: ${embedding.dimension}');
```

---

### Properties

#### values

The embedding vector as a list of doubles.

**Signature:**
```dart
final List<double> values
```

The length of this list equals the embedding dimension, which depends on the model used:
- BERT all-MiniLM-L6-v2: 384 dimensions
- BERT all-MiniLM-L12-v2: 384 dimensions
- Jina v2-small-en: 512 dimensions
- Jina v2-base-en: 768 dimensions

**Example:**
```dart
final result = embedder.embedText('Hello');
print('Vector values: ${result.values}');
print('First value: ${result.values.first}');
```

---

#### dimension

The dimensionality of the embedding. This is the length of the values vector and depends on the model architecture.

**Signature:**
```dart
int get dimension
```

**Returns:**
- `int`: The number of dimensions in the embedding vector.

**Example:**
```dart
final result = embedder.embedText('Hello');
print('Dimension: ${result.dimension}'); // e.g., 384 for BERT MiniLM-L6
```

---

### Methods

#### cosineSimilarity()

Computes cosine similarity with another embedding. Returns a value between -1 and 1 indicating semantic similarity.

**Signature:**
```dart
double cosineSimilarity(EmbeddingResult other)
```

**Parameters:**
- `other` (EmbeddingResult): The embedding to compare with.

**Returns:**
- `double`: Similarity score between -1 and 1:
  - **1.0**: Embeddings are identical (maximum similarity)
  - **0.0**: Embeddings are orthogonal (no similarity)
  - **-1.0**: Embeddings are opposite (maximum dissimilarity)

**Throws:**
- `ArgumentError`: If the embeddings have different dimensions.

**Note:**
In practice, similarity scores for natural language are typically in the range [0.0, 1.0], with higher values indicating greater semantic similarity.

**Performance:**
This operation is O(n) where n is the dimension. For typical embedding dimensions (384-768), this completes in microseconds.

**Example:**
```dart
final emb1 = embedder.embedText('I love machine learning');
final emb2 = embedder.embedText('Machine learning is great');
final emb3 = embedder.embedText('I enjoy cooking pasta');

final sim12 = emb1.cosineSimilarity(emb2);
final sim13 = emb1.cosineSimilarity(emb3);

print('Related texts similarity: ${sim12.toStringAsFixed(4)}');
// Output: Related texts similarity: 0.8742

print('Unrelated texts similarity: ${sim13.toStringAsFixed(4)}');
// Output: Unrelated texts similarity: 0.2156
```

---

#### toString()

Returns a string representation of the embedding for debugging.

**Signature:**
```dart
String toString()
```

**Returns:**
- `String`: A string showing the dimension and a preview of the first 5 values.

**Example:**
```dart
final result = embedder.embedText('Hello');
print(result.toString());
// Output: EmbeddingResult(dimension: 384, preview: [0.123, 0.456, -0.789, 0.234, -0.567...])
```

---

#### operator ==

Compares two embeddings for equality. Two embeddings are considered equal if they have the same dimension and all values match within a tolerance of 1e-6.

**Signature:**
```dart
bool operator ==(Object other)
```

**Parameters:**
- `other` (Object): The object to compare with.

**Returns:**
- `bool`: True if the embeddings are equal within tolerance, false otherwise.

**Example:**
```dart
final emb1 = embedder.embedText('Hello');
final emb2 = embedder.embedText('Hello');
print(emb1 == emb2); // true (same text produces same embedding)
```

---

#### hashCode

Returns a hash code for the embedding.

**Signature:**
```dart
int get hashCode
```

**Returns:**
- `int`: Hash code computed from the embedding values.

---

## ChunkEmbedding Class

Result of embedding a text chunk from a file. Contains the embedding vector, the original text chunk, and metadata about the source (file path, page, chunk index).

This is returned by `EmbedAnything.embedFile()` and `EmbedAnything.embedDirectory()` when embedding document files.

### Constructor

**Signature:**
```dart
const ChunkEmbedding({
  required EmbeddingResult embedding,
  String? text,
  Map<String, String>? metadata,
})
```

**Parameters:**
- `embedding` (EmbeddingResult, required): The embedding vector for this chunk.
- `text` (String?, optional): The text content of this chunk.
- `metadata` (Map\<String, String\>?, optional): Metadata dictionary with file path, chunk index, page number, etc.

**Example:**
```dart
final embedding = EmbeddingResult([1.0, 2.0, 3.0]);
final chunk = ChunkEmbedding(
  embedding: embedding,
  text: 'This is a text chunk.',
  metadata: {
    'file_path': '/docs/file.txt',
    'chunk_index': '0',
  },
);
```

---

### Properties

#### embedding

The embedding vector for this chunk.

**Signature:**
```dart
final EmbeddingResult embedding
```

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
print('Dimension: ${chunks.first.embedding.dimension}');
```

---

#### text

The text content of this chunk. May be null if text extraction failed or was not available.

**Signature:**
```dart
final String? text
```

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
for (final chunk in chunks) {
  print('Text: ${chunk.text ?? "No text"}');
}
```

---

#### metadata

Metadata dictionary with file path, chunk index, page number, and other information.

**Signature:**
```dart
final Map<String, String>? metadata
```

**Common Metadata Keys:**
- `file_path`: Path to the source file
- `page_number`: Page number (for PDFs)
- `chunk_index`: Index of this chunk within the document
- `heading`: Section heading (for structured documents)

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
for (final chunk in chunks) {
  if (chunk.metadata != null) {
    print('Metadata: ${chunk.metadata}');
  }
}
```

---

#### filePath

Convenience getter for file path from metadata. Returns the value of the `file_path` key in metadata, or null if metadata is null or the key doesn't exist.

**Signature:**
```dart
String? get filePath
```

**Returns:**
- `String?`: The file path, or null if not available.

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
for (final chunk in chunks) {
  print('Source: ${chunk.filePath ?? "unknown"}');
}
```

---

#### page

Convenience getter for page number from metadata (PDFs). Returns the integer value of the `page_number` key in metadata, or null if metadata is null, the key doesn't exist, or the value cannot be parsed as an integer.

**Signature:**
```dart
int? get page
```

**Returns:**
- `int?`: The page number, or null if not available.

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
for (final chunk in chunks) {
  if (chunk.page != null) {
    print('Found on page ${chunk.page}');
  }
}
```

---

#### chunkIndex

Convenience getter for chunk index from metadata. Returns the integer value of the `chunk_index` key in metadata, or null if metadata is null, the key doesn't exist, or the value cannot be parsed as an integer.

**Signature:**
```dart
int? get chunkIndex
```

**Returns:**
- `int?`: The chunk index, or null if not available.

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
for (final chunk in chunks) {
  print('Chunk #${chunk.chunkIndex ?? 0}');
}
```

---

### Methods

#### cosineSimilarity()

Computes cosine similarity with another chunk's embedding. This is a convenience method that delegates to `EmbeddingResult.cosineSimilarity()`.

**Signature:**
```dart
double cosineSimilarity(ChunkEmbedding other)
```

**Parameters:**
- `other` (ChunkEmbedding): The chunk to compare with.

**Returns:**
- `double`: Similarity score between -1 and 1, where higher values indicate greater semantic similarity.

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
final query = chunks.first;

// Find most similar chunk
double maxSim = -1;
ChunkEmbedding? mostSimilar;

for (final chunk in chunks.skip(1)) {
  final sim = query.cosineSimilarity(chunk);
  if (sim > maxSim) {
    maxSim = sim;
    mostSimilar = chunk;
  }
}

print('Most similar chunk has similarity: $maxSim');
```

---

#### toString()

Returns a string representation for debugging. Shows a preview of the text, embedding dimension, and metadata.

**Signature:**
```dart
String toString()
```

**Returns:**
- `String`: A debug string with text preview (truncated to 50 chars), dimension, and metadata.

**Example:**
```dart
final chunks = await embedder.embedFile('document.pdf');
print(chunks.first.toString());
// Output: ChunkEmbedding(text: "This is the beginning of the document...", embedding: 384D, metadata: {file_path: /docs/file.pdf, chunk_index: 0})
```

---

## ModelConfig Class

Configuration for loading embedding models from HuggingFace Hub. Provides a flexible way to configure model loading with sensible defaults while allowing customization for advanced use cases.

### ModelConfig Constructor

Creates a new ModelConfig with required and optional parameters.

**Signature:**
```dart
const ModelConfig({
  required String modelId,
  required EmbeddingModel modelType,
  String revision = 'main',
  ModelDtype dtype = ModelDtype.f32,
  bool normalize = true,
  int defaultBatchSize = 32,
})
```

**Parameters:**
- `modelId` (String, required): HuggingFace model identifier (e.g., 'sentence-transformers/all-MiniLM-L6-v2'). The model will be downloaded and cached on first use.
- `modelType` (EmbeddingModel, required): Model architecture type (bert or jina).
- `revision` (String, optional): Git revision (branch, tag, or commit hash). Defaults to 'main'. Can be used to pin to a specific model version.
- `dtype` (ModelDtype, optional): Data type for model weights. Defaults to f32 (full precision). Use f16 for faster inference with slightly reduced quality.
- `normalize` (bool, optional): Whether to normalize embeddings to unit length. Defaults to true. Normalized embeddings are suitable for cosine similarity comparisons.
- `defaultBatchSize` (int, optional): Default batch size for batch operations. Defaults to 32. Larger batch sizes are more efficient but require more memory.

**Throws:**
- `InvalidConfigError`: During validation if parameters are invalid.

**Example:**
```dart
// Basic configuration
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
);

// Advanced configuration
final customConfig = ModelConfig(
  modelId: 'jinaai/jina-embeddings-v2-base-en',
  modelType: EmbeddingModel.jina,
  revision: 'v1.0',
  dtype: ModelDtype.f16,
  normalize: true,
  defaultBatchSize: 64,
);

final embedder = EmbedAnything.fromConfig(customConfig);
```

---

### ModelConfig Factory Methods

#### bertMiniLML6()

Predefined configuration for BERT all-MiniLM-L6-v2. This is a lightweight 384-dimensional BERT model suitable for most general-purpose semantic similarity tasks.

**Signature:**
```dart
factory ModelConfig.bertMiniLML6()
```

**Model Details:**
- **Dimensions:** 384
- **Speed:** Fast
- **Quality:** Good
- **Use case:** General purpose

**Returns:**
- `ModelConfig`: Configuration for BERT MiniLM-L6-v2.

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
try {
  final result = embedder.embedText('Hello');
  print('Dimension: ${result.dimension}'); // 384
} finally {
  embedder.dispose();
}
```

---

#### bertMiniLML12()

Predefined configuration for BERT all-MiniLM-L12-v2. This is a slightly larger 384-dimensional BERT model with 12 layers instead of 6, providing better quality at the cost of slower inference.

**Signature:**
```dart
factory ModelConfig.bertMiniLML12()
```

**Model Details:**
- **Dimensions:** 384
- **Speed:** Medium
- **Quality:** Better
- **Use case:** When quality is more important than speed

**Returns:**
- `ModelConfig`: Configuration for BERT MiniLM-L12-v2.

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML12());
try {
  final result = embedder.embedText('High quality embedding');
  print('Dimension: ${result.dimension}'); // 384
} finally {
  embedder.dispose();
}
```

---

#### jinaV2Small()

Predefined configuration for Jina v2-small-en. This is a 512-dimensional Jina model optimized for English text.

**Signature:**
```dart
factory ModelConfig.jinaV2Small()
```

**Model Details:**
- **Dimensions:** 512
- **Speed:** Fast
- **Quality:** Good
- **Use case:** English text embeddings

**Returns:**
- `ModelConfig`: Configuration for Jina v2-small-en.

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());
try {
  final result = embedder.embedText('Search-optimized embedding');
  print('Dimension: ${result.dimension}'); // 512
} finally {
  embedder.dispose();
}
```

---

#### jinaV2Base()

Predefined configuration for Jina v2-base-en. This is a 768-dimensional Jina model providing high-quality embeddings for English text.

**Signature:**
```dart
factory ModelConfig.jinaV2Base()
```

**Model Details:**
- **Dimensions:** 768
- **Speed:** Medium
- **Quality:** Excellent
- **Use case:** High-quality English text embeddings

**Returns:**
- `ModelConfig`: Configuration for Jina v2-base-en.

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());
try {
  final result = embedder.embedText('Best quality embedding');
  print('Dimension: ${result.dimension}'); // 768
} finally {
  embedder.dispose();
}
```

---

### ModelConfig Instance Methods

#### validate()

Validates the configuration parameters. Throws InvalidConfigError if the configuration is invalid.

**Signature:**
```dart
void validate()
```

**Throws:**
- `InvalidConfigError`: If modelId is empty or defaultBatchSize is not positive.

**Example:**
```dart
final config = ModelConfig(
  modelId: '',
  modelType: EmbeddingModel.bert,
);

try {
  config.validate();
} on InvalidConfigError catch (e) {
  print('Invalid config: ${e.field} - ${e.reason}');
  // Output: Invalid config: modelId - cannot be empty
}
```

---

#### toString()

Returns a string representation of the configuration.

**Signature:**
```dart
String toString()
```

**Returns:**
- `String`: A string showing all configuration fields.

**Example:**
```dart
final config = ModelConfig.bertMiniLML6();
print(config.toString());
// Output: ModelConfig(modelId: sentence-transformers/all-MiniLM-L6-v2, modelType: EmbeddingModel.bert, revision: main, dtype: ModelDtype.f32, normalize: true, defaultBatchSize: 32)
```

---

#### operator ==

Compares two ModelConfig objects for equality.

**Signature:**
```dart
bool operator ==(Object other)
```

**Parameters:**
- `other` (Object): The object to compare with.

**Returns:**
- `bool`: True if all fields match, false otherwise.

---

#### hashCode

Returns a hash code for the configuration.

**Signature:**
```dart
int get hashCode
```

**Returns:**
- `int`: Hash code computed from all configuration fields.

---

### ModelConfig Properties

#### modelId

HuggingFace model identifier.

**Signature:**
```dart
final String modelId
```

---

#### modelType

Model architecture type (BERT or Jina).

**Signature:**
```dart
final EmbeddingModel modelType
```

---

#### revision

Git revision (branch, tag, or commit hash).

**Signature:**
```dart
final String revision
```

---

#### dtype

Data type for model weights (f32 or f16).

**Signature:**
```dart
final ModelDtype dtype
```

---

#### normalize

Whether to normalize embeddings to unit length.

**Signature:**
```dart
final bool normalize
```

---

#### defaultBatchSize

Default batch size for batch operations.

**Signature:**
```dart
final int defaultBatchSize
```

---

## Enums

### EmbeddingModel Enum

Supported embedding model architectures. Different model types use different underlying architectures and tokenization strategies.

**Values:**

#### bert

BERT-based models. BERT (Bidirectional Encoder Representations from Transformers) models are general-purpose sentence embedding models that work well for most semantic similarity tasks.

**Common BERT Models:**
- `sentence-transformers/all-MiniLM-L6-v2` (384 dim, fast)
- `sentence-transformers/all-MiniLM-L12-v2` (384 dim, better quality)

**Best For:**
- General semantic similarity
- Fast inference requirements
- Moderate quality requirements

**Performance:**
- Model load (warm cache): ~100ms
- Single embedding latency (short text): ~5-10ms

**Example:**
```dart
final embedder = EmbedAnything.fromPretrainedHf(
  model: EmbeddingModel.bert,
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
);
```

---

#### jina

Jina embedding models. Jina models are specifically optimized for semantic search and retrieval tasks, offering higher quality at the cost of slightly slower inference.

**Common Jina Models:**
- `jinaai/jina-embeddings-v2-small-en` (512 dim, fast)
- `jinaai/jina-embeddings-v2-base-en` (768 dim, high quality)

**Best For:**
- Semantic search applications
- High-quality similarity matching
- Document retrieval systems

**Performance:**
- Model load (warm cache): ~150ms
- Single embedding latency (short text): ~10-15ms

**Example:**
```dart
final embedder = EmbedAnything.fromPretrainedHf(
  model: EmbeddingModel.jina,
  modelId: 'jinaai/jina-embeddings-v2-small-en',
);
```

---

### ModelDtype Enum

Model data type for weights. Determines the precision of model weights during inference. Lower precision types (f16) provide faster inference and lower memory usage at the cost of slightly reduced quality.

**Performance Comparison (BERT all-MiniLM-L6-v2):**
- F32: 100% quality, ~90MB memory, baseline speed
- F16: 99% quality, ~45MB memory, ~1.3x faster

**Values:**

#### f32

32-bit floating point (full precision). This is the default and recommended option for most use cases. Provides the highest quality embeddings at the cost of larger memory footprint and slightly slower inference.

**Memory Usage (Typical Models):**
- BERT all-MiniLM-L6-v2: ~90MB
- Jina v2-base-en: ~280MB

**Use When:**
- Quality is the top priority
- Memory is not a constraint
- Reproducibility across platforms is important

**Example:**
```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f32,
);
```

---

#### f16

16-bit floating point (half precision). Reduces memory usage by approximately 50% and can provide faster inference on supported hardware. The quality difference is typically negligible for most applications.

**Memory Usage (Typical Models):**
- BERT all-MiniLM-L6-v2: ~45MB
- Jina v2-base-en: ~140MB

**Use When:**
- Running on resource-constrained devices
- Memory usage is a concern
- Speed is more important than maximum quality

**Note:**
Not all platforms support F16 acceleration. On unsupported platforms, the model may fall back to F32 internally.

**Example:**
```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,
);
```

---

## Error Classes

All error classes extend `EmbedAnythingError`, which is a sealed class. This enables exhaustive pattern matching on error types.

### EmbedAnythingError

Base class for all EmbedAnything errors.

**Signature:**
```dart
sealed class EmbedAnythingError implements Exception
```

**Properties:**
- `message` (String): The error message.

**Example:**
```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'invalid/model',
  );
} on EmbedAnythingError catch (e) {
  print('Error: ${e.message}');

  // Exhaustive pattern matching
  switch (e) {
    case ModelNotFoundError():
      print('Model not found: ${e.modelId}');
    case InvalidConfigError():
      print('Invalid config: ${e.field} - ${e.reason}');
    case EmbeddingFailedError():
      print('Embedding failed: ${e.reason}');
    case MultiVectorNotSupportedError():
      print('Multi-vector embeddings not supported');
    case FFIError():
      print('FFI error: ${e.operation}');
    case FileNotFoundError():
      print('File not found: ${e.path}');
    case UnsupportedFileFormatError():
      print('Unsupported format: ${e.extension}');
    case FileReadError():
      print('File read error: ${e.reason}');
  }
}
```

---

### ModelNotFoundError

Error thrown when a model is not found on HuggingFace Hub.

**Occurs When:**
- The model ID is incorrect or misspelled
- The model doesn't exist on HuggingFace Hub
- Network connectivity issues prevent model download
- The model requires authentication but no token is provided

**Properties:**
- `modelId` (String): The model ID that was not found.

**Example:**
```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'invalid/model/path',
  );
} on ModelNotFoundError catch (e) {
  print('Model not found: ${e.modelId}');
  print('Check the model ID on https://huggingface.co/');
}
```

---

### InvalidConfigError

Error thrown when model or embedder configuration is invalid.

**Occurs When:**
- Required configuration fields are missing or empty
- Configuration values are out of valid range
- Incompatible configuration options are used together

**Properties:**
- `field` (String): The configuration field that is invalid.
- `reason` (String): The reason why the configuration is invalid.

**Example:**
```dart
try {
  final config = ModelConfig(
    modelId: '',  // Invalid: empty string
    modelType: EmbeddingModel.bert,
  );
  config.validate();
} on InvalidConfigError catch (e) {
  print('Invalid ${e.field}: ${e.reason}');
}
```

---

### EmbeddingFailedError

Error thrown when embedding generation fails.

**Occurs Due To:**
- Text processing errors (e.g., invalid characters)
- Model inference failures
- Memory allocation failures during embedding generation
- Internal model errors

**Properties:**
- `reason` (String): The reason why embedding generation failed.

**Example:**
```dart
try {
  final result = embedder.embedText(someText);
} on EmbeddingFailedError catch (e) {
  print('Failed to generate embedding: ${e.reason}');
  // Consider retrying or using a different text
}
```

---

### MultiVectorNotSupportedError

Error thrown when multi-vector embeddings are encountered. Multi-vector embeddings (e.g., from ColBERT or late-interaction models) are not currently supported. Only dense single-vector embeddings are supported.

**Example:**
```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'some-colbert-model',
  );
  final result = embedder.embedText('test');
} on MultiVectorNotSupportedError catch (e) {
  print(e.message);
  // Use a different model that produces dense single vectors
}
```

---

### FFIError

Error thrown when an FFI (Foreign Function Interface) operation fails. This indicates a problem at the boundary between Dart and native code.

**Occurs Due To:**
- Null pointer errors
- Invalid memory access
- Native function call failures
- Rust panic or native crashes (if caught)

**Properties:**
- `operation` (String): The FFI operation that failed.
- `nativeError` (String?): Optional native error message from Rust/C side.

**Example:**
```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
} on FFIError catch (e) {
  print('FFI operation failed: ${e.operation}');
  if (e.nativeError != null) {
    print('Native error: ${e.nativeError}');
  }
}
```

---

### FileNotFoundError

Error thrown when a file or directory is not found.

**Occurs When:**
- The specified file path does not exist
- The specified directory path does not exist
- Permission denied accessing the file or directory

**Properties:**
- `path` (String): The path that was not found.

**Example:**
```dart
try {
  final chunks = await embedder.embedFile('/path/to/nonexistent.pdf');
} on FileNotFoundError catch (e) {
  print('File not found: ${e.path}');
  // Check the path and try again
}
```

---

### UnsupportedFileFormatError

Error thrown when a file format is not supported.

**Occurs When:**
- The file extension is not in the supported list
- The file format cannot be parsed by available parsers

**Supported Formats:**
PDF, TXT, MD, DOCX, HTML

**Properties:**
- `path` (String): The path to the file.
- `extension` (String): The file extension that is not supported.

**Example:**
```dart
try {
  final chunks = await embedder.embedFile('/path/to/file.xyz');
} on UnsupportedFileFormatError catch (e) {
  print('Unsupported format: ${e.extension} for ${e.path}');
  print('Supported formats: PDF, TXT, MD, DOCX, HTML');
}
```

---

### FileReadError

Error thrown when a file cannot be read.

**Occurs Due To:**
- Permission denied reading the file
- I/O error during file access
- File is locked by another process
- Disk read error

**Properties:**
- `path` (String): The path to the file that could not be read.
- `reason` (String): The reason why the file could not be read.

**Example:**
```dart
try {
  final chunks = await embedder.embedFile('/protected/file.pdf');
} on FileReadError catch (e) {
  print('Failed to read ${e.path}: ${e.reason}');
  // Check permissions or try again later
}
```

---

## See Also

- [Getting Started](getting-started.md) - Quick start guide and installation
- [Core Concepts](core-concepts.md) - Architecture and fundamental concepts
- [Usage Guide](usage-guide.md) - Common patterns and real-world usage
- [Error Handling](error-handling.md) - Comprehensive error handling guide
- [Models and Configuration](models-and-configuration.md) - Model selection and configuration
- [Advanced Topics](advanced-topics.md) - Advanced usage scenarios
