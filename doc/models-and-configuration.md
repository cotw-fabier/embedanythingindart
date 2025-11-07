# Models and Configuration

This guide helps you choose the right embedding model and configure it for your use case. EmbedAnythingInDart supports multiple BERT and Jina models with flexible configuration options.

## Available Models

EmbedAnythingInDart provides access to popular embedding models from HuggingFace Hub. Each model has different characteristics suited for specific use cases.

### Model Comparison

| Model Name | Model ID | Dimensions | Speed | Use Case | Predefined Config |
|------------|----------|------------|-------|----------|-------------------|
| BERT MiniLM-L6 | `sentence-transformers/all-MiniLM-L6-v2` | 384 | Fast | General purpose, quick prototyping | `ModelConfig.bertMiniLML6()` |
| BERT MiniLM-L12 | `sentence-transformers/all-MiniLM-L12-v2` | 384 | Medium | Better quality when speed is less critical | `ModelConfig.bertMiniLML12()` |
| Jina v2 Small | `jinaai/jina-embeddings-v2-small-en` | 512 | Fast | English semantic search, balanced quality | `ModelConfig.jinaV2Small()` |
| Jina v2 Base | `jinaai/jina-embeddings-v2-base-en` | 768 | Slower | Highest quality English embeddings | `ModelConfig.jinaV2Base()` |

### Model Types

**BERT Models**

BERT (Bidirectional Encoder Representations from Transformers) models are general-purpose sentence embedding models that work well for most semantic similarity tasks. They're fast and provide good quality embeddings.

Characteristics:
- Architecture: Transformer encoder with 6-12 layers
- Training: Pre-trained on massive text corpora
- Best for: General semantic similarity, fast inference
- Performance: Model load ~100ms (warm cache), single embedding ~5-10ms

**Jina Models**

Jina models are specifically optimized for semantic search and retrieval tasks. They offer higher quality embeddings at the cost of slightly slower inference.

Characteristics:
- Architecture: Optimized transformer architecture
- Training: Fine-tuned specifically for search/retrieval
- Best for: Semantic search, document retrieval, high-quality matching
- Performance: Model load ~150ms (warm cache), single embedding ~10-15ms

## Predefined Configurations

The easiest way to get started is with predefined model configurations. These provide sensible defaults optimized for each model.

### ModelConfig.bertMiniLML6()

Recommended starting point for most applications.

```dart
final config = ModelConfig.bertMiniLML6();
final embedder = EmbedAnything.fromConfig(config);

try {
  final result = embedder.embedText('Hello, world!');
  print('Dimension: ${result.dimension}'); // 384
} finally {
  embedder.dispose();
}
```

**Specifications:**
- Dimensions: 384
- Speed: Fast (~5-10ms per embedding)
- Memory: ~90MB (F32)
- Best for: General purpose, prototyping, speed-critical applications

**When to Use:**
- Starting a new project
- Need fast inference
- General semantic similarity tasks
- Resource-constrained environments

### ModelConfig.bertMiniLML12()

Better quality BERT model with 12 layers instead of 6.

```dart
final config = ModelConfig.bertMiniLML12();
final embedder = EmbedAnything.fromConfig(config);

try {
  final result = embedder.embedText('Machine learning');
  print('Dimension: ${result.dimension}'); // 384
} finally {
  embedder.dispose();
}
```

**Specifications:**
- Dimensions: 384
- Speed: Medium (slower than L6)
- Memory: ~120MB (F32)
- Best for: Higher quality requirements with same embedding size

**When to Use:**
- Quality is more important than speed
- Maintaining 384-dimensional embeddings (compatibility with L6)
- Moderate computational budget

### ModelConfig.jinaV2Small()

Optimized for English semantic search with balanced performance.

```dart
final config = ModelConfig.jinaV2Small();
final embedder = EmbedAnything.fromConfig(config);

try {
  final result = embedder.embedText('semantic search query');
  print('Dimension: ${result.dimension}'); // 512
} finally {
  embedder.dispose();
}
```

**Specifications:**
- Dimensions: 512
- Speed: Fast (~10-15ms per embedding)
- Memory: ~160MB (F32)
- Best for: English text embeddings, search applications

**When to Use:**
- Building search functionality
- Working exclusively with English text
- Need higher quality than BERT but reasonable speed

### ModelConfig.jinaV2Base()

Highest quality embeddings for production search systems.

```dart
final config = ModelConfig.jinaV2Base();
final embedder = EmbedAnything.fromConfig(config);

try {
  final result = embedder.embedText('high quality embedding');
  print('Dimension: ${result.dimension}'); // 768
} finally {
  embedder.dispose();
}
```

**Specifications:**
- Dimensions: 768
- Speed: Slower (more computation required)
- Memory: ~280MB (F32)
- Best for: Production search systems, maximum quality

**When to Use:**
- Quality is paramount
- Production search/retrieval systems
- Sufficient computational resources available
- Large vector database with high-dimensional support

## Custom Configuration

For advanced use cases, you can create custom configurations with fine-grained control over model parameters.

### Basic Custom Configuration

```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  revision: 'main',
  dtype: ModelDtype.f32,
  normalize: true,
  defaultBatchSize: 32,
);

final embedder = EmbedAnything.fromConfig(config);
```

### Configuration Parameters

#### modelId (required)

The HuggingFace model identifier. Must be a valid model path on HuggingFace Hub.

```dart
modelId: 'sentence-transformers/all-MiniLM-L6-v2'
```

Examples:
- `'sentence-transformers/all-MiniLM-L6-v2'`
- `'jinaai/jina-embeddings-v2-small-en'`
- `'custom-organization/custom-model'`

#### modelType (required)

The model architecture type. Must match the model's actual architecture.

```dart
modelType: EmbeddingModel.bert  // or EmbeddingModel.jina
```

Options:
- `EmbeddingModel.bert` - For BERT-based models
- `EmbeddingModel.jina` - For Jina-optimized models

#### revision (optional)

Git revision to use from the model repository. Defaults to `'main'`.

```dart
revision: 'main'  // default
revision: 'v1.0'  // specific tag
revision: 'abc123'  // specific commit hash
```

Use cases:
- Pin to specific model version for reproducibility
- Test experimental model versions
- Use alternative model configurations

#### dtype (optional)

Data type for model weights. Defaults to `ModelDtype.f32`.

```dart
dtype: ModelDtype.f32  // Full precision (default)
dtype: ModelDtype.f16  // Half precision
```

**F32 (Full Precision)**
- Highest quality embeddings
- More memory (~90MB for MiniLM-L6)
- Baseline speed
- Best reproducibility across platforms

**F16 (Half Precision)**
- ~99% quality of F32
- ~50% memory reduction (~45MB for MiniLM-L6)
- ~1.3x faster inference
- May fall back to F32 on unsupported platforms

Example with F16:
```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,  // Use half precision
);
```

#### normalize (optional)

Whether to normalize embeddings to unit length. Defaults to `true`.

```dart
normalize: true   // Embeddings are unit vectors (default)
normalize: false  // Raw embeddings
```

Normalization benefits:
- Cosine similarity becomes simple dot product
- Consistent magnitude across embeddings
- Standard for most embedding models
- Required for some vector databases

When to disable:
- Model already normalizes internally
- Need raw embedding values for debugging
- Specific downstream processing requirements

#### defaultBatchSize (optional)

Default batch size for batch operations. Defaults to `32`.

```dart
defaultBatchSize: 32   // Default
defaultBatchSize: 64   // Larger batches (more memory, faster throughput)
defaultBatchSize: 16   // Smaller batches (less memory)
```

Considerations:
- Larger batches: Better throughput, more memory
- Smaller batches: Lower memory, slightly slower
- Must be positive integer
- Can override per batch operation

### Custom Configuration Examples

**Memory-Optimized Configuration**

For resource-constrained environments:

```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,      // 50% memory reduction
  defaultBatchSize: 16,       // Smaller batches
);
```

**High-Throughput Configuration**

For batch processing workloads:

```dart
final config = ModelConfig(
  modelId: 'jinaai/jina-embeddings-v2-small-en',
  modelType: EmbeddingModel.jina,
  dtype: ModelDtype.f16,      // Faster inference
  defaultBatchSize: 64,       // Larger batches
  normalize: true,
);
```

**Production Configuration with Version Pinning**

For reproducible production deployments:

```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  revision: 'v1.0.0',         // Pin to specific version
  dtype: ModelDtype.f32,      // Maximum quality
  normalize: true,
  defaultBatchSize: 32,
);
```

### Configuration Validation

Configurations are validated when creating an embedder. Invalid configurations throw `InvalidConfigError`.

```dart
try {
  final config = ModelConfig(
    modelId: '',  // Invalid: empty model ID
    modelType: EmbeddingModel.bert,
  );

  final embedder = EmbedAnything.fromConfig(config);
} on InvalidConfigError catch (e) {
  print('Invalid configuration: ${e.field} - ${e.reason}');
  // Output: Invalid configuration: modelId - cannot be empty
}
```

Validation rules:
- `modelId` cannot be empty
- `defaultBatchSize` must be positive

## Performance Comparison

Understanding performance tradeoffs helps choose the right model and configuration.

### Speed Comparison

Based on BERT all-MiniLM-L6-v2 benchmarks on modern hardware:

| Operation | F32 | F16 |
|-----------|-----|-----|
| Model load (warm cache) | ~100ms | ~90ms |
| Single embedding (short text) | ~5-10ms | ~4-8ms |
| Batch (100 items) | ~80ms | ~65ms |

Factors affecting speed:
- Model size (L6 faster than L12, BERT faster than Jina)
- Input text length (longer text = more computation)
- Batch size (larger batches = better throughput)
- Hardware (CPU vs GPU acceleration)
- Data type (F16 faster than F32)

### Memory Comparison

Approximate memory usage per model:

| Model | F32 | F16 |
|-------|-----|-----|
| BERT all-MiniLM-L6-v2 | ~90MB | ~45MB |
| BERT all-MiniLM-L12-v2 | ~120MB | ~60MB |
| Jina v2-small-en | ~160MB | ~80MB |
| Jina v2-base-en | ~280MB | ~140MB |

Additional memory considerations:
- Batch processing requires memory for input texts
- Larger batches temporarily increase memory usage
- Each embedder instance loads model into memory
- Embeddings themselves: dimension × 8 bytes per vector (List<double>)

### Dimension Tradeoffs

Higher dimensions provide more precise semantic representation but have costs:

| Dimension | Pros | Cons |
|-----------|------|------|
| 384 (BERT) | Fast, compact, good for most tasks | Less nuanced similarity |
| 512 (Jina Small) | Better semantic precision | Slightly slower, more storage |
| 768 (Jina Base) | Highest quality, subtle distinctions | Slowest, most storage |

Storage implications for 1 million embeddings:
- 384 dimensions: ~3GB
- 512 dimensions: ~4GB
- 768 dimensions: ~6GB

### Batch Size Impact

Batch processing provides significant performance benefits:

| Approach | Time for 100 Texts | Throughput |
|----------|-------------------|------------|
| Individual calls | ~500ms | 200/sec |
| Batch size 32 | ~80ms | 1250/sec |
| Batch size 64 | ~65ms | 1540/sec |

Recommendations:
- Always use batch methods for multiple texts
- Batch size 32-64 optimal for most cases
- Larger batches (128+) may not improve speed significantly

## Model Loading Behavior

Understanding model loading helps manage first-run experience and caching.

### First Load (Cold Cache)

When loading a model for the first time:

1. Library checks local cache (`~/.cache/huggingface/hub`)
2. If not found, downloads from HuggingFace Hub
3. Model files saved to cache
4. Model loaded into memory

Characteristics:
- Takes several minutes (100-500MB download)
- Requires internet connectivity
- Progress not visible (blocking operation)
- Only happens once per model

Example first load:
```dart
// This will download the model (slow on first run)
print('Loading model... (may take a few minutes on first run)');
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
print('Model loaded!');
```

### Subsequent Loads (Warm Cache)

After first download, models load from local cache:

Characteristics:
- Fast (~100-150ms)
- No internet required
- Offline usage fully supported
- Same for all application runs

Example:
```dart
// Second and subsequent runs are fast
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
// Loads in ~100ms from cache
```

### Cache Location

Models are cached by HuggingFace Hub:
- **Linux/macOS**: `~/.cache/huggingface/hub`
- **Windows**: `%USERPROFILE%\.cache\huggingface\hub`

Cache management:
- Models persist across application runs
- Shared between all applications using HuggingFace models
- Can be cleared to free disk space
- Automatically re-downloaded if cleared

### Model Download Optimization

Tips for managing first-load experience:

**1. Pre-download models**
```bash
# Download model using HuggingFace CLI
pip install huggingface-hub
huggingface-cli download sentence-transformers/all-MiniLM-L6-v2
```

**2. Provide user feedback**
```dart
void loadModel() async {
  print('Loading model for first time...');
  print('This may take a few minutes while downloading from HuggingFace.');

  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  print('Model ready!');
}
```

**3. Handle loading errors**
```dart
try {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
} on ModelNotFoundError catch (e) {
  print('Failed to load model: ${e.message}');
  print('Check internet connection and HuggingFace Hub status.');
}
```

## Choosing the Right Model

Use this decision tree to select the appropriate model for your use case.

### Decision Tree

```
START: What is your use case?
│
├─ General semantic similarity
│  ├─ Speed critical? → BERT MiniLM-L6 + F16
│  └─ Quality important? → BERT MiniLM-L12
│
├─ Semantic search/retrieval
│  ├─ Balanced performance → Jina v2-small
│  └─ Best quality → Jina v2-base
│
├─ Resource constrained
│  ├─ Low memory → BERT MiniLM-L6 + F16
│  └─ Storage limited → BERT MiniLM-L6 (384 dim)
│
└─ Production system
   ├─ High throughput → BERT + F16 + batch size 64
   └─ Highest quality → Jina v2-base + F32
```

### Use Case Recommendations

**General Purpose Applications**
- Model: `ModelConfig.bertMiniLML6()`
- Why: Fast, good quality, widely tested
- Example: Text similarity, simple search

**Semantic Search Engine**
- Model: `ModelConfig.jinaV2Small()`
- Why: Optimized for retrieval, balanced performance
- Example: Document search, Q&A systems

**High-Quality Production Search**
- Model: `ModelConfig.jinaV2Base()`
- Why: Best quality, worth the compute cost
- Example: Enterprise search, critical applications

**Mobile/Embedded Devices**
- Model: BERT MiniLM-L6 + F16
```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,
);
```
- Why: Minimal memory footprint, reasonable quality

**Batch Processing Pipeline**
- Model: BERT MiniLM-L6 + F16 + large batches
```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,
  defaultBatchSize: 64,
);
```
- Why: Maximum throughput, efficient resource usage

**Prototyping/Development**
- Model: `ModelConfig.bertMiniLML6()`
- Why: Fast iteration, quick model loading
- Note: Can upgrade to Jina models for production

### Quality vs Performance Matrix

Visual guide to model selection:

```
High Quality
     ↑
     │  Jina v2-base (F32)
     │         ○
     │
     │              Jina v2-small (F32)
     │                   ○
     │  BERT L12 (F32)
     │         ○
     │                   BERT L6 (F32)
     │                        ○
     │              BERT L6 (F16)
     │                   ○
     └────────────────────────────────→ High Speed

○ = Model position in quality/speed tradeoff space
```

### Evaluation Checklist

Before finalizing model selection, consider:

- [ ] What is the primary use case? (search, similarity, clustering)
- [ ] What are the quality requirements? (good enough vs best possible)
- [ ] What are the speed requirements? (real-time vs batch)
- [ ] What are the resource constraints? (memory, storage, compute)
- [ ] How many embeddings will be generated? (storage scaling)
- [ ] Is first-load time acceptable? (download time)
- [ ] Is offline operation required? (after first download)
- [ ] Can the model be pre-downloaded? (deployment strategy)

## Configuration Best Practices

Follow these guidelines for robust configuration management:

### 1. Use Predefined Configs When Possible

```dart
// Good: Use predefined configuration
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

// Avoid: Manual configuration unless needed
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  // ... many parameters
);
```

### 2. Validate Configuration Early

```dart
final config = ModelConfig(
  modelId: userProvidedModelId,
  modelType: EmbeddingModel.bert,
);

// Validate before using
try {
  config.validate();
  final embedder = EmbedAnything.fromConfig(config);
} on InvalidConfigError catch (e) {
  print('Configuration error in ${e.field}: ${e.reason}');
  // Handle error gracefully
}
```

### 3. Store Configuration Objects

```dart
class EmbeddingService {
  final ModelConfig config;
  EmbedAnything? _embedder;

  EmbeddingService(this.config);

  EmbedAnything get embedder {
    return _embedder ??= EmbedAnything.fromConfig(config);
  }

  void dispose() {
    _embedder?.dispose();
    _embedder = null;
  }
}

// Usage
final service = EmbeddingService(ModelConfig.bertMiniLML6());
```

### 4. Use Constants for Model IDs

```dart
class EmbeddingModels {
  static const bertMini = 'sentence-transformers/all-MiniLM-L6-v2';
  static const jinaSmall = 'jinaai/jina-embeddings-v2-small-en';
}

// Usage
final config = ModelConfig(
  modelId: EmbeddingModels.bertMini,
  modelType: EmbeddingModel.bert,
);
```

### 5. Document Configuration Choices

```dart
/// Production embedding service using Jina v2-base for highest quality.
///
/// Configuration:
/// - Model: Jina v2-base (768 dimensions)
/// - Data type: F32 for maximum quality
/// - Batch size: 32 (balanced throughput/memory)
///
/// Rationale: Quality is critical for our search use case, and we have
/// sufficient resources to support the larger model.
class ProductionEmbeddingService {
  final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());

  // ... implementation
}
```

## Next Steps

Now that you understand models and configuration:

- **Apply your knowledge**: Review the [Usage Guide](usage-guide.md) for practical patterns
- **Handle errors**: Check [Error Handling](error-handling.md) for robust applications
- **Optimize performance**: See [Advanced Topics](advanced-topics.md) for performance tuning
- **Explore the API**: Browse the [API Reference](api-reference.md) for detailed documentation

## Related Documentation

- [Getting Started](getting-started.md) - Quick start guide with examples
- [Core Concepts](core-concepts.md) - Understanding the architecture
- [Usage Guide](usage-guide.md) - Common usage patterns
- [API Reference](api-reference.md) - Complete API documentation
- [Error Handling](error-handling.md) - Robust error management
- [Advanced Topics](advanced-topics.md) - Performance optimization and advanced features
